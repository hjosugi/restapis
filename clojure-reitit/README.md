# clojure-reitit

Clojure + [reitit](https://github.com/metosin/reitit)（Ring / Jetty）の users REST API と、[babashka/http-client](https://github.com/babashka/http-client) で書いたクライアント。ポートは **8014**。

| ファイル | 内容 |
|---|---|
| `src/users/server.clj` | サーバー。`["/users" ["/:id" {:get {...}}]]` のようにルートをデータで定義、malli スキーマ（`:parameters`）で入力チェック、muuntaja でマップ ⇔ JSON、ストアは `atom` |
| `src/users/client.clj` | クライアント。`http/request` に `:method` / `:query-params` / `:throw false`、jsonista の `write-value-as-string` / `read-value` で JSON 変換 |
| `deps.edn` | 依存（バージョン固定）と `:server` / `:client` alias |

```sh
task dev     # 変更検知で再起動 (watchexec)
task run     # サーバー起動 (別名: task main / task server) = clojure -M:server
task client  # 別ターミナルで CRUD + 検索を実行   = clojure -M:client
task check   # curl で API 仕様どおりか検証
task fmt     # cljfmt fix
task lint    # clj-kondo + cljfmt check
```

REPL で開発するなら VS Code は Calva の Jack-in（deps.edn）→ `server.clj` 末尾の `(comment ...)` 内のフォームを評価して起動 / 停止。

ツール: JDK 25 / Clojure CLI / clojure-lsp / clj-kondo / cljfmt（すべて `flake.nix`）
