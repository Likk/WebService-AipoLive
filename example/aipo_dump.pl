#!/usr/local/bin/perl
use strict;
use warnings;
use lib qw(
./lib
../lib
);
use WebService::AipoLive;
use YAML;
use Encode;

warn "input your aipo's username: "; my $username = <>;
warn "input your aipo's password: "; my $password = <>;
warn "input your test group id  : "; my $gid = <>;
chomp $username;
chomp $password;
chomp $gid;

my $aipo;
eval{
  $aipo = WebService::AipoLive->new(
    username => $username,
    password => $password,
  );
};
die "WebService::AipoLive login faild." if $@;

print Encode::encode_utf8 (YAML::Dump ($aipo->timeline()));
print Encode::encode_utf8 (YAML::Dump ($aipo->reply_messages()));
print Encode::encode_utf8 (YAML::Dump ($aipo->favorites_messages()));
$aipo->update(
  gid    => $gid,
  status => Encode::decode_utf8('テスト via WebService::AipoLive'),
  );
print Encode::encode_utf8 (YAML::Dump ($aipo->group_timeline(gid => $gid)));
  
