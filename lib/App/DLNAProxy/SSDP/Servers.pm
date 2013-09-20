########################################################################
###
### Servers that are announcing locations
###
########################################################################

package App::DLNAProxy::SSDP::Servers;

use Moose;
use MooseX::Method::Signatures;
use App::DLNAProxy::SSDP::Server;

has _servers => ( is=>'ro', isa=>'HashRef', default=>sub{{}} );

# Register a new server
#
method add ( Str $ip, Str $port, CodeRef $callback ) {
  my $label = "$ip:$port";
  $self->_servers->{$label} ||=
    App::DLNAProxy::SSDP::Server->new(
    );

  $callback->();
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
