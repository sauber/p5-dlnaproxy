package App::DLNAProxy::Message;

use Moo;
use namespace::clean;

has body           => ( is=>'ro', required=>1 );
has interface_name => ( is=>'ro' );
has is_multicast   => ( is=>'rw' );

sub clone_to_interface {
  my($self, $ifname) = @_;

  my $class = ref $self;
  return $class->new(
    body           => $self->body,
    is_multicast   => $self->is_multicast,
    interface_name => $ifname,
  );
}

1;
