#!perl -T

use strict;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Interfaces' );
use_ok( 'App::DLNAProxy::Message' );

# A network of 0 interfaces
my $if0 = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[]];
is @{$if0->interfaces}, 0, "0 interfaces";

# A network of 1 interface
my $if1 = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[
  { name=>'eth0', is_multicast=>1, address=>'5.10.30.55', netmask=>'255.255.255.224' },
]];
is @{$if1->interfaces}, 1, "1 interface";

# A network of 2 interfaces
my $if2 = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[
  { name=>'eth0', is_multicast=>1, address=>'5.10.30.55', netmask=>'255.255.255.224' },
  { name=>'eth1', is_multicast=>1, address=>'5.10.40.55', netmask=>'255.255.255.192' },
]];
is @{$if2->interfaces}, 2, "2 interfaces";
#diag explain $if2;

# Check properties of interface
#my($if) = $ifs->interfaces;
#is $if->name,         'eth0',            'interface name';
#is $if->is_multicast, 1,                 'interface is_multicast';
#is $if->address,      '5.10.30.55',      'interface address';
#is $if->netmask,      '255.255.255.224', 'interface netmask';

# Send and receive packets on interface
#my $message = new_ok 'App::DLNAProxy::Message', [ body=>'Hello' ];
#ok $if->send( $message ), 'send message';
#ok $if->receive( $message ), 'receive message';
#is $if->fetch->body, 'Hello', 'fetched message body';

# Brodcast a packet
#my $message = new_ok 'App::DLNAProxy::Message', [ body=>'Hello' ];
#ok $if2->broadcast($message), 'message is broadcasted';
#ok $if2->distribute($message), 'message is distributed';


done_testing;
