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
  $level = 1 if $level =~ /^e/i;
  $level = 2 if $level =~ /^w/i;
  $level = 3 if $level =~ /^n/i;
  $level = 4 if $level =~ /^i/i;
  $level = 5 if $level =~ /^t/i;
  $level = 6 if $level =~ /^de/i;
  $level = 7 if $level =~ /^du/i;
  $level = 0 if $level =~ /^\D/;

  return if $level > _LEVEL;
  #warn "level $level\n";

  # Format the output as Dump, sprintf or string
  #
  my $output;
  if ( $level == 7 ) {
    #warn "formating log as dumper\n";
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

1;
