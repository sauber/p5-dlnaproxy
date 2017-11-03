# Emulate a NIC

package App::DLNAProxy::Mock::Interface;

use Moo;
use namespace::clean;

with ('App::DLNAProxy::Interface');

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

1;
