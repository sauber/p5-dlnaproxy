# Defines methods of a socket class
#
package App::DLNAProxy::Socket;

use Moo;

has LocalPort  => ( is=>'ro', required=>1 );
has ReuseAddr  => ( is=>'ro', required=>1 );
has mcast_if   => ( is=>'rw' );
has mcast_add  => ( is=>'rw' );

sub mcast_send { die "not implemented" }

1;
