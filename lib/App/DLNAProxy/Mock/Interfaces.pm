# Emulate a NIC

package App::DLNAProxy::Mock::Interface;

use Moo;
use namespace::clean;

# Required input
has name         => ( is=>'ro', required=>1 );
has is_multicast => ( is=>'ro', required=>1 );
has address      => ( is=>'ro', required=>1 );
has netmask      => ( is=>'ro', required=>1 );

# Packet buffer
has _incoming => ( is=>'ro', default=>sub{[]} );
has _outgoing => ( is=>'ro', default=>sub{[]} );

# Send a packet
#
sub send {
  my $self = shift;
  push @{ $self->_outgoing }, shift;
}

# Receive a packet
#
sub receive {
  my $self = shift;
  push @{ $self->_incoming }, shift;
}

# Fetch a received packet
#
sub fetch {
  my $self = shift;
  shift @{ $self->_incoming };
}


########################################################################

# Mock package to present list of mock interfaces

package App::DLNAProxy::Mock::Interfaces;

use App::DLNAProxy::Interfaces;
use App::DLNAProxy::Mock::Interface;
our @ISA = qw(App::DLNAProxy::Interfaces);

sub new {
  my $class = shift;
  my $array = shift;
  return bless $array, $class;
}

sub interfaces {
  my $self = shift;
  map App::DLNAProxy::Mock::Interface->new($_), @$self;
}

1;
