#!/usr/bin/env perl

use strict;
use warnings;
 
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Handle::UDP;
use AnyEvent::Socket;
use AnyEvent::Log;
use IO::Interface::Simple;
use IO::Socket::Multicast;
use threads;
use threads::shared;

use YAML;
$AnyEvent::Log::FILTER->level("info");
use AnyEvent::Debug;
our $SHELL = AnyEvent::Debug::shell "127.1", "1357";

our $GROUP = '239.255.255.250';
our $PORT  = '1900';

# Every known DLNA server has listener on seperate ports
#
our %LISTENER :shared;

# Get list of IP multicast capable network interfaces
#
sub interfacelist {
  grep $_->address, grep $_->is_multicast, IO::Interface::Simple->interfaces
}

my $sa_un_zero = eval { Socket::pack_sockaddr_un "" }; $sa_un_zero ^= $sa_un_zero;

sub unpack_sockaddr($) {
   my $af = sockaddr_family $_[0];

   if ($af == AF_INET) {
      Socket::unpack_sockaddr_in $_[0]
   } elsif ($af == AF_INET6) {
      unpack "x2 n x4 a16", $_[0]
   } elsif ($af == AF_UNIX) {
      ((Socket::unpack_sockaddr_un $_[0] ^ $sa_un_zero), pack "S", AF_UNIX)
   } else {
      Carp::croak "unpack_sockaddr: unsupported protocol family $af";
   }
}

# Check if two IP's are on same subnet
#
sub same_subnet {
  my($ip1,$ip2,$mask) = map inet_aton($_), @_;

  ( $ip1 & $mask ) eq
  ( $ip2 & $mask )
}

# Setup a SSDP listener on all interfaces
#
sub ssdpsock {
  my $sock = IO::Socket::Multicast->new(Proto=>'udp',LocalPort=>$PORT);
  die "SSDP Listener Setup Error: $!\n" unless $sock;
  $sock->mcast_add($GROUP) || die "SSDP Listener Setup Error: $!\n";
  $sock->mcast_loopback(0);
  AE::log info => "Created multicast socket on $GROUP:$PORT";

  # XXX: After the first on_recv, tcp_server listener no longer executes
  my $server; $server = AnyEvent::Handle::UDP->new(
    fh => $sock,
    on_recv => receive_multicast_packet($sock),
    #on_recv => sub {},
  );

  AE::log debug => "Created handler for multicast socket $GROUP:$PORT";
  # This send seems to be causing a block
  #$server->push_send( generate_discover_packet(), [ $GROUP => $PORT ] );
  #$sock->mcast_send( generate_discover_packet(), $GROUP .':'. $PORT );
}

# Generate callback handler for multicast packets
#
sub receive_multicast_packet {
  my($sock) = @_;

  return sub {
    my ($message, $handle, $client_addr) = @_;
    my ($service, $host) = unpack_sockaddr $client_addr;
    $host = inet_ntoa($host);
    #AE::log info => "Multicast packet host length: " . length($host);
    AE::log info => "Multicast packet received from $host:$service\n";
    #AE::log trace => "Multicast packet received";
    AE::log trace => $message;
    # Take action depending on packet content
    if ( $message =~ /M-SEARCH/ ) {
      distribute_discover_packet($handle, $sock, $message, $host);
    } elsif ( $message =~ /LOCATION:/i ) {
      receive_location_packet($handle, $sock, $message);
    } else {
      AE::log debug => "Unknown packet\n:$message";
    }
    #AE::log debug => Dump \%LISTENER;
    threads->yield();
  }
}

# A discovery packet
#
sub generate_discover_packet {
  "M-SEARCH * HTTP/1.1
Host: $GROUP:$PORT
Man: \"ssdp:discover\"
ST: upnp:rootdevice
MX: 3

"
}

# Send a discover packet to all interfaces
#
sub distribute_discover_packet {
  my($handle, $sock, $message, $sender) = @_;

  for my $if ( interfacelist ) {
    # Make sure to not send to same interface where packet was received
    next if same_subnet($sender, $if->address, $if->netmask);
    $sock->mcast_if($if);
    $sock->mcast_send($message, $GROUP .':'. $PORT);
    AE::log trace =>  "M-SEARCH packet sent on $if\n";
  }
}

# When recieving a notify packet
# Match "NOTIFY * HTTP/1.1"
# Match "NT: urn:schemas-upnp-org:service:ContentDirectory:1"
# Distribute to all interfaces
# Use: CACHE-CONTROL: max-age=1800
# Rewrite: LOCATION: http://127.0.0.1:49152/description.xml
# Setup listener for packet forwarding
# Refresh cache on new notify
# Remove from cache on timeout
# When removing cache, removing all open connections to server
#
sub receive_location_packet {
  my($handle, $sock, $message) = @_;

  my($address,$port,$timeout) = extract_location($message);
  AE::log trace => "Location from server $address:$port cache $timeout";
  if ( $LISTENER{"$address:$port"} ) {
    # Send message to all interface using rewritten local port
    my $listenport = $LISTENER{"$address:$port"}{listenport};
    AE::log trace => "Reuse listener on $listenport for server $address:$port";
    distribute_location_packet($message, $sock);
  } else {
    # There is no listener yet. Create one and distribute messages
    AE::log trace => "Create listener for server $address:$port";
    #$LISTENER{"$address:$port"} = client_connection($message, $sock);
    #client_connection($message, $sock);
    async { client_connection($message, $sock); };
  }
  #my $listener = setup_listener($address, $port, $timeout);
  #my $local_port = $listener->{port};
  #print "*** server listener: $local_port\n";
  # TODO* Now that listener is setup
  # 1) Identify local port number
  # 2) Rewrite the packet to use IP of each interface
  # 3) Distribute modified message
}

