########################################################################
###
### A SSDP Server that detects DLNA servers, relay announcements
### and establish tcp proxy servers for data
###
########################################################################

package App::DLNAProxy;

use Moose;
use MooseX::Method::Signatures;
use POE;
use POE::Wheel::UDP;
use IO::Socket::Multicast;
use App::DLNAProxy::Interfaces;
use App::DLNAProxy::Log;
use App::DLNAProxy::SSDP::Clients;
use App::DLNAProxy::SSDP::Servers;
use App::DLNAProxy::SSDP::Announcement;

use constant _DATAGRAM_MAXLEN   => 8192; # 1024
use constant _MCAST_GROUP       => '239.255.255.250';
use constant _MCAST_PORT        => 1900;
use constant _MCAST_DESTINATION => _MCAST_GROUP . ':' . _MCAST_PORT;
use constant _DISCOVER_INTERVAL => 900; # 30;
use constant _DISCOVER_PACKET   => 
'M-SEARCH * HTTP/1.1
Host: ' . _MCAST_DESTINATION . '
Man: "ssdp:discover"
ST: upnp:rootdevice
MX: 3

';

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

# Build a socket interface
#
has _socket => ( is=>'ro', isa=>'IO::Socket::Multicast', lazy_build=>1 );
method _build__socket {
  IO::Socket::Multicast->new(
    LocalPort => _MCAST_PORT,
    ReuseAddr => 1,
    #ReusePort => 1,
  ) or die $!;
}

# A list of all network interfaces capable of multicast
#
has _interfaces => (is=>'ro',isa=>'App::DLNAProxy::Interfaces',lazy_build=>1);
method _build__interfaces { App::DLNAProxy::Interfaces->instance }

# A list of clients in discovery
#
has _clients => (is=>'ro', isa=>'App::DLNAProxy::SSDP::Clients', lazy_build=>1);
method _build__clients { App::DLNAProxy::SSDP::Clients->new }

# A list of servers that have announced themselves
#
has _servers => (is=>'ro', isa=>'App::DLNAProxy::SSDP::Servers', lazy_build=>1);
method _build__servers { App::DLNAProxy::SSDP::Servers->instance }

# Announce to the world that we are looking for servers
# Or reannounce messages we received
#
sub _send_discover {
  my($self, $kernel, $sender, $message) = @_[OBJECT, KERNEL, ARG0, ARG1];

  my $sock = $self->_socket;
  for my $if ( $self->_interfaces->all ) {
    # Don't send to interface with IP in same range as sender of packet
    next if $sender and $self->_interfaces->belong($if, $sender);

    $message ||= _DISCOVER_PACKET;

    if ( $sender ) {
      x info => '%s >: rediscover on %s for %s', $if->address, $if, $sender;
    } else {
      x info => '%s >: discover on %s', $if->address, $if;
    }
    #next if $if->name eq 'lo0';
    next if $if->name =~ /en/;
    x debug => 'setting if to %s', $if;
    $sock->mcast_if($if)
      or x warn => $!;
    $sock->mcast_send($message, _MCAST_DESTINATION)
      or x warn => $!;
 }

  # Cancel previous timer and set new
  $kernel->delay(_send_discover => _DISCOVER_INTERVAL);
}

# Send a SSDP message to a particular destination
#
method _send_direct ( Object $client, Object $announcement ) {

  my $message = $announcement->rewrite( $client );
  x trace => '%s:1900 > %s:%s: %i bytes',
             $client->sender_address,
             $client->address, $client->port,
             length $message;
  POE::Session->create(
    inline_states => {
      _start => sub {
        my $wheel =  POE::Wheel::UDP->new(
          PeerAddr  => $client->address,
          PeerPort  => $client->port,
          LocalAddr => $client->sender_address,
          LocalPort => 1900,
          Filter    => POE::Filter::Stream->new,
        );
        $wheel->put( { payload => [ $message ] } );
      },
    }
  );
  x trace => '%s:1900 > %s:%s: %i bytes',
             $client->sender_address,
             $client->address, $client->port,
             length $message;
}

