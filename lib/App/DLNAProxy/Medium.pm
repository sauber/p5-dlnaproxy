# This class defines how a medium behaves

package App::DLNAProxy::Medium;

use Moo::Role;

# Send a message to all interfaces
requires 'broadcast';

# Resend a message to all interfaces except where it came from
requires 'distribute';

# Send a message on specific interface
requires 'send';

# Register a reader of incoming packets
requires 'read';

1;
