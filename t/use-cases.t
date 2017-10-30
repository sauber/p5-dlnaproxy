#!perl -T

use Test::More;

use_ok( 'App::DLNAProxy::Mock::Medium' );
use_ok( 'App::DLNAProxy::Mock::Timer' );
use_ok( 'App::DLNAProxy::Usecases' );

my $medium = new_ok 'App::DLNAProxy::Mock::Medium', [];

my $api = new_ok 'App::DLNAProxy::Usecases', [
  discovery_interval => 2,
  medium => $medium,
  timer  => App::DLNAProxy::Mock::Timer->new,
];

### Discovery
# Discovery is sent regularly
ok $api->regular_discovery(), 'Setup regular discovery';
is @{ $medium->packets }, 2, 'There are two packets in discovery';
is $medium->packets->[0], $medium->discovery_packet, 'Packets are discovery format';

# Discovery is redistributed
# Announcements spawn proxies and rewrite
# Proxies expire if not renewed
# Announcements are redistributed

### Content
# Content spawn proxies and rewrite

### Media
# Data is streamed

### Proxy
# Expire if not renewed

done_testing;
