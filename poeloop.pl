#!/usr/bin/env perl

########################################################################
###
### TCP Proxy
###
########################################################################

package DP::PROXY;

use Moose;
use MooseX::Method::Signatures;
use POE qw(Component::Server::TCP);
use Socket 'unpack_sockaddr_in';

use constant _DEBUG             => 1;

has remote_address => ( is=>'ro', isa=>'Str',      required=>1 );
has remote_port    => ( is=>'ro', isa=>'Int',      required=>1 );
has bind_port      => ( is=>'rw', isa=>'Int',                  );
has message        => ( is=>'ro', isa=>'Str',      required=>1 );
has ssdp           => ( is=>'ro', isa=>'DP::SSDP', required=>1 );

method launch {
 POE::Component::Server::TCP->new(
    #Port => 12345,
    ClientConnected => sub {
      warn "*** got a connection from $_[HEAP]{remote_ip}\n" if _DEBUG;
      $_[HEAP]{client}->put("Smile from the server!");
    },
    ClientInput => sub {
      my $client_input = $_[ARG0];
      $client_input =~ tr[a-zA-Z][n-za-mN-ZA-M];
      $_[HEAP]{client}->put($client_input);
    },
    Started => sub {
      my $listener = $_[HEAP]{listener};
      my ($port, $addr) = unpack_sockaddr_in($listener->getsockname);
      $self->bind_port( $port );
      $self->_started;
    },
  );
  return $self;
}

# When a listening port is known, publish it
#
method _started {

  warn "*** $self started listener on port " . $self->bind_port . "\n"
    if _DEBUG;
  $self->ssdp->send_location( $self->message, $self->bind_port );
}

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
use IO::Interface::Simple;

use constant _DEBUG             => 1;
use constant _DATAGRAM_MAXLEN   => 1024;
use constant _MCAST_GROUP       => '239.255.255.250';
use constant _MCAST_PORT        => 1900;
use constant _MCAST_DESTINATION => _MCAST_GROUP . ':' . _MCAST_PORT;
use constant _DISCOVER_INTERVAL => 10;
use constant _DISCOVER_PACKET   => 
'M-SEARCH * HTTP/1.1
Host: ' . _MCAST_DESTINATION . '
Man: "ssdp:discover"
ST: upnp:rootdevice
MX: 3

';

has _session => ( is=>'ro', isa=>'POE::Session', lazy_build=>1 );
method _build__session {
  POE::Session->create(
    object_states => [
      $self => [ qw(_start _discover _read _read_location) ]
    ]
  ) or die $!;
}

has _socket => ( is=>'ro', isa=>'IO::Socket::Multicast', lazy_build=>1 );
method _build__socket {
  IO::Socket::Multicast->new(
    LocalPort => _MCAST_PORT,
    ReuseAddr => 1,
    ReusePort => 1,
  ) or die $!;
}

# A list of all network interfaces capable of multicast
#
has _interfaces => ( is=>'ro', isa=>'ArrayRef', auto_deref=>1, lazy_build=>1 );
method _build__interfaces {
  [ 
    grep $_->address, 
    grep $_->is_multicast, 
    IO::Interface::Simple->interfaces 
  ];
}

# A list of proxy servers, one for each known DLNA server
#
has _proxy => ( is=>'ro', isa=>'HashRef[DP::PROXY]', default=>sub{{}} );

# Check if two IP's are on same subnet
#
sub _same_subnet {
  my($ip1,$ip2,$mask) = map inet_aton($_), @_;

  ( $ip1 & $mask ) eq
  ( $ip2 & $mask )
}

# From a Location packet, extract the http address and cache time-out
#
sub _extract_location {
  my $message = shift;

  $message =~ m,LOCATION:.*http://(.*?):(\d+)/,i;
  my $address = $1; my $port = $2; 
  $message =~ m,CACHE-CONTROL:.*max-age=(\d+),i;
  my $timeout = $1;
  return($address, $port, $timeout);
}

# Announce to the world that we are looking for servers
#
sub _discover {
  my($self, $kernel, $sender, $message) = @_[OBJECT, KERNEL, ARG0, ARG1];

  my $sock = $self->_socket;
  for my $if ( $self->_interfaces ) {
    # Make sure to not send to same interface where packet was received
    next if $sender and _same_subnet($sender, $if->address, $if->netmask);

    $sock->mcast_if($if)
      or warn $!;
    $sock->mcast_send(_DISCOVER_PACKET, _MCAST_DESTINATION)
      or warn $!;

    warn "*** pid $$ sent discover on $if at " . time() . "\n" if _DEBUG;
  }

  $kernel->delay(_discover => _DISCOVER_INTERVAL); # Cancels previous timer
}

sub _read {
  my ($kernel, $socket) = @_[KERNEL, ARG0];

  my $remote_address = recv($socket, my $message = "", _DATAGRAM_MAXLEN, 0);
  die $! unless defined $remote_address;

  # Take action depending on packet content
  if ( $message =~ /M-SEARCH/i ) {
    $kernel->yield('_discover', $remote_address, $message);
  } elsif ( $message =~ /LOCATION:/i ) {
    $kernel->yield('_read_location', $message);
  } else {
    my ($peer_port, $peer_addr) = unpack_sockaddr_in($remote_address);
    my $human_addr = inet_ntoa($peer_addr);
    warn "*** received unknown packet from $human_addr : $peer_port ... $message\n" if _DEBUG;
  }
}

# We have received a location packet.
#
sub _read_location {
  my($self, $message) = @_[OBJECT, ARG0];

  my($address,$port,$timeout) = _extract_location($message);
  my $dest = "$address:$port";
  warn "*** Location from server $dest cache $timeout\n" if _DEBUG;

  if ( $self->_proxy->{$dest} ) {
    warn "***   already known\n";
    $self->send_location( $message, $self->_proxy->{$dest}->bind_port );
    # XXX refresh timeout
  } else {
    $self->_proxy->{$dest} = DP::PROXY->new(
      remote_address => $address,
      remote_port    => $port,
      ssdp           => $self,
      message        => $message,
    )->launch;
    warn "***   created new listener\n";
  }
}

# We have set up a listener for a remote location. Announce it's presence.
#
method send_location ( Str $message, Int $listenport ) {
  my($remote_address,$remote_port,$timeout) = _extract_location($message);

  my $sock = $self->_socket;
  for my $if ( $self->_interfaces ) {
    my $ifaddress = $if->address;
    next if _same_subnet($remote_address, $ifaddress, $if->netmask);
    my $newmessage = $message;
    $newmessage =~ s,(LOCATION.*http:)//([0-9a-z.]+)[:]*([0-9]*)/,$1//$ifaddress:$listenport/,i;
    $sock->mcast_if($if);
    $sock->mcast_send($newmessage, _MCAST_DESTINATION );
    warn "*** LOCATION packet rewritten to $ifaddress:$listenport and sent on $if\n";
  }
}



sub _start {
  my($self, $kernel) = @_[OBJECT, KERNEL];

  warn "*** $self session called _start\n" if _DEBUG;

  # With the session started, tell kernel to call "read" sub
  # when data arrives on socket.
  $kernel->select_read($self->_socket, '_read');

  # Start sending out discovery packets
  $kernel->yield('_discover');

  warn "*** $self session ended _start\n" if _DEBUG;
}

method run {
  $self->_session;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

DP::SSDP->new->run;
