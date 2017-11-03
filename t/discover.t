#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Medium' );
use_ok( 'App::DLNAProxy::Mock::Socket' );
use_ok( 'App::DLNAProxy::Discover' );

my $socket = new_ok 'App::DLNAProxy::Mock::Socket', [];
my $interf = new_ok 'App::DLNAProxy::Mock::Medium', [interfaces=>[]];

my $disc = new_ok 'App::DLNAProxy::Discover', [
  socket     => $socket,
  interfaces => $interf,
];

# When App starts, a server announcement is sent on each interface
# 

done_testing;
