########################################################################
###
### Logging
###
########################################################################

package App::DLNAProxy::Log;
use Data::Dumper;

# 0 - Quiet
# 1 - Error
# 2 - Warning
# 3 - Notice
# 4 - Info
# 5 - Trace
# 6 - Debug
# 7 - Dump
#
use constant _LEVEL => 7;

# STDOUT | STDERR | SYSLOG
#
use constant _OUTPUT => 'STDERR';

sub _dump {
  Data::Dumper->Dump([$_[1]], ["*** $_[0]"]);
}

sub log {
  my($self, $level, @message) = @_;

  #warn "level $level\n";
  #warn "message @message\n";

  # Convert to number if $level is a word
  #
  $level = 1 if $level =~ /~e/i;
  $level = 2 if $level =~ /^w/i;
  $level = 3 if $level =~ /^n/i;
  $level = 4 if $level =~ /^i/i;
  $level = 5 if $level =~ /^t/i;
  $level = 6 if $level =~ /^de/i;
  $level = 7 if $level =~ /^du/i;
  $level = 0 if $level =~ /^\D/i;

  return if $level > _LEVEL;

  # Format the output as Dump, sprintf or string
  #
  my $output;
  if ( $level == $7 ) {
    $output = _dump(@message);
  } elsif ( @message > 1 ) {
    #warn sprintf "There are %i strings so using sprintf", scalar @message;
    $output = sprintf shift @message, @message;
    #warn "result is $output\n";
  } else {
    $output = shift @message;
  }
  
  # Add timestamp and newline
  #
  my $pre = sprintf "*** %02i:%02i:%02i: ", (localtime)[2,1,0];
  my $nl = "\n" unless $message =~ /(\\x0D\\x0A?|\\x0A\\x0D?)$/;

  # Send output to destination
  #
  if ( _OUTPUT eq 'STDOUT' ) {
    print $pre . $output . $nl;
  } elsif ( _OUTPUT eq 'STDERR' ) {
    warn $pre . $output . $nl;
  } elsif ( _OUTPUT eq 'SYSLOG' ) {
  }
}


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

package App::DLNAProxy::Proxy;

use Moose;
use MooseX::Method::Signatures;
use POE qw(Component::Server::TCP Component::Client::TCP);
use Socket 'unpack_sockaddr_in';

# Required parameters is address and port of remote server
# and a callback sub to announce port number of listener
#
has remote_server_address  => ( is=>'ro', isa=>'Str',     required=>1 );
has remote_server_port     => ( is=>'ro', isa=>'Int',     required=>1 );
has proxy_listener_started => ( is=>'ro', isa=>'CodeRef', required=>1 );

# After we know the callback of where to send port number to
has proxy_listener_port   => ( is=>'rw', isa=>'Int',                  );

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