# Redistribute location packets
#
sub distribute_location_packet {
  my($message, $sock) = @_;

  my($address,$port,$timeout) = extract_location($message);
  unless ( $LISTENER{"$address:$port"} ) {
    AE::log note => "No listener for $address:$port";
    return;
  }
  my $listener = $LISTENER{"$address:$port"};
  my $listenport = $listener->{listenport};
  for my $if ( interfacelist ) {
    my $ifaddress = $if->address;
    # Don't send on same subnet as packet originate from
    next if same_subnet($ifaddress, $address, $if->netmask);
    my $newmessage = $message;
    $newmessage =~ s,(LOCATION.*http:)//([0-9a-z.]+)[:]*([0-9]*)/,$1//$ifaddress:$listenport/,i;
    $sock->mcast_if($if);
    $sock->mcast_send($newmessage, $GROUP .':'. $PORT);
    AE::log trace =>  "LOCATION packet rewritten and sent on $if\n";
  }
}

sub extract_location {
  my $message = shift;

  $message =~ m,LOCATION:.*http://(.*?):(\d+)/,i;
  my $address = $1; my $port = $2; 
  $message =~ m,CACHE-CONTROL:.*max-age=(\d+),i;
  my $timeout = $1;
  return($address, $port, $timeout);
}
 
# Make outgoing connection to a server
#
sub server_connection {
  my ($host, $port, $client_handle, $cb) = @_;

  my $server_handle;
  $server_handle = AnyEvent::Handle->new(
    connect  => [$host => $port],
    on_error => sub {
      $server_handle->destroy;
      $client_handle->destroy;
      AE::log info => "Server error. Disconnecter server and disconnect client";
    },
    on_eof   => sub {
      $server_handle->destroy;
      $client_handle->destroy;
      AE::log note => "Server EOF. Disconnecter server and disconnect client";
    },
  );
  $server_handle->on_read( sub {
      AE::log debug => "Data from $host:$port.";
      my $content = $_[0]->rbuf;
      $_[0]->rbuf = "";
      $server_handle->destroy if length $content <= 0;
      $cb->($content);
    }
  );

  AE::log debug => "Connect to server $host, port $port, handle $server_handle.";
  return $server_handle;
}

# Setup a listener to
# receive incoming connection from a client
# On content, make connection to server
#
sub client_connection {
  my($message, $sock) = @_;

  my($serverhost,$serverport) = extract_location($message);
  my $key = "$serverhost:$serverport";
  my $guard; $guard = tcp_server undef, undef, sub {
    my($fh, $host, $port) = @_;
    AE::log info => "Client connect from $host, port $port, fh $fh.";
    my $server;
    my $handle;
    $handle = AnyEvent::Handle->new(
      fh => $fh,
      on_error => sub {
        $server->destroy if $server;
        undef $server;
        $handle->destroy;
        AE::log note => "Client error and disconnect server"
      },
      on_eof   => sub {
        $server->destroy if $server;
        undef $server;
        $handle->destroy;
        AE::log info => "Client EOF and disconnect server"
      },
    );
    $handle->on_read( sub {
        AE::log debug => "Data from client";
        my $content = $_[0]->rbuf;
        if ( length $content <= 0 ) {
          $handle->destroy;
           return;
        }
        $_[0]->rbuf = "";
        #$server ||= server_connection '127.0.0.1', 49152, $handle, sub {
        $server ||= server_connection $serverhost, $serverport, $handle, sub {
          my($content) = @_;
          $handle->push_write($content);
          AE::log debug => "Data to client";
        };
        AE::log debug => "Data to server";
        $server->push_write($content);
      }
    );
  }, sub {
    my ($fh, $thishost, $thisport) = @_;
    #share($thisport);
    #share($fh);
    AE::log info => "New listener for $serverhost:$serverport bound to $thishost, port $thisport, fh $fh.";
    unless ( $LISTENER{$key} ) {
      my %hash :shared;
      $LISTENER{"$serverhost:$serverport"} = \%hash;
    }
    $LISTENER{"$serverhost:$serverport"}{listenport} = $thisport;
    $LISTENER{"$serverhost:$serverport"}{fh} = $fh;
    AE::log debug => Dump \%LISTENER;
    #distribute_location_packet($message, $sock);
  };
  unless ( $LISTENER{$key} ) {
    my %hash :shared;
    $LISTENER{"$serverhost:$serverport"} = \%hash;
  }
  share($guard);
  $LISTENER{"$serverhost:$serverport"}{guard} = $guard;
  AE::log debug => Dump \%LISTENER;
  return $guard;
}

#my $listener = client_connection(8192);
#my $listener = client_connection();
#my $listener = client_connection("LOCATION: http://127.0.0.1:49152/description.xml");
ssdpsock();

my $w = AnyEvent->timer (after => 2, interval => 2, cb => sub {
  AE::log debug => "Alive";
} );
AnyEvent->condvar->recv;
