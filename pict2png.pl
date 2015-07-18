#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use Image::Magick ();
use IO::Scalar ();
use FindBin ();
use Carp ();
require "$FindBin::Bin/rfork.subs";

$SIG{__DIE__} = sub { Carp::confess @_ };

## This module only supports a subset of valid PICTs.
## Code ported from Aleph One's image.cpp; that file
## contains comments documenting ignored items.

binmode STDIN;
binmode STDOUT;
use bytes;

my %skips = (
  (map { $_ =>  0 } (0x00, 0x11, 0x1c, 0x1e, 0x38, 0x39, 0x3a, 0x3b, 0x3c,
                     0x02ff)),
  (map { $_ =>  2 } (0x03, 0x04, 0x05, 0x08, 0x0d, 0x15, 0x16, 0x23, 0xa0)),
  (map { $_ =>  4 } (0x06, 0x07, 0x0b, 0x0c, 0x0e, 0x0f, 0x21)),
  (map { $_ =>  6 } (0x1a, 0x1b, 0x1d, 0x1f, 0x22)),
  (map { $_ =>  8 } (0x02, 0x09, 0x0a, 0x10, 0x20, 0x30, 0x31, 0x32, 0x33,
                     0x34)),
  (map { $_ => 24 } (0x0c00)),
  );

ReadPadding(6);
my $pic_height = ReadUint16();
my $pic_width = ReadUint16();
my $pic;
my $found_image = 0;

