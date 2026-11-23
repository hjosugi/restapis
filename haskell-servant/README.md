# haskell-servant

Haskell + [Servant](https://docs.servant.dev/) の users REST API と、同じ API 型から [servant-client](https://hackage.haskell.org/package/servant-client) で導出したクライアント。ポートは **8005**。

| ファイル | 内容 |
|---|---|
| `src/Api.hs` | サーバーとクライアントで共有する API 型。`"users" :> Capture "id" Int :> Get '[JSON] User` のようにルートを型で定義、`QueryParam "min_age" Int` でクエリ、`FromJSON UserInput` で入力チェック |
| `app/Server.hs` | サーバー。`Server UsersAPI` のハンドラを `:<|>` で並べ、`throwError err404` でエラー、`serveWithContext` + `ErrorFormatters` で既定のエラーを `{"error": ...}` に、warp で起動 |
| `app/Client.hs` | クライアント。`listUsers :<|> getUser :<|> ... = client (Proxy @UsersAPI)` で関数を導出、`runClientM` で実行、`ClientEnv` の `middleware` で送受信を表示、404 は `FailureResponse` |
| `haskell-servant.cabal` | library (Api) + executable `server` / `client`。依存は `flake.nix` の `ghcWithPackages` から入るので Hackage は使わない |

```sh
task dev     # ホットリロード (ghcid + cabal repl)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task build   # cabal build
task fmt     # fourmolu
task lint    # hlint
```

ツール: GHC 9.10 + servant 0.20 / cabal-install / haskell-language-server / fourmolu / hlint / ghcid（すべて `flake.nix`）
