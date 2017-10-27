#!perl -T

use Test::More;

use_ok( 'App::DLNAProxy::Mock::Socket' );

my $sock = new_ok 'App::DLNAProxy::Mock::Socket', [];
#my $sock = 'App::DLNAProxy::Mock::Socket'->new();

# Test methods
ok $sock->mcast_if($if);
ok $sock->mcast_send($if);
ok $sock->mcast_add($if);

done_testing;
