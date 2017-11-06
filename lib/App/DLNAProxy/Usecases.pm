package App::DLNAProxy::Usecases;

use Moo;
use App::DLNAProxy::Message;
use namespace::clean;

has interfaces         => ( is=>'ro', required=>1 );
has timer              => ( is=>'ro', required=>1 );
has discovery_interval => ( is=>'ro', default=>900 );

# Discovery messages are sent regularly
#
sub start_discovery {
  my $self = shift;

  $self->timer->timed(
    $self->discovery_interval,
    sub {
      my $message = App::DLNAProxy::Message->new(body=>"search");
      for my $if ( @{$self->interfaces->interfaces} ) {
        $if->send($message);
      }
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
    for my $if ( @{$self->interfaces->interfaces} ) {
      next if $if->name eq $message->if->name;
      $if->send($message);
    }
  };

  # Register handler in medium
  $self->medium->reader( $callback );
}

1;
