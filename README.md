# restapis

いろいろな言語・フレームワークで **同じ仕様の users REST API**（インメモリ、DB なし）と、**同じ言語で書いたクライアント**を作って、
「REST API の作り方」と「REST API への問い合わせ方」を見比べるためのリポジトリ。

- 言語ごとに `<言語>-<フレームワーク>/` ディレクトリ
- ツールチェーン / LSP / formatter / linter はすべてディレクトリごとの `flake.nix`（nixpkgs unstable）
- 実行は [Task](https://taskfile.dev)（`task dev` / `task run` / `task client` ...）
- 全実装が同じ仕様なので、**どのクライアントからどのサーバーにも**アクセスできる（ポートが違うので全部同時に起動可）

## 実装一覧

| ディレクトリ | ポート | 言語 | サーバー | クライアント |
|---|---|---|---|---|
| [c-libmicrohttpd](c-libmicrohttpd) | 8001 | C23 (gcc 16) | libmicrohttpd + cJSON | libcurl |
| [cpp-drogon](cpp-drogon) | 8002 | C++23 (gcc 16) | Drogon | cpr |
| [go-gin](go-gin) | 8003 | Go 1.27 | Gin | net/http |
| [rust-axum](rust-axum) | 8004 | Rust 1.99 | axum | reqwest |
| [haskell-servant](haskell-servant) | 8005 | GHC 9.10 | Servant | servant-client（API 型から自動導出） |
| [typescript-elysia](typescript-elysia) | 8006 | TypeScript 7 / Bun 1.4 | Elysia | fetch |
| [python-fastapi](python-fastapi) | 8007 | Python 3.15 | FastAPI + htmx 画面 | httpx |
| [java-spring](java-spring) | 8008 | Java 25 | Spring Boot 4 (Maven) | RestClient |
| [kotlin-spring](kotlin-spring) | 8009 | Kotlin 2.4 | Spring Boot 4 (Gradle) | RestClient |
| [fsharp-giraffe](fsharp-giraffe) | 8010 | F# / .NET 11 | Giraffe | HttpClient |
| [elixir-phoenix](elixir-phoenix) | 8011 | Elixir 1.20 / OTP 29 | Phoenix | Req |
| [erlang-cowboy](erlang-cowboy) | 8012 | Erlang/OTP 29 | Cowboy | httpc |
| [gleam-wisp](gleam-wisp) | 8013 | Gleam 1.19 | Wisp + Mist | gleam_httpc |
| [clojure-reitit](clojure-reitit) | 8014 | Clojure 1.12 | reitit + Ring (Jetty) | babashka/http-client |
| [lisp-hunchentoot](lisp-hunchentoot) | 8015 | Common Lisp (SBCL 2.6) | Hunchentoot + easy-routes | dexador |
| [nim-mummy](nim-mummy) | 8016 | Nim 2.2 | Mummy | std/httpclient |
| [perl-mojolicious](perl-mojolicious) | 8017 | Perl 5.42 | Mojolicious | Mojo::UserAgent |
| [php-slim](php-slim) | 8018 | PHP 8.5 | Slim（ReactPHP で常駐） | Guzzle |

### formatter / linter / LSP（すべて各ディレクトリの flake.nix に入っている）

| ディレクトリ | formatter (`task fmt`) | linter (`task lint`) | LSP |
|---|---|---|---|
| c-libmicrohttpd / cpp-drogon | clang-format | clang-tidy | clangd |
| go-gin | gofumpt + goimports | golangci-lint v2 | gopls |
| rust-axum | rustfmt | clippy | rust-analyzer |
| haskell-servant | fourmolu | hlint | haskell-language-server |
| typescript-elysia | oxfmt | oxlint + tsc | tsc --lsp (TypeScript 7) |
| python-fastapi | ruff format | ruff + ty | ruff / ty |
| java-spring | google-java-format | PMD | jdtls |
| kotlin-spring | ktlint | ktlint | kotlin-language-server（VS Code は Kotlin by JetBrains） |
| fsharp-giraffe | Fantomas | FSharpLint | fsautocomplete |
| elixir-phoenix | mix format | Credo | Expert |
| erlang-cowboy | erlfmt | elvis | ELP |
| gleam-wisp | gleam format | gleam build --warnings-as-errors | gleam lsp |
| clojure-reitit | cljfmt | clj-kondo | clojure-lsp |
| lisp-hunchentoot | cl-indentify | mallet | alive-lsp（VS Code）/ swank（Conjure） |
| nim-mummy | nph | nim check | nimlangserver |
| perl-mojolicious | perltidy | perlcritic | PerlNavigator |
| php-slim | PHP-CS-Fixer | PHPStan (level max) | phpactor（VS Code は Intelephense） |

## 使い方

```sh
cd go-gin          # direnv が flake の devShell を読み込む（初回は `direnv allow`）
task run           # サーバー起動（別名: task main / task server）
task client        # 別ターミナルで: クライアントが CRUD + 検索を順番に実行
task dev           # ホットリロードでサーバー起動
task check         # 起動中のサーバーが仕様どおりか curl で検証 (scripts/check.sh)
task fmt / task lint

# ルートからでも OK
task go-gin:run
task go-gin:client

# 別言語のクライアント → 別言語のサーバー
API_URL=http://127.0.0.1:8004 task go-gin:client   # Go クライアントで Rust サーバーを叩く
```

direnv を使わずに実行しても、Taskfile が自動で `nix develop` を挟むので動く（少し遅くなるだけ）。

## エディタ

- **Neovim (LazyVim)**: 各ディレクトリの `.lazy.lua` が、LSP / formatter / linter を Mason ではなく
  nix devShell のもの（`mason = false`）で動かす設定。direnv が効いたシェルで、そのディレクトリに `cd` してから `nvim` を開く
  （初回は `.lazy.lua` を信頼するか聞かれる）。
- **VS Code**: ディレクトリごとにフォルダとして開く（`code go-gin`）。`.vscode/` に
  `extensions.json`（推奨拡張）/ `settings.json` / `launch.json`（server と client のデバッグ起動）がある。
  `mkhl.direnv` 拡張が flake の環境を読み込むので、拡張は nix のツールを使う。
  推奨拡張は `task vscode-extensions` でまとめてインストールできる。
- `users.http` は VS Code の REST Client / Neovim の kulala.nvim でそのまま実行できる。

## API 仕様（全実装共通）

ユーザー:

```json
{ "id": 1, "name": "Alice", "email": "alice@example.com", "age": 30 }
```

| メソッド | パス | ボディ | 成功 | エラー |
|---|---|---|---|---|
| GET | `/users` | | 200 ユーザー配列（id 昇順） | 400 `min_age` が整数でない |
| GET | `/users/{id}` | | 200 ユーザー | 404 |
| POST | `/users` | 入力 | 201 作成したユーザー | 400 |
| PUT | `/users/{id}` | 入力 | 200 更新後のユーザー（全置換） | 400 / 404 |
| DELETE | `/users/{id}` | | 204（ボディなし） | 404 |

- 検索（`GET /users` のクエリ。両方指定したら AND）
  - `name`: 名前の部分一致（大文字小文字を区別しない）
  - `min_age`: `age >= min_age`
- 入力 `{"name": string, "email": string, "age": integer}`
  - `name` / `email` は空でない文字列、`age` は 0 以上の整数（文字列 `"1"` は不可）
  - 壊れた JSON・欠けている項目・型違い → 400
- エラーは `{"error": "メッセージ"}`、JSON のレスポンスは `Content-Type: application/json`
- 起動時のデータ: `1 Alice alice@example.com 30` / `2 Bob bob@example.com 25`（次の id は 3、削除しても id は再利用しない）
- id が数値でないパス（`/users/abc`）は 400 か 404（実装しだい）
- サーバーは `127.0.0.1:$PORT` で待ち受け（`PORT` 未指定ならディレクトリごとのポート）
- クライアントは `API_URL`（未指定なら `http://127.0.0.1:<ポート>`）に対して次を順に実行して表示する
  1. 一覧取得 `GET /users`
  2. 作成 `POST /users` `{"name":"Carol","email":"carol@example.com","age":35}`
  3. 1件取得 `GET /users/{作成した id}`
  4. 更新 `PUT /users/{id}` `{"name":"Carol Smith","email":"carol@example.com","age":36}`
  5. 検索（名前）`GET /users?name=car`
  6. 検索（年齢）`GET /users?min_age=30`
  7. 削除 `DELETE /users/{id}`
  8. 削除確認 `GET /users/{id}` → 404

curl での例は [users.http](users.http) と [scripts/check.sh](scripts/check.sh) を参照。
