# This class defines how an interface behaves

package App::DLNAProxy::Interface;

use Moo::Role;

# Name of interface
#requires 'name';

# If interface is multicast capable
#requires 'is_multicast';

# The IP of the interface
#requires 'address';

# The netmask of the interface
#requires 'address';

# Send a packet on interface
requires 'send';

# Receive a packet on interface and place in incoming buffer
requires 'receive';

# Get packing from incoming buffer
requires 'fetch';

1;
