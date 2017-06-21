########################################################################
###
### A SSDP Server that detects DLNA servers, relay announcements
### and establish tcp proxy servers for data
###
########################################################################

package App::DLNAProxy;

use Moose;
use MooseX::Method::Signatures;
use POE;
use App::DLNAProxy::Discover;

# A discovery agent
#
has _discover => (is=>'ro', isa=>'App::DLNAProxy::Discover', lazy_build=>1);
method _build__discover { App::DLNAProxy::Discover->new }

method start {
  $self->_discover;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

