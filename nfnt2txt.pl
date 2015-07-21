#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/rfork.subs";
use Carp ();
$SIG{__DIE__} = sub { Carp::confess(@_) };

binmode STDIN;
binmode STDOUT;
use bytes;

my $font_type = ReadUint16();
my $first_char = ReadUint16();
my $last_char = ReadUint16();
my $max_width = ReadUint16();
my $max_kern = ReadSint16();
my $neg_descent = ReadSint16();
my $rect_width = ReadUint16();
my $rect_height = ReadUint16();
my $tbl_offset = (ReadUint16() * 2) + 16;
my $max_ascent = ReadSint16();
my $max_descent = ReadSint16();
my $leading = ReadSint16();
my $bytes_per_row = ReadUint16() * 2;

print "MT $max_ascent $max_descent $leading $max_width 0\n";
print "BB $rect_width $rect_height $max_kern @{[ 0 - $max_ascent ]} 0\n";

my $missing_char = $last_char + 1;
my $table_end = $missing_char + 1;

# bit image
my @rows;
for my $y (1..$rect_height)
{
  push(@rows, [ ReadPackedBits($bytes_per_row * 8) ]);
}

my @ginfo;

# locations in image
for my $cnum ($first_char..$table_end)
{
  $ginfo[$cnum]{'location'} = ReadUint16();
}

# image offset and width
for my $cnum ($first_char..$missing_char)
{
  $ginfo[$cnum]{'offset'} = ReadSint8();
  $ginfo[$cnum]{'width'} = ReadSint8();
}
ReadPadding(2) unless ReadDone();

# ignore the optional data: glyph widths and image height

## done with reading: process the data

# missing glyph
for my $cnum ($missing_char, $first_char..$last_char)
{
  my $info = $ginfo[$cnum];
  my $cwidth = $info->{'width'};
  next if $cwidth < 0;
  
  my $bitstart = $info->{'location'};
  my $bitend = $ginfo[$cnum + 1]{'location'} - 1;
  my $bitoff = $info->{'offset'};
  
  my $rows = ($bitend < $bitstart) ? 0 : $rect_height;
  my $prefix = ($cnum == $missing_char) ? 'GM' : "GL $cnum";
 
  my $image = '';
  if ($rows)
  {
    for my $y (1..$rect_height)
    {
      $image .= '.' x ($bitoff - $max_kern);
      for my $b ($bitstart..$bitend)
      {
        $image .= $rows[$y - 1][$b] ? '*' : '.';
      }
      $image .= '.' x ($rect_width - ($bitend - $bitstart + 1) - ($bitoff - $max_kern));
      $image .= "\n";
    }
    $rows = 0 unless $image =~ /\*/s;
  }
  print "$prefix $cwidth 0 $rows\n";
  print $image if $rows;  
}

