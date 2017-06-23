########################################################################
###
### A SSDP Server that detects DLNA servers, relay announcements
### and establish tcp proxy servers for data
###
########################################################################

package App::DLNAProxy;

use Moose;
use MooseX::Method::Signatures;
use IO::Socket::Multicast;
use App::DLNAProxy::Interfaces;
use App::DLNAProxy::Discover;

use constant _MCAST_PORT        => 1900;

# Build a socket interface
#
has _socket => ( is=>'ro', isa=>'IO::Socket::Multicast', lazy_build=>1 );
method _build__socket {
  IO::Socket::Multicast->new(
    LocalPort => _MCAST_PORT,
    ReuseAddr => 1,
    #ReusePort => 1,
  ) or die $!;
}

# A list of all network interfaces capable of multicast
#
has _interfaces => (is=>'ro',isa=>'App::DLNAProxy::Interfaces',lazy_build=>1);
method _build__interfaces { App::DLNAProxy::Interfaces->instance }

# A discovery agent
#
has _discover => (is=>'ro', isa=>'App::DLNAProxy::Discover', lazy_build=>1);
method _build__discover { App::DLNAProxy::Discover->new(
  socket     => $self->_socket,
  interfaces => $self->_interfaces,
)}

method start {
  $self->_discover->start;

  #POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

