########################################################################
###
### Interfaces
###
########################################################################

package App::DLNAProxy::Interfaces;

use Moose;
use MooseX::Method::Signatures;
use IO::Interface::Simple;
use MooseX::Singleton;
use App::DLNAProxy::Log;

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

# A list of all network interfaces capable of multicast
#
has _interface_cache => ( is=>'ro', isa=>'HashRef', default=>sub{{}} );
method all {
  unless ( $self->_interface_cache->{timeout} and $self->_interface_cache->{timeout} > time ) {
    $self->_interface_cache->{timeout}    = time + 30;
    $self->_interface_cache->{interfaces} = [ 
      grep $_->address, 
      grep $_->is_multicast, 
      IO::Interface::Simple->interfaces 
    ];
    x trace => "session interface list refresh";
  }
  return @{ $self->_interface_cache->{interfaces} };
}

# Check if an ip belongs to an interface
#
method belong ( Object $if, Str $ip ) {
  $ip = inet_aton($ip) unless $ip =~ /^\d+\.\d+\.\d+\.\d+/;

  ( $ip          & $if->netmask ) eq
  ( $if->address & $if->netmask )
}

# Check if an IP can be reached directly on a interface
#
method direct ( Str $ip ) {
  for my $if ( $self->all ) {
    return 1==1 if $self->belong( $if, $ip );
  }
  return 1==0;
}

# Which interface does a particular IP belong to
#
method interface_for ( Str $ip ) {
  for my $if ( $self->all ) {
    return $if if $self->belong( $if, $ip );
  }
}

__PACKAGE__->meta->make_immutable;

