package App::DLNAProxy::Mock::Medium; 

use Moo;
use namespace::clean;
use App::DLNAProxy::Mock::Interface;

with ('App::DLNAProxy::Medium');

has interfaces => ( is=>'ro', required=>1, coerce=>sub {[
  map App::DLNAProxy::Mock::Interface->new($_), @{$_[0]}
]} );
#has packets => ( is=>'ro', default=>sub {[]} );
#has discovery_packet => ( is=>'ro', default=>"M-SEARCH" );
#has reader => ( is=>'rw', default=>sub {} );

# Number of interfaces
#
#sub count {
#  return scalar @{shift->interfaces};
#}

#sub get {
#}

# Send a message on all interfaces
#
#sub broadcast {
#  my($self, $message) = @_;
#  $_->send($message) for @{$self->interfaces};
#}

# Resend a packet on all interfaces except where it came from
#
sub distribute {
  my($self, $message, $ifname) = @_;
  #push @{ $self->packets }, $packet;
  $_->send($message) for
    grep { not defined $ifname or $_->name ne $ifname }
    @{$self->interfaces};
  return 1;
}
sub broadcast { distribute(@_) }

# Send a message on a named interface
#
sub send {
  my($self, $ifname, $message) = @_;
  $_->send($message) for grep { $_->name eq $ifname } @{$self->interfaces};
} 

sub read {
  my($self, $callback) = @_;
  $self->interfaces->reader->( $callback );
}

1;
