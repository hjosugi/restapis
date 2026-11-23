# typescript-elysia

TypeScript + [Elysia](https://elysiajs.com/)（[Bun](https://bun.com/) 上で動く）の users REST API と、標準の `fetch` だけで書いたクライアント。ポートは **8006**。

| ファイル | 内容 |
|---|---|
| `src/server.ts` | サーバー。`.get("/users/:id", ...)` でルート定義、`t.Object(...)` スキーマ（`body` / `query`）で入力チェック、`onError` で既定の 422 などを `{"error": ...}` に変換、`status(201, ...)` でステータス指定 |
| `src/client.ts` | クライアント。`fetch` + `JSON.stringify` / `JSON.parse`（`User` 型として受け取る）、`URLSearchParams` でクエリ組み立て |

```sh
task dev     # ホットリロード (bun --watch)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # oxfmt
task lint    # oxlint + tsc --noEmit（型チェック）
```

`task run` / `dev` / `client` / `lint` は初回に `bun install` を自動で実行する（`task deps`）。

ツール: Bun / TypeScript 7（`tsc`、LSP は `tsc --lsp`）/ oxfmt / oxlint（すべて `flake.nix`）。npm パッケージは elysia と @types/bun だけ（`package.json` / `bun.lock`）
