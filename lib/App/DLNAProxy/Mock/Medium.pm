package App::DLNAProxy::Mock::Medium;

use Moo;
use namespace::clean;

has packets => ( is=>'ro', default=>sub {[]} );
has discovery_packet => ( is=>'ro', default=>"M-SEARCH" );

sub broadcast_discovery {
  my $self = shift;
  push @{ $self->packets }, $self->discovery_packet;
}

1;
