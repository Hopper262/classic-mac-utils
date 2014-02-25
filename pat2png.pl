#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use Image::Magick ();
use FindBin ();
require "$FindBin::Bin/rfork.subs";

binmode STDIN;
binmode STDOUT;
use bytes;

my @colors = ( [ 1, 1, 1, 0 ], [ 0, 0, 0, 0 ] );

my $rowBytes = 1;
my ($top, $left, $bottom, $right) = (0, 0, 8, 8);
my $bpp = 1;

# image data
my @image_rows;
for my $i ($top..($bottom - 1))
{
  push(@image_rows, ReadRaw($rowBytes));
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


