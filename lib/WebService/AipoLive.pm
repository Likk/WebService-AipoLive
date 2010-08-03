package WebService::AipoLive;

=head1 NAME

WebService::AipoLive - Aipolive client for perl.

=head1 SYNOPSIS

  use WebService::AipoLive;
  use YAML;
  
  my $aipo = WebService::AipoLive->new(
    username => q{YOUR USERNAME},
    password => q{YOUR PASSWORD},
  );
  
  print YAML::Dump $aipo->timeline();
  print YAML::Dump $aipo->group_timeline(gid => 1);
  print YAML::Dump $aipo->reply_messages();
  print YAML::Dump $aipo->favorites_messages();
  $aipo->update(
    gid      => 1,
    status   => q{hello aipo},
    parentid => 1,             #option
  );
  
};

=head1 DESCRIPTION

WebService::AipoLive is Aipolive client for perl

=cut

use strict;
use warnings;
use Carp;
use WWW::Mechanize;
use Web::Scraper;
use Time::Piece;
use Encode;

use YAML;

our $VERSION = '0.01';

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new WebService::AipoLive object.:

WebService::AipoLive->new(
#required 
    username => q{YOUR USERNAME},
    password => q{YOUR PASSWORD},
#option
    agent    => q{user agent},
    ssl_mode => (1|0),#default 0
    nologin  => (1|0),#default 0
)

WebService::AipoLiveオブジェクトの作成

=cut
sub new {
  my $class = shift;
  my %args  = @_;
  $args{'agent'}      ||= __PACKAGE__." ".$VERSION;
  $args{'wm'}           = WWW::Mechanize->new(
                            agent=> $args{'source'},
                          );  
  
  $args{'www_root'}     = 'http://www.aipolive.com';
  $args{'ssl_root'}     = 'https://aipo-live.appspot.com';
  $args{'no_login'}   ||= 0;
  $args{'ssl_mode'}   ||= 0;
  $args{'site_root'}    = $args{'ssl_mode'} ?
    $args{'ssl_root'}:
    $args{'www_root'};
  my $self = bless {%args}, $class;
  $self->login unless $self->{no_login} == 1;
  return $self;	
}

#login

=head1 METHODS

=head2 login
the login action method. If login failed then die.:
    $aipo->login();
  
ログインアクションを行う、ログイン出来ない場合はdieする。
 
 1. CSRF対策用の__csrf__値を_login_csrf_parseメソッドから取得
 2. 1と、ID,PASSWORDを用いて/auth/loginへpost
 3. レスポンス内容を_login_checkメソッドで確認
 4. ログインチェックが通らない場合はcroak(die)する

=cut

sub login {
#public String login(WebService::AipoLive $self)
  my $self = shift;
  my $csrf = $self->_login_csrf_parse($self->{'wm'}->get("$self->{site_root}"));
  my $post = {
    username => $self->{username},
    password => $self->{password},
    __csrf__ => $csrf,
    autologin => 'yes',
    LoginForm => '%E3%83%AD%E3%82%B0%E3%82%A4%E3%83%B3%E3%81%99%E3%82%8B',
  };
  my $res = $self->_login_check($self->{'wm'}->post("$self->{site_root}/auth/login", $post));
  croak("login faild") unless $res;
}

#get (read timeline)

=head2 timeline
get the timeline.:

    my $tl = $aipo->timeline();


タイムライン情報を取得する。
 
 1. ユーザのTOPページにアクセス
 2. _parseメソッドでtimeline情報をscrape.
 3. データを整形し、hash_refのarray_ref構造で返す

=cut

sub timeline {
#public array_ref timeline(WebService::AipoLive $self)
  my $self = shift;
  my $tl = $self->_parse($self->{'wm'}->get("$self->{site_root}"));
  for my $post (@$tl){
    $post->{body} =~ s{^$post->{name}\s}{}; #発言ユーザ名を除く
    $post->{body} =~ s{^.\@}{\@};           #返信 ＠前の1文字を除く
    $post->{gid}  =~ s{/g/([0-9]+)/}{$1};
  }
  return $tl;
}

=head2 group_timeline
get the group timeline.:

    my $gtl = $aipo->group_timeline( gid => 1 );

グループのタイムライン情報を取得する。
 
 1. グループのTOPページにアクセス
 2. _group_parseメソッドでtimeline情報をscrape.
 3. データを整形し、hash_refのarray_ref構造で返す

