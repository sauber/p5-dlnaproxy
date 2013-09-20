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

package App::DLNAProxy::TCP::Proxy;

use Moose;
use MooseX::Method::Signatures;
use POE qw(Component::Server::TCP Component::Client::TCP Filter::DLNAProxy);
use Socket 'unpack_sockaddr_in';
use App::DLNAProxy::Log;

# Required parameters is address and port of remote server
# and a callback sub to announce port number of listener
#
has remote_server_address  => ( is=>'ro', isa=>'Str',     required=>1 );
has remote_server_port     => ( is=>'ro', isa=>'Int',     required=>1 );
has proxy_listener_started => ( is=>'ro', isa=>'CodeRef', required=>1 );

# After we know the callback of where to send port number to
has proxy_listener_port   => ( is=>'rw', isa=>'Int' );
has proxy_session         => ( is=>'rw', isa=>'Int' );

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

# A listener to accept incoming connections
#
method BUILD {

  x trace => "Building a listener";
  POE::Component::Server::TCP->new(
    ClientFilter => 'POE::Filter::DLNAProxy',

    # The listener is now up and running and port is identified
    #
    Started => sub {
      my ($proxy_listener_port, $proxy_listener_addr) =
        unpack_sockaddr_in( $_[HEAP]{listener}->getsockname );
      $self->proxy_listener_port( $proxy_listener_port );
      $self->proxy_session( $_[SESSION]->ID );
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
        #x debug => "to client: $message";
        $heap->{client}->put($message);
      },
    },
  );
}

method _proxy_client_create ( Int $remote_client_session ) {
  x trace => "Creating proxy client for remote client $remote_client_session\n";
  POE::Component::Client::TCP->new(
    Filter        => 'POE::Filter::Stream',
    RemoteAddress => $self->remote_server_address,
    RemotePort    => $self->remote_server_port,

    Connected => sub {
      my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
      x info => "connected to %s:%s", $self->remote_server_address, $self->remote_server_port;
      # Flush buffer of messages while connecting
      while ( @{ $heap->{buffer} } ) {
        my $message = shift @{ $heap->{buffer} };
        x debug => "Flushing buffer $message";
        $heap->{server}->put( $message );
      }
      delete $heap->{buffer};
    },

    ServerInput => sub {
      # Got data form server, send to client
      my ( $kernel, $heap, $message ) = @_[ KERNEL, HEAP, ARG0 ];
      my $size = length $message;
      #x trace => "Received $size bytes from server heap $heap";
      x trace => "Received %s bytes from server %s:%s", $size, $self->remote_server_address, $self->remote_server_port;
      #x debug => $message;
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
