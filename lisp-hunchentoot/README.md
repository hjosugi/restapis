# lisp-hunchentoot

Common Lisp (SBCL) + [Hunchentoot](https://edicl.github.io/hunchentoot/) / [easy-routes](https://github.com/mmontone/easy-routes) の users REST API と、[dexador](https://github.com/fukamachi/dexador) で書いたクライアント。ポートは **8015**。
ライブラリは Quicklisp ではなく flake の `sbcl.withPackages` で入れ、ASDF から読み込む。

| ファイル | 内容 |
|---|---|
| `server.lisp` | サーバー。`(easy-routes:defroute users-show ("/users/:id" :method :get) () ...)` でルート定義、`&get` でクエリパラメータ、`hunchentoot:raw-post-data` + `jzon:parse` で入力チェック、`hunchentoot:abort-request-handler` でエラー応答。ストアはハッシュテーブル + `bt:with-lock-held` |
| `client.lisp` | クライアント。`dex:request` + `dex:ignore-and-continue`（4xx を例外にしない）、`jzon:stringify` / `jzon:parse`、`quri:url-encode-params` でクエリ組み立て |
| `users.asd` | ASDF のシステム定義（`users/server` / `users/client`） |

```sh
task dev     # 変更検知で再起動 (watchexec)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # cl-indentify (インデント) + mallet --fix
task lint    # mallet + 警告をエラー扱いでコンパイル + インデント確認
task swank   # nvim (Conjure) 用の swank サーバー (127.0.0.1:4005)
```

REPL で開発するなら VS Code は Alive（LSP サーバー alive-lsp も flake に入っている）、nvim は `task swank` + Conjure。
どちらも `(asdf:load-system "users/server")` → `(users-server:start 8015)` を評価すると REPL を止めずにサーバーが動く。

ツール: SBCL / Hunchentoot / easy-routes / jzon / dexador / [mallet](https://github.com/fukamachi/mallet)（linter）/ [cl-indentify](https://github.com/yitzchak/cl-indentify)（インデント整形）/ alive-lsp / swank（すべて `flake.nix`）
