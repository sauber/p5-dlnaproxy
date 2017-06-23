#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use_ok( 'App::DLNAProxy' );
my $app = new_ok 'App::DLNAProxy';

# When App starts, a server announcement is sent on each interface
# 

done_testing;
