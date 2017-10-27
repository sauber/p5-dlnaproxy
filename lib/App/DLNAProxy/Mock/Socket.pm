package App::DLNAProxy::Mock::Socket;

#$INC{'IO/Socket/Multicast.pm'} = 1;
use IO::Socket::Multicast;
our @ISA = qw(IO::Socket::Multicast);

sub new {
  return bless {}, shift;
}

sub mcast_if {
  my($self, $if) = @_;
}

sub mcast_send {
  my($self, $if) = @_;
}

sub mcast_add {
  my($self, $if) = @_;
}

1;
