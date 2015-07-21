#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';

my $finalsize = 0;
my @rawchunks;

# skip everything before data init
while (my $line = <>)
{
#   warn "Looking for init\n";
  last if $line =~ /Data Initialization information:/;
}
# grab uncompressed size, skip to chunks
while (my $line = <>)
{
#   warn "Looking for size\n";
  last if $line =~ /Data Image:/;
  
  if ($line =~ /Data image size = \$([0-9A-F]+)/)
  {
    $finalsize = hex($1);
#     warn "Found size: $finalsize\n";
  }
}

# grab chunks
while (my $line = <>)
{
#   warn "Looking for chunk\n";
  last if $line =~ /Data Relocation Information:/;
  
  if ($line =~ /Offset = \$([0-9A-F]+), +. = \$([0-9A-F]+), +Bytes = \$([0-9A-F]+), +Repeats = (\d+)/)
  {
    my %info = (
      'offset' => hex($1),
      'delta' => hex($2),
      'bytes' => hex($3),
      'repeat' => 0 + $4,
      );
    
    die "Unexpected input within chunk" unless <> =~ /Data:/;
    
    my $datasize = $info{'bytes'} * $info{'repeat'};
    my @data;
    while (my $line = <>)
    {
      my $digits = substr($line, 0, 50);
      $digits =~ s/ //g;
      while (scalar $digits)
      {
        push(@data, hex(substr($digits, 0, 2, '')));
      }
      last if scalar(@data) >= $datasize;
    }
    die "Unexpected data within chunk" unless scalar(@data) >= $datasize;
    
    $info{'data'} = \@data;
#     warn "Pushing chunk\n";
    push(@rawchunks, \%info);
  }
}
# warn "Done looking\n";

# process chunks
my $datablock = '';
for my $info (@rawchunks)
{
  my $offset = $info->{'offset'};
  my $delta = $info->{'delta'};
  my $bsize = $info->{'bytes'};
  my $bdata = $info->{'data'};
  my $repeat = $info->{'repeat'};
  
#   warn "Found chunk\n";
  die "Offset mismatch" if (($offset - $delta) != length($datablock));
  
  for my $i (1..$repeat)
  {
#     warn "Writing $delta + $bsize bytes\n";
    $datablock .= pack('C', 0) x $delta;
    for my $j (1..$bsize)
    {
      $datablock .= pack('C', shift @$bdata);
    }
#    $datablock .= substr($bdata, $bsize * ($i - 1), $bsize);
  }
}

# add trailing nulls
my $remaining = $finalsize - length($datablock);
if ($remaining > 0)
{
  $datablock .= pack('C', 0) x $remaining;
}

print $datablock;
