#!/usr/bin/env perl

#use warnings;
#use strict;

########################################################################
###
### A SSDP Server that listens for and sends multicast packages
###
########################################################################

package DP::SSDP;

use Moose;
use MooseX::Method::Signatures;
use POE;
use IO::Socket::Multicast;

use constant DEBUG             => 1;
use constant DATAGRAM_MAXLEN   => 1024;
use constant MCAST_PORT        => 1900;
use constant MCAST_GROUP       => '239.255.255.250';
use constant MCAST_DESTINATION => MCAST_GROUP . ':' . MCAST_PORT;
use constant DISCOVER_INTERVAL => 10;
use constant DISCOVER_PACKET   => 
'M-SEARCH * HTTP/1.1
Host: ' . MCAST_GROUP . ':' . MCAST_PORT . '
Man: "ssdp:discover"
ST: upnp:rootdevice
MX: 3

';

has _session => ( is=>'ro', isa=>'POE::Session', lazy_build=>1 );
method _build__session {
  POE::Session->create(
    object_states => [
      $self => [ qw(_start discover read) ]
    ]
  ) or die $!;
}

has _socket => ( is=>'ro', isa=>'IO::Socket::Multicast', lazy_build=>1 );
method _build__socket {
  IO::Socket::Multicast->new(
    LocalPort => MCAST_PORT,
    ReuseAddr => 1,
    ReusePort => 1,
  ) or die $!;
}

# Announce to the world that we are looking for servers
#
sub discover {
  my($self, $kernel) = @_[OBJECT,KERNEL];

  warn $! unless
    $self->_socket->mcast_send(DISCOVER_PACKET, MCAST_DESTINATION);

  warn "*** pid $$ sent discover at " . time() . "\n" if DEBUG;
  $kernel->delay(discover => DISCOVER_INTERVAL);
}

sub read {
  my ($kernel, $socket) = @_[KERNEL, ARG0];

  my $remote_address = recv($socket, my $message = "", DATAGRAM_MAXLEN, 0);
  die $! unless defined $remote_address;

  chomp $message;

  my ($peer_port, $peer_addr) = unpack_sockaddr_in($remote_address);
  my $human_addr = inet_ntoa($peer_addr);

  print "received from $human_addr : $peer_port ... $message\n";
}


sub _start {
  my($self, $kernel) = @_[OBJECT, KERNEL];

  warn "*** $self session called _start\n" if DEBUG;

  # With the session started, tell kernel to call "read" sub
  # when data arrives on socket.
  $kernel->select_read($self->_socket, "read");

  # Start sending out discovery packets
  $kernel->yield('discover');

  warn "*** $self session ended _start\n" if DEBUG;
}

method run {
  $self->_session;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

DP::SSDP->new->run;
