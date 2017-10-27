# Mock package to present list of mock interfaces

package App::DLNAProxy::Mock::Interface;

sub new {
  my $class = shift;
  my $data = shift;
  return bless $data, $class;
}

sub name         { shift->{name}         }
sub is_multicast { shift->{is_multicast} }
sub address      { shift->{address}      }
sub netmask      { shift->{netmask}      }

# Mock package to present list of mock interfaces

package App::DLNAProxy::Mock::Interfaces;

use App::DLNAProxy::Interfaces;
our @ISA = qw(App::DLNAProxy::Interfaces);

sub new {
  my $class = shift;
  my $data = shift;
  return bless $data, $class;
}

sub interfaces {
  my $self = shift;
  map App::DLNAProxy::Mock::Interface->new($_), @$self;
}

1;
