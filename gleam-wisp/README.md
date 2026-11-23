# gleam-wisp

Gleam + [Wisp](https://github.com/gleam-wisp/wisp)（HTTP サーバーは [Mist](https://github.com/rawhat/mist)）の users REST API と、
[gleam_httpc](https://github.com/gleam-lang/httpc) で書いたクライアント。ポートは **8013**。

| ファイル | 内容 |
|---|---|
| `src/server.gleam` | サーバー。`case wisp.path_segments(req), req.method` のパターンマッチでルート定義、`gleam/dynamic/decode` のデコーダー + `validate` で入力チェック、`wisp.json_response` でレスポンス。ストアは `gleam/otp/actor`（メッセージを 1 つずつ処理するのでロック不要） |
| `src/client.gleam` | クライアント。`request.to` + `request.set_method` / `request.set_body` で組み立てて `httpc.send`、`json.parse` + デコーダーで `User` 型に変換、`uri.query_to_string` でクエリ組み立て |
| `gleam.toml` / `manifest.toml` | 依存定義とロックファイル（`gleam run` が自動で取得） |

```sh
task dev     # ファイル変更で再起動 (watchexec)
task run     # サーバー起動 = gleam run -m server (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行 = gleam run -m client
task check   # curl で API 仕様どおりか検証
task fmt     # gleam format
task lint    # gleam format --check + gleam build --warnings-as-errors（コンパイラ警告 0 件）
```

ツール: Gleam / Erlang/OTP 29 / rebar3（すべて `flake.nix`。LSP と formatter は gleam 本体の `gleam lsp` / `gleam format`）
