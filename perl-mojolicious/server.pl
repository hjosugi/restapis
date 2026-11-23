#!/usr/bin/env perl
# users リソースの CRUD を提供する REST API サーバー（Mojolicious::Lite / インメモリ保存）。
#   perl server.pl daemon -l http://127.0.0.1:8017    開発時は morbo server.pl（自動リロード）
use Mojolicious::Lite -signatures;
use JSON::Validator;

# -l を省略して `perl server.pl daemon` で起動したときの待ち受け先（PORT 未指定なら 8017）
$ENV{MOJO_LISTEN} ||= 'http://127.0.0.1:' . ($ENV{PORT} || 8017);

# メモリ上のユーザー一覧（id => ユーザー）。Mojolicious は 1 プロセスのイベントループなのでロック不要
my %users;
my $next_id = 1;

sub create_user ($in) {
  my $user = {id => $next_id++, name => $in->{name}, email => $in->{email}, age => $in->{age}};
  return $users{$user->{id}} = $user;
}
create_user({name => 'Alice', email => 'alice@example.com', age => 30});
create_user({name => 'Bob',   email => 'bob@example.com',   age => 25});

# POST / PUT のボディを JSON Schema で検証する（age は integer なので文字列 "1" は型違いで弾かれる）
my $input_schema = JSON::Validator->new->schema({
  type       => 'object',
  required   => [qw(name email age)],
  properties => {
    name  => {type => 'string',  minLength => 1},
    email => {type => 'string',  minLength => 1},
    age   => {type => 'integer', minimum   => 0},
  },
});

# エラーは {"error": "..."} で返す
helper error => sub ($c, $status, $message) {
  return $c->render(status => $status, json => {error => $message});
};

# リクエストボディの JSON を検証して返す。不正なら 400 を返して undef
helper user_input => sub ($c) {
  my $in = $c->req->json;    # 壊れた JSON なら undef（→ "Expected object - got null."）
  if (my @errors = $input_schema->validate($in)) {
    $c->error(400, join ', ', @errors);
    return;
  }
  return $in;
};

# フレームワーク既定の 404 / 500 ページ（HTML）を JSON に置き換える
my %default_errors = (not_found => 'not found', exception => 'internal server error');
hook before_render => sub ($c, $args) {
  my $message = $default_errors{$args->{template} // ''} or return;
  $args->{json} = {error => $message};
  return;
};

# GET /users?name=al&min_age=20（両方指定したら AND）
# クエリパラメータは Mojolicious の validation でチェック（num = 整数。空文字は未指定扱い）
get '/users' => sub ($c) {
  my $v = $c->validation;
  $v->optional('name');
  $v->optional('min_age', 'not_empty')->num;
  return $c->error(400, 'min_age must be an integer') if $v->has_error;

  my $name    = fc($v->param('name') // '');
  my $min_age = $v->param('min_age');
  my @result  = grep { index(fc $_->{name}, $name) >= 0 && (!defined $min_age || $_->{age} >= $min_age) }
    map { $users{$_} } sort { $a <=> $b } keys %users;    # id 昇順
  return $c->render(json => \@result);
};

# <id:num> は数字だけにマッチする（/users/abc はどのルートにも当たらず 404）
get '/users/<id:num>' => sub ($c) {
  my $user = $users{$c->param('id')} or return $c->error(404, 'user not found');
  return $c->render(json => $user);
};

post '/users' => sub ($c) {
  my $in = $c->user_input or return;
  return $c->render(status => 201, json => create_user($in));
};

put '/users/<id:num>' => sub ($c) {
  my $in   = $c->user_input          or return;
  my $user = $users{$c->param('id')} or return $c->error(404, 'user not found');

  # id 以外を全置換
  @$user{qw(name email age)} = @$in{qw(name email age)};
  return $c->render(json => $user);
};

# 204 はボディなし
del '/users/<id:num>' => sub ($c) {
  delete $users{$c->param('id')} or return $c->error(404, 'user not found');
  return $c->rendered(204);
};

app->start;
