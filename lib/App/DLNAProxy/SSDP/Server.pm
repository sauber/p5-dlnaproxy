########################################################################
###
### A SSDP Server
###
########################################################################

package App::DLNAProxy::SSDP::Server;

use Moose;
use MooseX::Method::Signatures;

has address => ( is=>'ro', isa=>'Str', required=>1 );
has port    => ( is=>'ro', isa=>'Int', required=>1 );

has proxies => ( is=>'ro', isa=>'HashRef[App::DLNAProxy::TCP::Proxy]', default=>sub{{}} );

__PACKAGE__->meta->make_immutable;
