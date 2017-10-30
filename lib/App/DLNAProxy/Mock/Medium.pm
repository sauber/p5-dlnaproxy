package App::DLNAProxy::Mock::Medium;

use Moo;
use namespace::clean;

has packets => ( is=>'ro', default=>sub {[]} );
has discovery_packet => ( is=>'ro', default=>"M-SEARCH" );
has reader => ( is=>'rw', default=>sub {} );

# Send a discovery packet on all interfaces
#
sub broadcast_discovery {
  my $self = shift;
  push @{ $self->packets }, $self->discovery_packet;
}

# Resend a packet on all interfaces except where it came from
#
sub distribute {
  my $self = shift;
  my $packet = shift;
  push @{ $self->packets }, $packet;
}

sub read {
  my $self = shift;
  my $packet = shift;

  $self->reader->( $packet );
}

1;
