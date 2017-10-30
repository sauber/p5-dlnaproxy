package App::DLNAProxy::Usecases;

use Moo;
use namespace::clean;

has medium => ( is=>'ro', required=>1 );
has timer  => ( is=>'ro', required=>1 );
has discovery_interval => ( is=>'ro', default=>900 );

# Discovery messages are sent regularly
#
sub regular_discovery {
  my $self = shift;

  my $callback = sub { $self->medium->broadcast_discovery };
  $self->timer->timed( $self->discovery_interval, $callback );
}

# When discovery is received, resend to all other interfaces
#
sub read_discovery {
  my $self = shift;

  # Closure to handle incoming packets
  my $callback = sub {
    my $packet = shift;
    $self->medium->distribute( $packet );
  };

  # Register handler in medium
  $self->medium->reader( $callback );
}

1;
