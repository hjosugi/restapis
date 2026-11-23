# go-gin

Go + [Gin](https://gin-gonic.com/) の users REST API と、標準ライブラリ `net/http` だけで書いたクライアント。ポートは **8003**。

| ファイル | 内容 |
|---|---|
| `cmd/server/main.go` | サーバー。`r.GET("/users/:id", ...)` でルート定義、`c.ShouldBindJSON` + `binding` タグで入力チェック、`c.JSON` でレスポンス |
| `cmd/client/main.go` | クライアント。`http.NewRequest` + `http.DefaultClient.Do`、`json.Marshal` / `json.Unmarshal`、`url.Values` でクエリ組み立て |

```sh
task dev     # ホットリロード (watchexec)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # golangci-lint fmt (gofumpt + goimports)
task lint    # golangci-lint run
```

ツール: Go / gopls / delve / gofumpt / golangci-lint v2（すべて `flake.nix`）
