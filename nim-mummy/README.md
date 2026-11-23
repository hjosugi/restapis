# nim-mummy

Nim + [Mummy](https://github.com/guzba/mummy)（マルチスレッドの HTTP サーバー）の users REST API と、標準ライブラリ `std/httpclient` だけで書いたクライアント。ポートは **8016**。

| ファイル | 内容 |
|---|---|
| `src/server.nim` | サーバー。`router.get("/users/@id", handler)` でルート定義、`request.pathParams` / `request.queryParams` でパラメーター取得、`parseJson(body).to(UserInput)` + 手書きのチェックで入力検証、`request.respond(status, headers, $(%user))` でレスポンス。ストアは `Lock` + `{.guard.}` で守る |
| `src/client.nim` | クライアント。`newHttpClient()` + `client.request(url, HttpPost, body, headers)`、`%obj` / `parseJson(...).to(User)` で JSON 変換、`encodeQuery` でクエリ組み立て |
| `nim_mummy.nimble` / `nimble.lock` | 依存（mummy）とロックファイル。`task deps`（`nimble --localdeps setup`）が `nimbledeps/` に取得し、`nimble.paths` 経由で `config.nims` から読み込む |

```sh
task dev     # ホットリロード (watchexec)
task run     # サーバー起動 (別名: task main / task server)。依存は初回に自動取得
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # nph
task lint    # nim check（警告が出たら失敗）
task build   # bin/ にビルド（--debugger:native。VS Code の CodeLLDB や nim-gdb でデバッグ）
```

ツール: Nim 2.2 / nimble / nimlangserver / nph / gdb (nim-gdb)（すべて `flake.nix`）
