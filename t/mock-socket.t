#!perl -T

use warnings;
use strict;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Socket' );

my $sock = new_ok 'App::DLNAProxy::Mock::Socket', [ LocalPort=>1900, ReuseAddr=>1 ];

# Test methods
ok $sock->mcast_if('eth0'), 'Change if for sending';
ok $sock->mcast_send('message', 'dest:port'), 'Send message to destination address and port';
ok $sock->mcast_add('group'), 'Add group';

done_testing;