=cut

sub group_timeline {
#<public array_ref group_timeline(WebService::AipoLive $self, Int $gid)
  my $self = shift;
  my %arg  = @_;
  croak(q{required gid. exp($aipo->group_timeline(1)}) unless $arg{gid};
  my ($tl,$group) = $self->_group_parse($self->{'wm'}->get("$self->{site_root}/g/$arg{gid}/"));
  for my $post (@$tl){
    $post->{body} =~ s{^$post->{name}\s}{}; #発言ユーザ名を除く
    $post->{body} =~ s{^.\@}{\@};           #返信 ＠前の1文字を除く
    $post->{gid}   = $arg{gid};
    $post->{group} = $group;
  }
  return $tl;
}

=head2 reply_messages
get the reply messages.:

    my $replies = $aipo->reply_messages();

自分宛の投稿情報を取得する。
 
 1. 自分宛のページにアクセス
 2. _parseメソッドでtimeline情報をscrape.
 3. データを整形し、hash_refのarray_ref構造で返す

=cut

sub reply_messages {
#public array_ref reply_messages(WebService::AipoLive $self)
  my $self = shift;
  my %arg  = @_;
  my $tl = $self->_parse($self->{'wm'}->get("$self->{site_root}/mypage/parts/message/reply"));
  for my $post (@$tl){
    $post->{body} =~ s{^$post->{name}\s}{}; #発言ユーザ名を除く
    $post->{body} =~ s{^.\@}{\@};           #返信 ＠前の1文字を除く
    $post->{gid}  =~ s{/g/([0-9]+)/}{$1};
  }
  return $tl;
}

=head2 favorites_messages
get the favorites messages.:

    my $replies = $aipo->favorites_messages();

自分宛の投稿情報を取得する。
 
 1. お気に入りのページにアクセス
 2. _parseメソッドでtimeline情報をscrape.
 3. データを整形し、hash_refのarray_ref構造で返す

=cut

sub favorites_messages {
#public array_ref favorites_messages(WebService::AipoLive $self)
  my $self = shift;
  my %arg  = @_;
  my $tl = $self->_parse($self->{'wm'}->get("$self->{site_root}/mypage/parts/message/favorite"));
  for my $post (@$tl){
    $post->{body} =~ s{^$post->{name}\s}{}; #発言ユーザ名を除く
    $post->{body} =~ s{^.\@}{\@};           #返信 ＠前の1文字を除く
    $post->{gid}  =~ s{/g/([0-9]+)/}{$1};
  }
  return $tl;
}

#action (post)

=head2 update
post to the Aipolive.:

    $aipo->update({});

Aipoliveに投稿する。
 
 1. updateしたいグループのtimelineにアクセス
 2. CSRF対策用の__csrf__値を_post_csrf_parseメソッドから取得
 3. post情報の組み立てと、ヘッダの追加.
 4. 実際のpost. と不要になったヘッダの除去

=cut

sub update {
#B<public void update(WebService::AipoLive $self, hash_ref $args)>
  my $self = shift;
  my %arg = @_;
  croak(q{required gid. exp($aipo->group_timeline(1)}) unless $arg{gid};
  my $csrf = $self->_post_csrf_parse($self->{'wm'}->get("$self->{site_root}/g/$arg{gid}/"));
  $arg{status} = Encode::is_utf8($arg{status}) ? 
    $arg{status}:
    Encode::encode_utf8($arg{status});
    
  my $post = {
    body      => $arg{status},
    __csrf__  => $csrf,
    parentId  => $arg{parentid}||undef,
    MessageAddForm => '%E6%8A%95%E7%A8%BF%E3%81%99%E3%82%8B',
  };
  #post時だけhttp request header に X-Requested-With:XMLHttpRequest を追加する
  $self->{'wm'}->add_header( 'X-Requested-With' => 'XMLHttpRequest');
  #post
  my $res = $self->{'wm'}->post("$self->{site_root}/group/parts/message/form?groupId=$arg{gid}", $post);
  #post終了したら、速やかに X-Requested-With を消去する
  $self->{'wm'}->delete_header('X-Requested-With');
}




#parse (content scraping)

##login

=head1 PRIVATE METHODS

=over

=item B<_login_csrf_parse>
get the __csfr__ value.

CSRF対策用の__csrf__値を取得する。
 
 1. HTTP::Responseのcontentから//form/input[1]のvalueをscrape

=cut

sub _login_csrf_parse {
#private String _login_csrf_parse(WebService::AipoLive $self, HTTP::Response $data)
  my $self = shift;
  my $data = shift;
  my $scraper = scraper
  {
    process '//form/input[1]',
      'csrf' => '@value';
    result 'csrf';
  };
  return $scraper->scrape(Encode::decode_utf8 $data->{_content});
}

=item B<_login_check>
check a HTML at just after the login.

ログイン後のHTML内容をチェックする。
 
 1. HTTP::Responseのcontentからdiv.headerRightBoxをscrape

=cut

sub _login_check {
#private String _login_check(WebService::AipoLive $self, HTTP::Response $data)
  my $self = shift;
  my $data = shift;
  my $scraper = scraper
  {
    process '//div[@class="headerRightBox"]',
      'data' => 'TEXT';
    result 'data';
  };
  return $scraper->scrape(Encode::decode_utf8 $data->{_content});
}

##post

=item B<_post_csrf_parse>
get the __csfr__ value.

CSRF対策用の__csrf__値を取得する。
 
 1. HTTP::Responseのcontentから//form/input[1]のvalueをscrape

=cut

sub _post_csrf_parse {
#private String _post_csrf_parse(WebService::AipoLive $self, HTTP::Response $data)
  my $self = shift;
  my $data = shift;
  my $scraper = scraper
  {
    process '//form/input[1]',
      'csrf' => '@value';
    result 'csrf';
  };
  return $scraper->scrape(Encode::decode_utf8 $data->{_content});	
}


##timeline

=item B<_parse>
scrape a timeline HTML.

HTML を scrape して、タイムライン情報を取得
 
 1. HTTP::Responseのcontentからdiv.pageElementをscrape

=cut

sub _parse {
#<private array_ref _parse(WebService::AipoLive $self, HTTP::Response $data)>
  my $self = shift;
  my $data = shift;
  my $scraper = scraper
  {
    process 'div.timeline',
      'data[]' => scraper
    {
      process '//div[@class="id"]',
        'status'    => 'TEXT';
      process '//div[@class="main"]/div[@class="body"]',
        'body'      => 'TEXT';
      process '//div[@class="main"]/div[@class="body"]/span[@class="name"]/a',
        'name'      => 'TEXT';
      process '//div[@class="main"]/div[@class="clearfix"]/div[@class="time"]/a[1]',
        'datetime'  => 'TEXT';
      process '//div[@class="main"]/div[@class="clearfix"]/div[@class="time"]/a[2]',
        'group'     => 'TEXT',
        'gid'       => '@href';
    };
    result 'data';
  };
  return $scraper->scrape(Encode::decode_utf8 $data->{_content});	
}

=item B<_group_parse>
scrape a timeline HTML.

HTML を scrape して、タイムライン情報を取得
 
 1. HTTP::Responseのcontentからdiv.pageElementをscrape

=cut

sub _group_parse {
#private array_ref,String _group_parse(WebService::AipoLive $self, HTTP::Response $data)
  my $self = shift;
  my $data = shift;
  my $gid_scraper = scraper
  {
    process '//div[@id="header"]/h1[@class="group clearfix"]',
        'group'    => '@title';
    result 'group'; 	
  };
  my $group = $gid_scraper->scrape(Encode::decode_utf8 $data->{_content});
  
  my $scraper = scraper
  {
    process 'div.timeline',
      'data[]' => scraper
    {
      process '//div[@class="id"]',
        'status'    => 'TEXT';
      process '//div[@class="main"]/div[@class="body"]',
        'body'      => 'TEXT';
      process '//div[@class="main"]/div[@class="body"]/span[@class="name"]/a',
        'name'      => 'TEXT';
      process '//div[@class="main"]/div[@class="clearfix"]/div[@class="time"]/a[1]',
        'datetime'  => 'TEXT';
      process '//div[@class="main"]/div[@class="clearfix"]/div[@class="time"]/a[2]',
        'group'     => $group,
        'gid'       => '@href';
    };
    result 'data';
  };
  return $scraper->scrape(Encode::decode_utf8 $data->{_content}),$group;	
}

1;
__END__

=back

=head1 AUTHOR

Likkradyus E<lt>git {at} li.que.jpE<gt>

=head1 SEE ALSO
L<http://www.aipolive.com/>,
WWW::Mechnize,
Web::Scraper,

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
