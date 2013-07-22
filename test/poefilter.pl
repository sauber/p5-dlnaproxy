#!/usr/bin/env perl

use warnings;
use strict;
use POE::Filter::DLNAProxy;

my $filter = POE::Filter::DLNAProxy->new( translator => {} );

my $lines = $filter->get(['<responsecode>', '<header>', '<content>']);
foreach my $line (@$lines) {
  print "$line\n";
}
