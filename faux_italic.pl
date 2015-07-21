#!/usr/bin/env perl
use strict;
use warnings 'FATAL' => 'all';
use Carp ();
$SIG{__DIE__} = sub { Carp::confess(@_) };

while (my $line = <STDIN>)
{
  chomp $line;
  my ($code, @rest) = split(/\s+/, $line);
  my @details;
  for my $i (1..pop(@rest))
  {
    my $dline = <STDIN>;
    chomp $dline;
    push(@details, $dline);
  }
  
  if ($code eq 'BB')
  {
    $rest[0] += int(($rest[1] - 1)/2);
  }
  elsif ($code eq 'GM' || $code eq 'GL')
  {
    my $height = scalar(@details);
    my $addwidth = int(($height - 1)/2);
    for my $y (0..($height - 1))
    {
      my $addleft = int(($height - $y - 1)/2);
      my $addright = $addwidth - $addleft;
      my $dline = '.' x $addleft;
      $dline .= $details[$y];
      $dline .= '.' x $addright;
     $details[$y] = $dline;
    }
  }
  
  print join(' ', $code, @rest, scalar(@details)) . "\n";
  print map { $_ . "\n" } @details;
}
exit;
