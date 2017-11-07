#!perl -T

use warnings;
use strict;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Socket' );
use_ok( 'App::DLNAProxy::Mock::Interfaces' );
my $interfaces = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[
  { name=>'eth0',  is_multicast=>1, address=>'5.1.30.1', netmask=>'255.255.255.224' },
  { name=>'wlan1', is_multicast=>1, address=>'5.1.40.2', netmask=>'255.255.255.192' },
  { name=>'tun2',  is_multicast=>1, address=>'5.1.50.3', netmask=>'255.255.255.128' },
]];

my $sock = new_ok 'App::DLNAProxy::Mock::Socket', [ LocalPort=>1900, ReuseAddr=>1, interfaces=>$interfaces ];

# Test methods
ok $sock->mcast_if('eth0'), 'Change if for sending';
ok $sock->mcast_send('message', 'dest:port'), 'Send message to destination address and port';
ok $sock->mcast_add('group'), 'Add group';

done_testing;
