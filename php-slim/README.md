# php-slim

PHP 8.5 + [Slim 4](https://www.slimframework.com/) の users REST API と、[Guzzle](https://docs.guzzlephp.org/) で書いたクライアント。ポートは **8018**。

PHP は普通リクエストごとに状態が消えるので、[ReactPHP](https://reactphp.org/http/) の HTTP サーバー（1 プロセスのイベントループ）で Slim アプリを動かしてインメモリ配列を保持する（Composer の依存だけで完結し、`php server.php` 1 本で動くのが一番シンプルなため）。

| ファイル | 内容 |
|---|---|
| `server.php` | サーバー。`$app->get('/users/{id:[0-9]+}', ...)` でルート定義、`json_decode` + `is_string` / `is_int` で入力チェック、`HttpBadRequestException` / `HttpNotFoundException` を投げてエラーミドルウェアのハンドラで `{"error": ...}` の JSON に、`new HttpServer($app->handle(...))` で ReactPHP に載せる |
| `client.php` | クライアント。`$client->request($method, $path, ['json' => ...])`（`http_errors => false`）、`json_decode` した配列を名前付き引数で `User` クラスに、`http_build_query` でクエリ組み立て |

```sh
task dev     # ホットリロード (watchexec で再起動)
task run     # サーバー起動 (別名: task main / task server)。vendor/ がなければ composer install も実行
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # PHP-CS-Fixer (PER-CS 3.0)
task lint    # PHPStan (level max)
```

ツール: PHP 8.5（Xdebug 入り。普段は off）/ Composer / phpactor / PHP-CS-Fixer / PHPStan（すべて `flake.nix`）
