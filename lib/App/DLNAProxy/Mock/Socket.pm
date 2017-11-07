package App::DLNAProxy::Mock::Socket;

use Moo;
extends 'App::DLNAProxy::Socket';
use namespace::clean;

has interfaces => ( is=>'ro', required=>1 );

sub mcast_send {
  my($self, $message, $destination) = @_;

  my($if) = grep { $_->name eq $self->mcast_if } @{$self->interfaces->interfaces};
  $if->send($message);
}

1;
