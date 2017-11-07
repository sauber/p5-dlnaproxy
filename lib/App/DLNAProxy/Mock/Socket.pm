package App::DLNAProxy::Mock::Socket;

use Moo;
extends 'App::DLNAProxy::Socket';
use namespace::clean;

has LocalPort => ( is=>'ro', required=>1 );
has ReuseAddr => ( is=>'ro', required=>1 );

sub mcast_if {
  my($self, $ifname) = @_;
}

sub mcast_send {
  my($self, $message, $destination) = @_;
}

sub mcast_add {
  my($self, $group) = @_;
}

1;
