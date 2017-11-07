package App::DLNAProxy::Usecases;

use Moo;
use App::DLNAProxy::Message;
use namespace::clean;

has socket             => ( is=>'ro', required=>1 );
has timer              => ( is=>'ro', required=>1 );
has discovery_interval => ( is=>'ro', default=>900 );

# Discovery messages are sent regularly
#
sub start_discovery {
  my $self = shift;

  $self->timer->timed(
    $self->discovery_interval,
    sub {
      my $message = App::DLNAProxy::Message->new(body=>"search", is_multicast=>1);
      $self->socket->broadcast($message);
    }
  );
}

# When discovery is received, resend to all other interfaces
#
sub read_discovery {
  my $self = shift;

  # Closure to handle incoming packets
  my $callback = sub {
    my $message = shift;
    $self->socket->distribute($message);
  };

  # Register handler in medium
  $self->medium->reader( $callback );
}

1;
