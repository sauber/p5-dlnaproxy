#!/usr/bin/env perl

use warnings;
use strict;

use POE;
use IO::Socket::Multicast;

use constant DATAGRAM_MAXLEN   => 1024;
use constant MCAST_PORT        => 1900;
use constant MCAST_GROUP       => '239.255.255.250';
use constant MCAST_DESTINATION => MCAST_GROUP . ':' . MCAST_PORT;

POE::Session->create(
  inline_states => {
    _start         => \&peer_start,
    get_datagram   => \&peer_read,
    send_something => \&send_something,
  }
);

POE::Kernel->run();
exit;

### Set up the peer socket.

sub peer_start {
  my $kernel = $_[KERNEL];

  # Don't specify an address.
  my $socket = IO::Socket::Multicast->new(
    LocalPort => MCAST_PORT,
    ReuseAddr => 1,
    ReusePort => 1,
  ) or die $!;

  $socket->mcast_add(MCAST_GROUP) or die $!;

  # Don't mcast_loopback(0). 	This disables multicast datagram
  # delivery to all peers on the interface.  Nobody gets data.

  # Begin watching for multicast datagrams.
  $kernel->select_read($socket, "get_datagram");

  # Send something once a second.  Pass the socket as a continuation.
  $kernel->delay(send_something => 1, $socket);
}

### Receive a datagram when our sicket sees it.

sub peer_read {
  my ($kernel, $socket) = @_[KERNEL, ARG0];

  my $remote_address = recv($socket, my $message = "", DATAGRAM_MAXLEN, 0);
  die $! unless defined $remote_address;

  chomp $message;

  my ($peer_port, $peer_addr) = unpack_sockaddr_in($remote_address);
  my $human_addr = inet_ntoa($peer_addr);

  print "received from $human_addr : $peer_port ... $message\n";
}

### Periodically send something.

sub send_something {
  my ($kernel, $socket) = @_[KERNEL, ARG0];

  my $message = "pid $$ sending at " . time() . " to " . MCAST_DESTINATION;
  warn $! unless $socket->mcast_send($message, MCAST_DESTINATION);

  $kernel->delay(send_something => 1, $socket);
}
