package App::DLNAProxy::Usecases;

use Moo;
use namespace::clean;
use App::DLNAProxy::Message;

has medium => ( is=>'ro', required=>1 );
has timer  => ( is=>'ro', required=>1 );
has discovery_interval => ( is=>'ro', default=>900 );

# Discovery messages are sent regularly
#
sub start_discovery {
  my $self = shift;

  my $message = App::DLNAProxy::Message->new(body=>"search");
  my $callback = sub { $self->medium->broadcast($message) };
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
