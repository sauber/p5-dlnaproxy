########################################################################
###
### A clients that is searching for SSDP servers
###
########################################################################

package App::DLNAProxy::SSDP::Client;

use Moose;
use MooseX::Method::Signatures;
use App::DLNAProxy::Interfaces;

use constant TIMEOUT => 60;
has address => ( is=>'ro', isa=>'Str', required=>1    );
has port    => ( is=>'ro', isa=>'Int', required=>1    );
has since   => ( is=>'ro', isa=>'Int',  default=>time );

# A list of all network interfaces capable of multicast
#
has _interfaces => (is=>'ro',isa=>'App::DLNAProxy::Interfaces',lazy_build=>1);
method _build__interfaces { App::DLNAProxy::Interfaces->instance }

# Check if client is expired
#
method expired { $self->since < time - TIMEOUT }

# Calculate which sender IP to use for this client
#
has sender_address => ( is=>'ro', isa=>'Str', lazy_build=>1 );
method _build_sender_address {
  for my $if ( $self->_interfaces->all ) {
    return $if->address if $$self->_interfaces->belong( $if, $self->addres );
  }
}

__PACKAGE__->meta->make_immutable;