method _send_broadcast ( Object $announcement ) {
  x error => 'sending broadcast not implemented';

  #for my $if ( $self->_interfaces->all ) {
  #  # Don't send to interface with IP in same range as sender of packet
  #  next if $self->_interfaces->belong( $if, $announcement->sender_address );
  #  my $message;
  #  if ( $proxy ) {
  #    $message = $announcement->rewrite( $if->address, $proxy->listener_port );
  #    x info => 'LOCATION packet rewritten to %s:%s', $if->address, $proxy->listener_port;
  #  } else {
  #    $message = $announcement->message;
  #  }
  #  x info => "%s > %s: reannouncement", $if->address, $if;
  #  $sock->mcast_if($if);
  #  $sock->mcast_send($message, _MCAST_DESTINATION );
  #}
}

# We have set up a listener for a remote location. Announce it's presence.
#
method _send_announcement ( Object $announcement ) {
  #my $sock = $self->_socket;

  # Send first to all known client waiting for announcements
  $self->_send_direct( $_, $announcement ) for $self->_clients->all;

  # Then broadcast to rest of world
  $self->_send_broadcast( $announcement );
}

# Process a location packet
#
sub _process_announcement {
  my($self, $kernel, $announcement) = @_[OBJECT, KERNEL, ARG0];

  x trace => '%s:%s announcement location %s:%s',
             $announcement->sender_address,   $announcement->sender_port,
             $announcement->location_address, $announcement->location_port;

  # If $address is local and $port matches that of a proxy,
  # then we got our own announcement.
  # If $address is local, but different port, then we have DLNA running
  # locally; DLNA server usually only announce themselves on one interface
  # so reannoucne on remaining interfaces.
  #
  for my $if ( $self->_interfaces->all ) {
    next unless $announcement->location_address eq $if->address;
    # IP is local - check for port
    for my $pr ( $self->_servers->proxies ) {
      if ( $pr->port == $announcement->location_port ) {
        x trace => "session received announcement from own proxy";
        return;
      }
    }
  }

  # Find out if location is on any local subnet
  # TODO: For now just resend announcement. But it seems we have to proxy.
  #if ( ! $self->_interfaces->direct($message->location_address) ) {
  #  $self->_send_announcement( $message );
  #  return;
  #}

  # TODO: If location is not on any interface, we cannot proxy it
  #       We'll have to redistribute without rewrite

  # TODO: Are there any client waiting for location?
  #

  # TODO: Got announcement for something where proxy is already set up
  #

  # When we have announcement, set up proxy server, and redistribute
  # announcement.
  #
  my $callback =
    sub { $self->_send_announcement( $announcement, @_ ) };
  $self->_servers->add( 
    $announcement,
    $callback,
  );


}

# A packet arrived. Find out which type it is and respond
#
sub _read {
  my ($self, $kernel, $socket) = @_[OBJECT, KERNEL, ARG0];

  my $remote_address = recv($socket, my $message = "", _DATAGRAM_MAXLEN, 0);
  die $! unless defined $remote_address;
  my ($peer_port, $peer_addr) = unpack_sockaddr_in($remote_address);
  my $human_addr = inet_ntoa($peer_addr);
  #x debug => $message;

  # Take action depending on packet content
  if ( $message =~ /M-SEARCH/i ) {
    # A client is doing discovery
    x info => '%s:%s <: discover', $human_addr, $peer_port;
    $self->_clients->add( $human_addr, $peer_port );
    $kernel->yield('_send_discover', $human_addr, $message);
  } elsif ( $message =~ /LOCATION:/i ) {
    # A server is announcing itself
    x trace => '%s:%s <: announcement', $human_addr, $peer_port;
    $kernel->yield(
      '_process_announcement',
      App::DLNAProxy::SSDP::Announcement->new(
        sender_address => $human_addr,
        sender_port    => $peer_port,
        message        => $message
      )
    );
  } else {
    # Something we don't recognize
    x trace => '%s:%s <: unknown packet', $human_addr, $peer_port, $message;
  }
}

# POE sessions starts
#
sub _start {
  my($self, $kernel) = @_[OBJECT, KERNEL];

  x trace => "session starting";

  my $socket = $self->_socket;
  $socket->mcast_add(_MCAST_GROUP) or die $!;

  # With the session started, tell kernel to call "read" sub
  # when data arrives on socket.
  $kernel->select_read($socket, '_read');

  # Start sending out discovery packets
  $kernel->yield('_send_discover');

  x trace => "session started";
}

# A POE session with various events
#
has _session => ( is=>'ro', isa=>'POE::Session', lazy_build=>1 );
method _build__session {
  POE::Session->create(
    object_states => [
      $self => [ qw(_start _read _process_announcement _send_announcement _send_discover) ]
    ]
  ) or die $!;
}

method BUILD {
  $self->_session;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;

