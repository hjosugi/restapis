# elixir-phoenix

Elixir + [Phoenix](https://www.phoenixframework.org/) の users REST API と、[Req](https://hexdocs.pm/req/) で書いたクライアント。ポートは **8011**。
`mix phx.new --no-ecto --no-html --no-assets ...` で作った雛形から、API に要らないもの（HTML・セッション・Telemetry・テスト等）を削っている。

| ファイル | 内容 |
|---|---|
| `lib/users_api_web/router.ex` | ルート定義。`get "/users/:id", UserController, :show` |
| `lib/users_api_web/controllers/user_controller.ex` | コントローラー。`with` で入力チェック → `json(conn, user)` / `put_status(:created)`、`params` からクエリ、`conn.body_params` からボディ |
| `lib/users_api_web/controllers/fallback_controller.ex` | `action_fallback`。コントローラーが返した `{:error, ...}` を 400 / 404 の `{"error": ...}` にする |
| `lib/users_api_web/controllers/error_json.ex` | 壊れた JSON（`Plug.Parsers.ParseError`）や存在しないルートを `{"error": ...}` にする（`render_errors`） |
| `lib/users_api_web/endpoint.ex` | `Plug.Parsers` で JSON ボディをデコード、dev では `Phoenix.CodeReloader` |
| `lib/users_api/store.ex` / `user.ex` | `Agent` のストア（`Application` の supervisor で起動）と `@derive JSON.Encoder` した `%User{}` |
| `lib/mix/tasks/client.ex` | クライアント（`mix client`）。`Req.new(base_url: ...)` + `Req.request/2`、`JSON.encode!` / `JSON.decode!`、`URI.encode_query` |
| `config/config.exs` / `runtime.exs` | JSON は Elixir 標準の `JSON` モジュール（Jason なし）、`PORT` は起動時に読む |

```sh
task dev     # MIX_ENV=dev。コードを変えると次のリクエストで再コンパイル (Phoenix.CodeReloader)
task run     # MIX_ENV=prod でサーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # mix format
task lint    # mix compile --warnings-as-errors + mix credo
iex -S mix phx.server   # IEx 付きで起動（Store.list(nil, nil) などを直接呼べる）
```

ツール: Erlang/OTP 29 / Elixir 1.20 / Hex / rebar3 / Expert（LSP）（すべて `flake.nix`）、Credo（`mix.exs` の dev 依存）。
Hex は nix のものを `MIX_PATH` で読み込むので `mix local.hex` は不要。
