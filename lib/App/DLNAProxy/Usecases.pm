package App::DLNAProxy::Usecases;

use Moo;
use namespace::clean;

has medium => ( is=>'ro', required=>1 );
has timer  => ( is=>'ro', required=>1 );
has discovery_interval => ( is=>'ro', default=>900 );

sub regular_discovery {
  my $self = shift;

  my $callback = sub { $self->medium->broadcast_discovery };
  $self->timer->timed( $self->discovery_interval, $callback );
}

1;
