#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Image::Magick ();
use FindBin ();
require "$FindBin::Bin/rfork.subs";

binmode STDIN;
binmode STDOUT;
use bytes;

# ppat resource:
#   28-byte PixPat structure
#   50-byte PixMap structure
#   image data
#   clut data

# PixPat
my $type = ReadSint16();
die "Only indexed-color ppat resources are supported, exiting\n" unless $type == 1;
my $pm_off = ReadSint32();
my $img_off = ReadSint32();
ReadPadding(18);

# PixMap
ReadPadding($pm_off - CurOffset());
ReadPadding(4);
my $rowBytes = ReadUint16() & 0x3FFF;  # upper 2 bits are flags
my ($top, $left, $bottom, $right) = (ReadSint16(), ReadSint16(), ReadSint16(), ReadSint16());
ReadPadding(2);
$type = ReadSint16();
die "Only uncompressed ppats are supported, exiting\n" unless $type == 0;
ReadPadding(4);
my $res = ReadSint32();
warn "Unexpected horizontal resolution: $res\n" unless $res == (72 << 16);
$res = ReadSint32();
warn "Unexpected vertical resolution: $res\n" unless $res == (72 << 16);
$type = ReadSint16();
die "Only indexed color ppat resources are supported, exiting\n" unless $type == 0;
my $bpp = ReadSint16();
die "Unexpected bits per pixel, exiting\n" unless ($bpp == 1 || $bpp == 2 || $bpp == 4 || $bpp == 8);
my $cmpCount = ReadSint16();
die "Unexpected component count, exiting\n" unless $cmpCount == 1;
my $cmpSize = ReadSint16();
my $plane = ReadSint32();
die "Unexpected planeBytes count, exiting\n" unless $plane == 0;
my $clut_off = ReadSint32();
ReadPadding(4);

# image data
ReadPadding($img_off - CurOffset());
my @image_rows;
for my $i ($top..($bottom - 1))
{
  push(@image_rows, ReadRaw($rowBytes));
}

# clut data
ReadPadding($clut_off - CurOffset());
ReadPadding(6);
my $clut_max = ReadSint16();
my @colors;
for my $i (0..$clut_max)
{
  my $value = ReadSint16();
  my ($red, $green, $blue) = (ReadUint16(), ReadUint16(), ReadUint16());
  push(@colors, [ $red / 65535, $green / 65535, $blue / 65535, 0.0 ]);
}

# now, build image
my $width = $right - $left;
my $height = $bottom - $top;

my $img = Image::Magick->new();
$img->Set('size' => $width . 'x' . $height);
$img->Read('canvas:rgb(0,0,0,0)');
$img->Set('matte' => 'True');
$img->Set('alpha' => 'On');

for my $row (0..($bottom - $top - 1))
{
  my $rowdata = $image_rows[$row];
  for my $col (0..($right - $left - 1))
  {
    my $div = 8 / $bpp;
    my $byte = substr($rowdata, int($col / $div), 1);
    my $bits = unpack('B8', $byte);
    
    my $subbits = substr($bits, $bpp * ($col % $div), $bpp);
    my $iso = ('0' x (8 - $bpp)) . $subbits;
    my $idx = ord(pack('B8', $iso));
#     warn "Byte: @{[ ord($byte) ]}  Bpp: $bpp   Bits: $bits  Sub: $subbits  Iso: $iso  Index: $idx\n";
    
    die "Only ppats with fully specified color tables are supported, exiting\n" if $idx > scalar(@colors);
    
    $img->SetPixel('x' => $col, 'y' => $row, 'channel' => 'All', 'color' => $colors[$idx]);
  }
}

$img->Write('png:-');