my $opcode;
while (($opcode = ReadUint16()) != 0xff)
{
#   warn sprintf "Opcode %04x\n", $opcode;
  if (exists $skips{$opcode})
  {
#     warn "Skipping $skips{$opcode} bytes\n";
    ReadPadding($skips{$opcode});
  }
  elsif ($opcode == 0x01)     # Clipping region
  {
    my $size = ReadUint16();
    $size += ($size & 1);
    ReadPadding($size - 2);
  }
  elsif ($opcode == 0xa1)     # LongComment
  {
    ReadPadding(2);
    my $size = ReadUint16();
    $size += ($size & 1);
    ReadPadding($size);
  }
  elsif ($opcode == 0x98 ||   # Packed CopyBits
         $opcode == 0x99 ||   # Packed CopyBits with clipping region
         $opcode == 0x9a ||   # Direct CopyBits
         $opcode == 0x9b)     # Direct CopyBits with clipping region
  {
#     warn "Found CopyBits image ($opcode; $pic_width x $pic_height)\n";
    ReadPadding(4) if $opcode == 0x9a || $opcode == 0x9b;
    my $row_bytes = ReadUint16();
    my $is_pixmap = ($row_bytes & 0x8000);
    $row_bytes &= 0x3fff;
    
    my $top = ReadUint16();
    my $left = ReadUint16();
    my $height = ReadUint16();
    my $width = ReadUint16();
    
    my ($pack_type, $pixel_size) = (0, 1);
    my @colors;
    if ($is_pixmap)
    {
      ReadPadding(2);
      $pack_type = ReadUint16();
      ReadPadding(14);
      $pixel_size = ReadUint16();
      ReadPadding(16);
      
      if ($opcode == 0x98 || $opcode == 0x99)
      {
        ReadPadding(4);
        my $flags = ReadUint16();
        my $ignore_index = ($flags & 0x8000);
        my $num_colors = ReadUint16() + 1;
        for my $i (0..($num_colors - 1))
        {
          ReadPadding(1);
          my $val = ReadUint8();
          $val = $i if $ignore_index;
          $colors[$val] = [ ReadUint16()/65535, ReadUint16()/65535, ReadUint16()/65535 ];
        }
      }
    }
    
    ReadPadding(18);
    ReadPadding(ReadUint16() - 2) if $opcode == 0x99 || $opcode == 0x9b;
    
    my @rows;
    if ($row_bytes < 8 || $pack_type == 1)
    {
      for my $i (1..$height)
      {
        push(@rows, ReadRaw($row_bytes));
      }
    }
    else
    {
      if ($pixel_size <= 8)
      {
        for my $i (1..$height)
        {
          push(@rows, UnpackBits($row_bytes, 0));
        }
      }
      else
      {
        if ($pack_type == 3 || ($pack_type == 0 && $pixel_size == 16))
        {
          for my $i (1..$height)
          {
            push(@rows, UnpackBits($row_bytes, 1));
          }
        }
        elsif ($pack_type == 4 || ($pack_type == 0 && $pixel_size == 32))
        {
          my $w = int($row_bytes / 4);
          for my $i (1..$height)
          {
            my $rowdata = UnpackBits($row_bytes, 0);
            my $interleaved = '';
            for my $x (0..($width - 1))
            {
              $interleaved .= chr(0) .
                              substr($rowdata, $x, 1) .
                              substr($rowdata, $x + $w, 1) .
                              substr($rowdata, $x + 2*$w, 1);
            }
            push(@rows, $interleaved);
          }
        }
        else
        {
          die "Unimplemented packing type $pack_type (depth $pixel_size)";
        }
      }
    }
    
    $pic = Image::Magick->new();
    $pic->Set('size' => $width . 'x' . $height);
    $pic->Read('xc:black');
    
    my $y = 0;
    for my $rowdata (@rows)
    {
      my @elems;
      if ($pixel_size == 1)
      {
        @elems = map { $colors[$_] } unpack('B*', $rowdata);
      }
      elsif ($pixel_size == 2)
      {
        for my $val (unpack('H*', $rowdata))
        {
          push(@elems, $colors[$val >> 2], 
                       $colors[$val & 0x3]);
        }
      }
      elsif ($pixel_size == 4)
      {
        @elems = map { $colors[$_] } unpack('H*', $rowdata);
      }
      elsif ($pixel_size == 8)
      {
        @elems = map { $colors[$_] } unpack('C*', $rowdata);
      }
      elsif ($pixel_size == 16)
      {
        for my $val (unpack('n*', $rowdata))
        {
          push(@elems, [ (($val & 0x7c00) >> 10)/31,
                         (($val & 0x03e0) >> 5)/31,
                         ($val & 0x001f)/31 ]);
        }
      }
      elsif ($pixel_size == 32)
      {
        for my $val (unpack('N*', $rowdata))
        {
          push(@elems, [ (($val & 0xff0000) >> 16)/255,
                         (($val & 0x00ff00) >> 8)/255,
                         ($val & 0x0000ff)/255 ]);
        }
      }
      
      my $x = 0;
      for my $cref (@elems)
      {
        $pic->SetPixel('x' => $x, 'y' => $y, 'channel' => 'RGB',
                       'color' => $cref);
        $x++;
      }
      $y++;
    }
    
    # stop after first image
    last;
  }
  elsif ($opcode == 0x8200)   # Compressed QuickTime image
  {
#     warn "Found QuickTime image ($pic_width x $pic_height)\n";
    my $opcode_size = ReadUint32();
    $opcode_size += ($opcode_size & 1);
    my $opcode_start = CurOffset();
    ReadPadding(26);
    my $offset_x = ReadUint16();
    ReadPadding(2);
    my $offset_y = ReadUint16();
    ReadPadding(6);
    my $matte_size = ReadUint32();
    ReadPadding(22);
    my $mask_size = ReadUint32();
    
    ReadPadding(ReadUint32() - 4) if $matte_size;
    ReadPadding($matte_size);
    ReadPadding($mask_size);
    
    my $id_start = CurOffset();
    my $id_size = ReadUint32();
    my $codec_type = ReadRaw(4);
    if ($codec_type ne 'jpeg')
    {
      warn "Unsupported QuickTime codec '$codec_type'\n";
      last;
    }
    ReadPadding(36);
    my $data_size = ReadUint32();
    ReadPadding(CurOffset() - $id_start + $id_size);
    
    my $data = ReadRaw($data_size);
    my $jpeg = Image::Magick->new();
    my $fh = IO::Scalar::new(\$data);
    $jpeg->Read('file' => $fh);
    
    unless ($pic)
    {
      $pic = Image::Magick->new();
      $pic->Set('size' => $pic_width . 'x' . $pic_height);
      $pic->Read('xc:black');
    }
    $pic->Composite('image' => $jpeg, 'compose' => 'Copy',
                    'x' => $offset_x, 'y' => $offset_y);

    ReadPadding(CurOffset() - $opcode_start + $opcode_size);
    # don't stop, since image may be banded
  }
  elsif ($opcode >= 0x0300 && $opcode < 0x8000)
  {
    ReadPadding(($opcode >> 8) * 2);
  }
  elsif ($opcode >= 0x8000 && $opcode < 0x8100)
  {
    ReadPadding(0);
  }
  else
  {
    warn sprintf("Unknown opcode %04x in PICT", $opcode);
    last;
  }
}

warn "No image data found\n" unless $pic;

$pic->Write('png:-') if $pic;


exit;

sub UnpackBits
{
  my ($row_bytes, $sixteen) = @_;
  
  my $unpacked;
  
  my $src_count = ($row_bytes > 250) ? ReadUint16() : ReadUint8();
  my $end_offset = CurOffset() + $src_count;
 
  while ($end_offset > CurOffset())
  {
    my $c = ReadSint8();
    if ($c < 0)
    {
      my $size = 1 - $c;
      $unpacked .= ReadRaw($sixteen ? 2 : 1) x $size;
    }
    else
    {
      my $size = $c + 1;
      $unpacked .= ReadRaw($size * ($sixteen ? 2 : 1));
    }
  }
  return $unpacked;
}
