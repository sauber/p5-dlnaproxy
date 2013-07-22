########################################################################
###
### A POE Filter
###
########################################################################

# For xml files, detect ip:port and replace with a local port to proxy requests through.
# When rewritten, also rewrite content-length header.
# For other media types, pass through as raw data

package POE::Filter::DLNAProxy;

use strict;
use POE::Filter;
use App::DLNAProxy;

use vars qw($VERSION @ISA);
$VERSION = '0.001'; # NOTE - Should be #.### (three decimal places)
@ISA = qw(POE::Filter);

# Logging shortcut
#
sub x { App::DLNAProxy::Log->log(@_) }

# Location in self array ref for data
use constant {
  HEADER     => 0,
  CONTENT    => 1,
  MEDIA_TYPE => 2,
  REWRITE    => 3,
  TRANSLATOR => 4,
};

sub new {
  my $type = shift;

  # Need an object that can translate known and new remote ip:port to local
  my %params = @_;

  x debug => 'DLNAProxy filter initiated';

  bless [
    '',    # HEADER
    '',    # CONTENT
    undef, # MEDIA_TYPE
    undef, # REWRITE
    $params{translator},
  ], $type;
}

sub get_one_start {
  my ($self, $stream) = @_;
  $self->[CONTENT] .= join '', @$stream;

  x trace => 'Adding content to filter';
}

sub get_one {
  my $self = shift;

  return [ ] unless length $self->[CONTENT];
  my $chunk = $self->[CONTENT];
  $self->[CONTENT] = '';
  x trace => 'Taking content from filter';
  return [ $chunk ];
}

sub put {
  my ($self, $lines) = @_;
  x trace => 'In Filter put function';
  [ @$lines ];
}

# A copy of everything in the buffer so far
sub get_pending {
  my $self = shift;

  return [ $self->[CONTENT] ] if length $self->[CONTENT];
  return undef;
}

1;


