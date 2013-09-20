########################################################################
###
### Clients that are searching for SSDP servers
###
########################################################################

package App::DLNAProxy::SSDP::Clients;

use Moose;
use MooseX::Method::Signatures;
use App::DLNAProxy::SSDP::Client;

has _clients => (is=>'ro', isa=>'HashRef', default=>sub{{}} );

# Register a new client
#
method add ( Str $ip, Str $port ) {
  my $label = "$ip:$port";
  $self->_clients->{$label} = App::DLNAProxy::SSDP::Client->new(
    address => $ip,
    port    => $port,
  );
}

# List of all waiting clients
#
method all {
  map {
    if ( $self->_clients->{$_}->expired ) {
      # Remove expired clients from list
      delete $self->_clients->{$_};
      ();
    } else {
      $self->_clients->{$_};
    }
  }
  keys %{ $self->_clients };
}

__PACKAGE__->meta->make_immutable;
