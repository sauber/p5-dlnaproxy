########################################################################
###
### A SSDP Announcement Packet
###
########################################################################

package App::DLNAProxy::SSDP::Announcement;

use Moose;
use MooseX::Method::Signatures;

has message        => (is=>'ro', isa=>'Str', required=>1);
has sender_address => (is=>'ro', isa=>'Str', required=>1);
has sender_port    => (is=>'ro', isa=>'Int', required=>1);

# A list of all network interfaces capable of multicast
#
use App::DLNAProxy::Interfaces;
has _interfaces => (is=>'ro',isa=>'App::DLNAProxy::Interfaces',lazy_build=>1);
method _build__interfaces { App::DLNAProxy::Interfaces->instance }

# A list of all known servers
#
use App::DLNAProxy::SSDP::Servers;
has _server => (is=>'ro',isa=>'App::DLNAProxy::SSDP::Servers',lazy_build=>1);
method _build__servers { App::DLNAProxy::SSDP::Servers->instance }
method _proxy ( Str $ip, Int $port ) { $self->_servers->proxy_for($ip,$port) }

# Extract location and timeout from package

has location_address => (is=>'ro', isa=>'Str', lazy_build=>1);
method _build_location_address {
  $self->message =~ m,LOCATION:.*http://(.*?):(\d+)/,i;
  return $1;
}

has location_port => (is=>'ro', isa=>'Int', lazy_build=>1);
method _build_location_port {
  $self->message =~ m,LOCATION:.*http://(.*?):(\d+)/,i;
  return $2;
}

has location_timeout => (is=>'ro', isa=>'Int', lazy_build=>1);
method _build_timeout {
  $self->message =~ m,CACHE-CONTROL:.*max-age=(\d+),i;
  return 1;
}

# Rewrite the message for a particular client
#
method rewrite ( Object $client ) {

  # Find out which interface the client is on
  my $address = $self->_interfaces->interface_for( $client->address )->address;

  # Find out which port number the proxy for location is running on
  my $port = $self-_proxy($self->location_address, $self->location_port)->port;

  my $msg = $self->message;
  $msg =~ s,(LOCATION.*http:)//([0-9a-z.]+)[:]*([0-9]*)/,$1//$address:$port/,i;
  return $msg;
}

__PACKAGE__->meta->make_immutable;
