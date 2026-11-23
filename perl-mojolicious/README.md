# perl-mojolicious

Perl + [Mojolicious](https://mojolicious.org/)（`Mojolicious::Lite`）の users REST API と、`Mojo::UserAgent` で書いたクライアント。ポートは **8017**。

| ファイル | 内容 |
|---|---|
| `server.pl` | サーバー（1 ファイルの Lite アプリ）。`get '/users/<id:num>' => sub ($c) {...}` でルート定義、`$c->req->json` + [JSON::Validator](https://metacpan.org/pod/JSON::Validator)（JSON Schema）で入力チェック、`$c->validation` でクエリチェック、`$c->render(json => ..., status => ...)` でレスポンス。`before_render` フックで既定の 404 / 500 ページを JSON に置き換え。ストアはハッシュ（1 プロセスのイベントループなのでロック不要） |
| `client.pl` | クライアント。`$ua->build_tx(POST => $url, json => {...})` + `$ua->start`、`$res->json` でハッシュリファレンスにデコード、`Mojo::Parameters` でクエリ組み立て |

```sh
task dev     # 自動リロード (morbo)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # perltidy（Mojolicious 本体と同じ .perltidyrc）
task lint    # perlcritic（severity 3）
```

ツール: Perl 5.42 / PerlNavigator (LSP) / perltidy / perlcritic / Perl::LanguageServer（VS Code の richterger.perl でデバッグ）（すべて `flake.nix`）
