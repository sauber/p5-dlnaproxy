#!perl -T

use Test::More;

use_ok( 'App::DLNAProxy::Mock::Interfaces' );
use_ok( 'App::DLNAProxy::Message' );

# 0 interfaces
my $ifs = new_ok 'App::DLNAProxy::Mock::Interfaces', [[]];
is $ifs->interfaces, 0, "0 interfaces";

# 1 interface
my $ifs = new_ok 'App::DLNAProxy::Mock::Interfaces', [[
  { name=>'eth0', is_multicast=>1, address=>'5.10.30.55', netmask=>'255.255.255.224' },
]];
is $ifs->interfaces, 1, "1 interface";

# 2 interfaces
my $ifs = new_ok 'App::DLNAProxy::Mock::Interfaces', [[
  { name=>'eth0', is_multicast=>1, address=>'5.10.30.55', netmask=>'255.255.255.224' },
  { name=>'eth1', is_multicast=>1, address=>'5.10.40.55', netmask=>'255.255.255.192' },
]];
is $ifs->interfaces, 2, "2 interfaces";

# Check properties of interface
my($if) = $ifs->interfaces;
is $if->name,         'eth0',            'interface name';
is $if->is_multicast, 1,                 'interface is_multicast';
is $if->address,      '5.10.30.55',      'interface address';
is $if->netmask,      '255.255.255.224', 'interface netmask';

# Send and receive packets
my $message = new_ok 'App::DLNAProxy::Message', [ body=>'Hello' ];
ok $if->send( $message ), 'send message';
ok $if->receive( $message ), 'receive message';
is $if->fetch->body, 'Hello', 'fetched message body';

done_testing;
