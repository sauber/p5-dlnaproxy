dlanproxy
=========

Bridge dlna traffic across multiple subnets on multi-homed host

Does so by listening for notification multicast messages, rewrite the
location line as if it came from this host, and redistribute notification
on all other interfaces. For every DLNA server learned, set up a listener
to forward traffic from clients.
