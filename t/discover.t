#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Interfaces' );
use_ok( 'App::DLNAProxy::Mock::Socket' );
use_ok( 'App::DLNAProxy::Mock::Interfaces' );
my $interfaces = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[
  { name=>'eth0',  is_multicast=>1, address=>'5.1.30.1', netmask=>'255.255.255.224' },
  { name=>'wlan1', is_multicast=>1, address=>'5.1.40.2', netmask=>'255.255.255.192' },
  { name=>'tun2',  is_multicast=>1, address=>'5.1.50.3', netmask=>'255.255.255.128' },
]];
use_ok( 'App::DLNAProxy::Discover' );

my $socket = new_ok 'App::DLNAProxy::Mock::Socket', [ LocalPort=>1900, ReuseAddr=>1, interfaces=>$interfaces ];

#my $disc = new_ok 'App::DLNAProxy::Discover', [
#  socket     => $socket,
#  interfaces => $interf,
#];

# When App starts, a server announcement is sent on each interface
# 

done_testing;