# A listener to accept incoming connections
#
method BUILD {

  x trace => "Building a listener";
  POE::Component::Server::TCP->new(
    # The listener is now up and running and port is identified
    #
    Started => sub {
      my ($proxy_listener_port, $proxy_listener_addr) =
        unpack_sockaddr_in( $_[HEAP]{listener}->getsockname );
      $self->proxy_listener_port( $proxy_listener_port );
      x info =>
        "listener started on port %s for remote server %s:%s",
        $proxy_listener_port,
        $self->remote_server_address,
        $self->remote_server_port;
        
      $self->proxy_listener_started->($proxy_listener_port);
    },

    # Data arrived from client. Send to Server.
    #
    ClientInput => sub {
      my($kernel, $session, $heap, $message) = @_[KERNEL, SESSION, HEAP, ARG0];
      x debug => "%i bytes from client heap %s", length($message), $heap;
   
      $heap->{remote_server} ||= $self->_proxy_client_create( $session->ID );
      $kernel->post($heap->{remote_server}, 'remote_server_send', $message);
    },

    # Client has disconnected. Disconnect from server as well.
    #
    ClientDisconnected => sub {
      my($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
      my $session_id = $session->ID;
      my $server_session_id = $heap->{remote_server};
      x info => "client session $session_id has disconnected, shutting down server connection session $server_session_id";
      $kernel->post($heap->{remote_server}, 'shutdown' );
      delete $heap->{remote_server};
    },

    InlineStates => {
      remote_client_send => sub {
        my($heap, $message) = @_[HEAP, ARG0];
        x debug => "to client: $message";
        $heap->{client}->put($message);
      },
    },
  );
}

method _proxy_client_create ( Int $remote_client_session ) {
  x trace => "Creating proxy client for remote client $remote_client_session\n";
  POE::Component::Client::TCP->new(
    RemoteAddress => $self->remote_server_address,
    RemotePort    => $self->remote_server_port,

    Connected => sub {
      my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
      x info => "connected to %s:%s", $self->remote_server_address, $self->remote_server_port;
      # Flush buffer of messages while connecting
      while ( my $message = shift @{ $heap->{buffer} } ) {
        x info => "Flushing buffer $message";
        $heap->{server}->put( $message );
      }
      delete $heap->{buffer};
    },

    ServerInput => sub {
      # Got data form server, send to client
      my ( $kernel, $heap, $message ) = @_[ KERNEL, HEAP, ARG0 ];
      my $size = length $message;
      x trace => "Received $size bytes from server heap $heap";
      x debug => $message;
      # This is causing leak
      #$remote_client->put( $message );
      $kernel->post( $remote_client_session, 'remote_client_send', $message );
    },

    InlineStates => {
      remote_server_send => sub {
        my ( $heap, $message ) = @_[ HEAP, ARG0 ];
        #x heap => $heap;
        if ( $heap->{connected} ) {
          x trace => "sending to server: $message";
          $heap->{server}->put($message);
        } else {
          # Buffer up because not yet connected
          x trace => "buffer to server: $message";
          push @{ $heap->{buffer} }, $message;
        }
      },
    },

    Disconnected => sub {
      x info => "Server disconnected";
      $_[KERNEL]->post( $remote_client_session, 'shutdown' );
    },
  )
}

__PACKAGE__->meta->make_immutable;


########################################################################
###
### A SSDP Server that listens for and sends multicast packages
###
########################################################################

package App::DLNAProxy;

use Moose;
use MooseX::Method::Signatures;
use POE;
use IO::Socket::Multicast;
use IO::Interface::Simple;

use constant _DATAGRAM_MAXLEN   => 1024;
use constant _MCAST_GROUP       => '239.255.255.250';
use constant _MCAST_PORT        => 1900;
use constant _MCAST_DESTINATION => _MCAST_GROUP . ':' . _MCAST_PORT;
use constant _DISCOVER_INTERVAL => 1800; # 30;
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
has _proxy => ( is=>'ro', isa=>'HashRef[App::DLNAProxy::Proxy]', default=>sub{{}} );

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
      or x warn => $!;
    $sock->mcast_send(_DISCOVER_PACKET, _MCAST_DESTINATION)
      or x warn => $!;

    x info => "pid $$ sent discover on $if";
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
    x notice => "received unknown packet from $human_addr : $peer_port ... $message";
  }
}

# We have received a location packet.
#
sub _read_location {
  my($self, $message) = @_[OBJECT, ARG0];

  my($address,$port,$timeout) = _extract_location($message);
  my $dest = "$address:$port";
  x notice => "Location from server $dest cache $timeout";

  if ( $self->_proxy->{$dest} ) {
    x info => "  already known";
    $self->send_location( $message, $self->_proxy->{$dest}->proxy_listener_port );
    # XXX refresh timeout
  } else {
    $self->_proxy->{$dest} = App::DLNAProxy::Proxy->new(
      remote_server_address => $address,
      remote_server_port    => $port,
      proxy_listener_started => sub { $self->send_location( $message, @_ ) },
    );
    x info => "   created new listener";
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
    x info => "LOCATION packet rewritten to $ifaddress:$listenport and sent on $if";
  }
}

sub _start {
  my($self, $kernel) = @_[OBJECT, KERNEL];

  x trace => "$self session called _start";

  # With the session started, tell kernel to call "read" sub
  # when data arrives on socket.
  $kernel->select_read($self->_socket, '_read');

  # Start sending out discovery packets
  $kernel->yield('_discover');

  x trace => "$self session ended _start";
}

method BUILD {
  $self->_session;

  POE::Kernel->run();
}

__PACKAGE__->meta->make_immutable;
