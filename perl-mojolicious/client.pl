#!/usr/bin/env perl
# REST API に CRUD + 検索を一通り投げるクライアント（Mojo::UserAgent）。
use Mojo::Base -strict, -signatures;
use Mojo::JSON qw(to_json);
use Mojo::Parameters;
use Mojo::UserAgent;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $base_url = $ENV{API_URL} || 'http://127.0.0.1:8017';
my $ua       = Mojo::UserAgent->new;

# リクエストを 1 本送り、送った内容と返ってきた内容を表示する
sub call ($method, $path, $body = undef) {
  if (defined $body) { say "> $method $path ", to_json($body) }
  else               { say "> $method $path" }

  # json => ... で JSON にエンコードし Content-Type: application/json を付けて送る
  my $tx = $ua->start($ua->build_tx($method => "$base_url$path", defined $body ? (json => $body) : ()));
  if (my $err = $tx->error) {
    if (!$err->{code}) {    # code がない = HTTP の応答自体がない（接続失敗など）
      say STDERR "リクエスト失敗（サーバーは起動していますか？）: $err->{message}";
      exit 1;
    }
  }
  printf "< %d %s\n\n", $tx->res->code, $tx->res->text;
  return $tx->res;
}

say '--- 1. 一覧取得';
call(GET => '/users');

say '--- 2. 作成';

# ->json でレスポンスの JSON をハッシュリファレンスにデコードして id を取り出す
my $created   = call(POST => '/users', {name => 'Carol', email => 'carol@example.com', age => 35})->json;
my $user_path = "/users/$created->{id}";

say '--- 3. 1件取得';
call(GET => $user_path);

say '--- 4. 更新';
call(PUT => $user_path, {name => 'Carol Smith', email => 'carol@example.com', age => 36});

say '--- 5. 検索（名前の部分一致）';
call(GET => '/users?' . Mojo::Parameters->new(name => 'car'));

say '--- 6. 検索（年齢の下限）';
call(GET => '/users?' . Mojo::Parameters->new(min_age => 30));

say '--- 7. 削除';
call(DELETE => $user_path);

say '--- 8. 削除されたことを確認（404 になる）';
call(GET => $user_path);
