# Defines methods of a socket class
#
package App::DLNAProxy::Socket;

use Moo;

has LocalPort  => ( is=>'ro', required=>1 );
has ReuseAddr  => ( is=>'ro', required=>1 );
has mcast_if   => ( is=>'rw' );
has mcast_add  => ( is=>'rw' );

sub mcast_send { die "not implemented" }

sub broadcast {
  my($self, $message) = @_;
  $self->distribute($message);
} 

sub distribute {
  my($self, $message) = @_;
  my $from_if = $message->interface_name;
  for my $if ( @{$self->interfaces->interfaces} ) {
    next if $from_if and $if->name eq $from_if;
    $self->mcast_if($if->name);
    $self->mcast_send($message);
  }
}

1;
