use ExtUtils::MakeMaker;
WriteMakefile(
  NAME        => "App::DLNAProxy",
  ABSTRACT    => 'proxy dlna service across subnets',
  AUTHOR      => 'Soren Dossing <sauber@cpan.org>',
  VERSION     => "0.1",
  EXE_FILES   => ['bin/dlnaproxy'],
  "PREREQ_PM" => {
    "Data::Dumper"                => 0,
    "Devel::SimpleTrace"          => 0,
    "IO::Interface::Simple"       => 0,
    "IO::Socket::Multicast"       => 0,
    "Moose"                       => 0,
    "MooseX::Method::Signatures"  => 0,
    "MooseX::Singleton"           => 0,
    "POE::Component::Client::TCP" => 0,
    "POE::Component::Server::TCP" => 0,
    "Socket"                      => 0,
    "POE::Wheel::UDP"             => 0,
  },
  dist => { COMPRESS => 'gzip', SUFFIX => 'gz' },
);
