# fsharp-giraffe

F# + [Giraffe](https://giraffe.wiki/)（ASP.NET Core 上の関数型 Web フレームワーク）の users REST API と、`HttpClient` + `System.Net.Http.Json` で書いたクライアント。ポートは **8010**。

| ファイル | 内容 |
|---|---|
| `src/Server/Program.fs` | サーバー。`choose [ GET >=> routef "/users/%i" getUser; ... ]` でルート定義、`ctx.BindJsonAsync<UserInput>()`（System.Text.Json）+ `validate` で入力チェック、`setStatusCode 201 >=> json user` でレスポンス、`ctx.TryGetQueryStringValue` でクエリ取得 |
| `src/Client/Program.fs` | クライアント。`HttpRequestMessage` + `HttpClient.SendAsync`、`JsonContent.Create` で送信、`ReadFromJsonAsync<User>()` でレコードに変換 |
| `fsharp-giraffe.slnx` / `Directory.Build.props` | 2 プロジェクトのソリューションと共通設定（net11.0、警告はエラー、`packages.lock.json`） |

```sh
task dev     # ホットリロード (dotnet watch。F# は変更のたびに再ビルド + 再起動)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # Fantomas (.editorconfig の設定)
task lint    # fantomas --check + FSharpLint
```

ツール: .NET SDK 11 / FsAutoComplete / netcoredbg / Fantomas / FSharpLint（すべて `flake.nix`）。
作業後に MSBuild のプロセスが残っていたら `dotnet build-server shutdown`。
