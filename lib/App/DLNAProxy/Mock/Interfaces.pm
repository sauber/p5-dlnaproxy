package App::DLNAProxy::Mock::Interfaces; 

use Moo;
use namespace::clean;
use App::DLNAProxy::Mock::Interface;
extends 'App::DLNAProxy::Interfaces';

has interfaces => ( is=>'ro', required=>1, coerce=>sub {[
  # Convert hash structures to objects
  map App::DLNAProxy::Mock::Interface->new($_), @{$_[0]}
]} );

1;
