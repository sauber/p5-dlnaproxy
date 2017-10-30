package App::DLNAProxy::Mock::Timer;

use Moo;
use namespace::clean;

# Run a piece of code at regular intervals
#
sub timed {
  my($self, $interval, $coderef) = @_;

  # Use interval is count
  for ( 1 .. $interval ) {
    $coderef->();
  }
  return 1;
}

1;
