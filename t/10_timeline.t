use strict;
use Test::More;
use WebService::AipoLive;

diag "input your aipo's username: "; my $username = <>;
diag "input your aipo's password: "; my $password = <>;
chomp $username;
chomp $password;

my $aipo;
eval{
  $aipo = WebService::AipoLive->new(
    username => $username,
    password => $password,
  );
};
plan skip_all => "WebService::AipoLive login faild." if $@;
plan tests => 9;
my $timeline = $aipo->timeline();
isa_ok($timeline, 'ARRAY', 'timeline test');

my $status = $timeline->[0];
isa_ok($status, 'HASH', 'one status test');

my @hash_key = ('body','datetime','gid','group','name','status');
is_deeply([sort keys %$status], \@hash_key, 'status hash keys check');

ok($status->{body},     'check at status has body');
ok($status->{datetime}, 'check at status has datetime');
ok($status->{gid},      'check at status has gid');
ok($status->{group},    'check at status has group');
ok($status->{name},     'check at status has name');
ok($status->{status},   'check at status has status');
