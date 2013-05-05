#!/usr/bin/env perl

########################################################################
###
### TCP Proxy Server
###
########################################################################

# Terminology
# _proxy_listener:                  Accept   connection from remote clients
# _remote_client -> _proxy_server:  Incoming connection from remote client
# _proxy_client  -> _remote_server: Outgoing connection to   remote server
# 

package DP::Proxy;

BEGIN { require 'sub_x.pm' };

use Moose;
use MooseX::Method::Signatures;
use POE qw(Component::Server::TCP Wheel::ReadWrite);
use Socket 'unpack_sockaddr_in';

use constant _DEBUG => 1;

# Required parameters is address and port of remote server
# and a callback sub to announce port number of listener
#
has remote_server_address  => ( is=>'ro', isa=>'Str',     required=>1 );
has remote_server_port     => ( is=>'ro', isa=>'Int',     required=>1 );
has proxy_listener_started => ( is=>'ro', isa=>'CodeRef', required=>1 );

# After we know the callback of where to send port number to
has proxy_listener_port   => ( is=>'rw', isa=>'Int',                  );
#has message        => ( is=>'ro', isa=>'Str',      required=>1 );
#has ssdp           => ( is=>'ro', isa=>'DP::SSDP', required=>1 );

# A listener to accept incoming connections
#
method BUILD {

  warn "*** Building a listener\n";
  POE::Component::Server::TCP->new(
    #ClientInput     => sub { $self->_remote_client_read( $_[HEAP], $_[ARG0] ) },
    #ClientConnected => sub { $self->_remote_client_connection(  $_[HEAP]           ) },

    # The listener is now up and running and port is identified
    #
    Started => sub {
      my ($proxy_listener_port, $proxy_listener_addr) =
        unpack_sockaddr_in( $_[HEAP]{listener}->getsockname );
      $self->proxy_listener_port( $proxy_listener_port );
      warn sprintf
        "*** listener started on port %s for remote server %s:%s\n",
        $proxy_listener_port,
        $self->remote_server_address,
        $self->remote_server_port;
      $self->proxy_listener_started->($proxy_listener_port);
      #x 'callback', $self->proxy_listener_started;
      #my $callback = $self->proxy_listener_started;
      #warn "*** callback port to $callback\n";
      #$callback->($proxy_listener_port);
    },

    # Data arrived from client. Send to Server.
    #
    ClientInput => sub {
      my($kernel, $heap, $message) = @_[KERNEL, HEAP, ARG0];
      my $size = length $message;
      warn "*** Got $size bytes from client heap $heap\n";
      $heap->{remote_server} ||= $self->_proxy_client_create( $heap->{client} );
      #x remote_server => $heap->{remote_server};
      $kernel->post($heap->{remote_server}, '_remote_server_send', $message);
    },

    ClientDisconnected => sub {
      my($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
      warn "*** client has disconnected, shutting down server connection\n";
      $kernel->post($heap->{remove_server}, 'shutdown');
    },

    #InlineStates    => {
    #  _remote_client_send => sub {
    #    my ( $heap, $message ) = @_[ HEAP, ARG0 ];
    #    my $size = length $message;
    #    warn("*** sending $size bytes to client");
    #    $heap->{client}->put($message);
    #  },
    #},
  );
}

method _proxy_client_create ( Ref $remote_client ) {
  warn "Creating proxy client for remote client $remote_client\n";
  POE::Component::Client::TCP->new(
    RemoteAddress => $self->remote_server_address,
    RemotePort    => $self->remote_server_port,

    Connected => sub {
      my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
      warn sprintf "*** connected to %s:%s\n",
        $self->remote_server_address, $self->remote_server_port;
      # Flush buffer of messages while connecting
      while ( my $message = shift @{ $heap->{buffer} } ) {
        warn "*** Flushing buffer $message\n";
        $heap->{server}->put( $message );
      }
      delete $heap->{buffer};
    },

    ServerInput   => sub {
      # Got data form server, send to client
      my ( $kernel, $heap, $message ) = @_[ KERNEL, HEAP, ARG0 ];
      my $size = length $message;
      warn "*** Received $size bytes from server heap $heap\n";
      warn $message;
      $remote_client->put( $message );
    },

    InlineStates => {
      # Data to be sent to server from client.
      #
      _remote_server_send => sub {
        my ( $heap, $message ) = @_[ HEAP, ARG0 ];
        #x heap => $heap;
        if ( $heap->{connected} ) {
          warn "*** sending to server: $message\n";
          $heap->{server}->put($message);
        } else {
          # Buffer up because not yet connected
          warn "*** buffer to server: $message\n";
          push @{ $heap->{buffer} }, $message;
        }
      },
    },

    Disconnected => sub {
      warn "*** Server disconnected\n";
      $remote_client->shutdown;
    },
  )
}

# When a listening port is known, publish it
#
#method _started ( Ref $listener ) {
#  my ($port, $addr) = unpack_sockaddr_in($listener->getsockname);
#  $self->bind_port( $port );
#  warn "*** $self started listener on port " . $self->bind_port . "\n"
#    if _DEBUG;
#  $self->ssdp->send_location( $self->message, $self->bind_port );
#}

# A new client has connected. Hook it up with a server end.
#
#method _connection ( HashRef $heap ) {
#  my $client = $heap->{client};
#  warn "*** Connected client $client to $self->remote_address:$self->remote_address\n" if _DEBUG;
#  #$heap->{proxy_client} = DP::Connection->new(
#  #   client         => $client,
#  #   remote_address => $self->remote_address,
#  #   remote_port    => $self->remote_port,
#  #);
#}

# Make a client connection component session to server
#
#method _create_server_connection {
#  POE::Component::Client::TCP->new(
#    RemoteAddress => $self->remote_address,
#    RemotePort    => $self->remote_port,
#    Started       => sub {
#      my($kernel, $heap, $inner_self) = @_[ KERNEL, HEAP, ARG0];
#      $heap->{parent_client_session} = $session_id;
#      $heap->{self} = $inner_self;
#      $heap->{is_connected_to_server} = 0;
#      warn("*** started session $session_id to $inner_self->{orig_address}:$inner_self->{orig_port}");
#    },
#    Connected => sub {
#      my ( $kernel, $heap) = @_[ KERNEL, HEAP];
#      $heap->{is_connected_to_server} = 1;
#      $heap->{parent_client_session} = $session_id;
#      warn(sprintf "*** connected to %s:%s\n", $self->remote_address, $self->remote_port);
#    },
#    ServerInput => sub {
#      my ( $kernel, $heap, $input ) = @_[ KERNEL, HEAP, ARG0 ];
#      if (defined($input)) {
#        dbprint(3, "Input from remote server $self->{orig_address} :",
#                "$self->{orig_port}: -$input- sending to",
#                "remote client and any callback");
#        $kernel->post($heap->{parent_client_session},
#                            "send_client", $input);
#        $self->{data_from_server}->($input);
#      } else {
#        dbprint(1, "ServerInput event but no input!");
#      }
#    },
#
#
#
#
#
#  );
#}
#
#method _clientinput ( HashRef $heap, Str $message ) {
#  my $session = $heap->{
#  warn "*** Input from heap $heap\n" if _DEBUG;
#}
#
#method launch {
#  $self->_listener
#  return $self;
#} 

#method BUILD {
  #$self->_proxy_listener
#}

__PACKAGE__->meta->make_immutable;


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
use constant _DISCOVER_INTERVAL => 30; # 1800;
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
has _proxy => ( is=>'ro', isa=>'HashRef[DP::Proxy]', default=>sub{{}} );

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
    $self->send_location( $message, $self->_proxy->{$dest}->proxy_listener_port );
    # XXX refresh timeout
  } else {
    $self->_proxy->{$dest} = DP::Proxy->new(
      remote_server_address => $address,
      remote_server_port    => $port,
      #ssdp           => $self,
      #message        => $message,
      #started        => sub { $self->send_location( $message ) },
      proxy_listener_started => sub { $self->send_location( $message, @_ ) },
      #proxy_listener_started => sub { warn sprintf "Called back with %s\n", join ',', @_, $message },
    );
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

method BUILD {
  $self->_session;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

DP::SSDP->new;
