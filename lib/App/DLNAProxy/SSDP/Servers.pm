########################################################################
###
### Servers that are announcing locations
###
########################################################################

package App::DLNAProxy::SSDP::Servers;

use Moose;
use MooseX::Method::Signatures;
use MooseX::Singleton;
use App::DLNAProxy::SSDP::Server;
use App::DLNAProxy::Log;

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

has _servers => ( is=>'ro', isa=>'HashRef', default=>sub{{}} );

# Register a new server

# XXX: The address where announcement comes from has a port that keeps changing
# so cannot use as identifier? Perhaps use IP without port.
# But there might be several servers on same IP.
# And each may have different IP for location.
# While parsing results, there may be additional IP/port locations
# that need proxy setup for same "server".
#
method add ( Object $announcement, CodeRef $callback ) {
  x trace => 'Adding new announcement';
  my $ip   = $announcement->location_address;
  my $port = $announcement->location_port;
  my $label = "$ip:$port";
  if ( $self->_servers->{$label} ) {
    x trace => 'Proxy exists';
    $callback->();
  } else {
    x trace => 'Creating new proxy';
    $self->_servers->{$label} =
      App::DLNAProxy::SSDP::Server->new(
         address  => $ip,
         port     => $port,
         callback => $callback,
      );
  }
}

# List of all waiting clients
# Expire if more than 1 min old
#
method all {
  values %{ $self->_servers };
}

# List of all that all servers have set up
#
method proxies {
  # TODO
}

# Find a proxy for a particular location
#
method proxy_for ( Str $ip, Int $port ) {
  for my $server ( values %{ $self->_servers } ) {
    for my $proxy ( $server->proxies ) {
      return $proxy if $proxy->address eq $ip and $proxy->port eq $port;
    }
  }
}

__PACKAGE__->meta->make_immutable;
