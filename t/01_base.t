use strict;
use Test::More tests => 1;
use WebService::AipoLive;

my $aipo = WebService::AipoLive->new(
    username => q{},
    password => q{},
    no_login => 1,
  );

isa_ok($aipo,'WebService::AipoLive', 'isa test');