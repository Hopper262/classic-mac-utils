#!/usr/bin/perl
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
  
  if ($code eq 'MT')
  {
    $rest[3]++;
  }
  elsif ($code eq 'BB')
  {
    $rest[0]++;
  }
  elsif ($code eq 'GM' || $code eq 'GL')
  {
    my $pos = ($code eq 'GM') ? 0 : 1;
    $rest[$pos]++ if $rest[$pos] > 0;
    
    for my $y (0..(scalar(@details) - 1))
    {
      my $dline = $details[$y];
      $dline .= '.';
      my @dvals = map { $_ eq '*' } split(//, $dline);
      my $nline;
      for my $x (0..(scalar(@dvals) - 1))
      {
        $nline .= ($dvals[$x] || ($x && $dvals[$x - 1])) ? '*' : '.';
      }
      $details[$y] = $nline;
    }
  }
  
  print join(' ', $code, @rest, scalar(@details)) . "\n";
  print map { $_ . "\n" } @details;
}
exit;
