#!/usr/bin/perl
use strict;
use warnings 'FATAL' => 'all';
use FindBin ();
require "$FindBin::Bin/Macbinary.pm";

binmode STDIN;
my $mb = Mac::Macbinary->new(\*STDIN);

binmode STDOUT;
print $mb->resource;
