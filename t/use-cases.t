#!perl -T

use strict;
use Test::More;

use_ok( 'App::DLNAProxy::Mock::Interfaces' );
use_ok( 'App::DLNAProxy::Mock::Timer' );
use_ok( 'App::DLNAProxy::Usecases' );

my $interfaces = new_ok 'App::DLNAProxy::Mock::Interfaces', [interfaces=>[
  { name=>'eth0',  is_multicast=>1, address=>'5.1.30.1', netmask=>'255.255.255.224' },
  { name=>'wlan1', is_multicast=>1, address=>'5.1.40.2', netmask=>'255.255.255.192' },
  { name=>'tun2',  is_multicast=>1, address=>'5.1.50.3', netmask=>'255.255.255.128' },
]];

my $api = new_ok 'App::DLNAProxy::Usecases', [
  discovery_interval => 2,
  interfaces         => $interfaces,
  timer              => App::DLNAProxy::Mock::Timer->new,
];

# Find matching messages in interface buffers
#
sub _inspect {
  my($body, $buffername) = @_;
  my $bufname = "_$buffername";
  return {
    map { $_->name => [
      grep { $_->body eq $body }
      @{ $_->$bufname() }
    ] }
    @{$interfaces->interfaces}
  };
}

### Discovery

# Discovery is sent regularly on all interfaces
ok $api->start_discovery(), 'Setup regular discovery';

# Since this is fake medium, there should be two packets on each interface
my $result = _inspect('search', 'outgoing');
while ( my($if,$messages) = each %$result ) {
  is @{$messages}, 2, "Two packets on $if";
}

# Discovery is redistributed
# TODO: Distinguish specific interfaces
#ok $api->read_discovery, 'Setup reader for when packets are received';
#ok $medium->read( "Discovery" ), 'Receive a discovery packet';
#is $medium->packets->[-1], 'Discovery', 'Received packet is resent';

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
