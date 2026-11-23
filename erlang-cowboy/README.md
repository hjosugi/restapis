# erlang-cowboy

Erlang/OTP + [Cowboy](https://ninenines.eu/) の users REST API と、OTP 標準の `httpc` だけで書いたクライアント。ポートは **8012**。
JSON は OTP 27+ 標準の `json` モジュール。

| ファイル | 内容 |
|---|---|
| `src/users_api_app.erl` | アプリケーション。`cowboy_router:compile` でルート定義、`cowboy:start_clear` で HTTP リスナー起動 |
| `src/users_handler.erl` | ハンドラ（素の `cowboy_handler`）。`cowboy_req:match_qs` でクエリ、`read_body` + `json:decode` でボディ、ガード付きの `validate/2` で入力チェック、`maybe` 式で処理をつなぎ `cowboy_req:reply` で返す |
| `src/users_store.erl` / `users_api_sup.erl` | `gen_server` のストアと、それを起動する supervisor |
| `src/users_client.erl` | クライアント。`httpc:request/4`、`json:encode` / `json:decode` → `#user{}` レコード、`uri_string:compose_query` |

```sh
task dev     # ファイル変更でコンパイル + 再起動 (watchexec)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # erlfmt --write
task lint    # erlfmt --check + elvis rock
rebar3 shell # シェル付きで起動（users_store:list(<<>>, undefined) などを直接呼べる）
```

ツール: Erlang/OTP 29 / rebar3 / ELP（LSP）/ erlfmt / elvis（すべて `flake.nix`）
