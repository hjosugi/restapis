# cpp-drogon

C++23 + [Drogon](https://github.com/drogonframework/drogon) の users REST API と、[cpr](https://github.com/libcpr/cpr)（libcurl の C++ ラッパー）+ [nlohmann/json](https://github.com/nlohmann/json) で書いたクライアント。ポートは **8002**。

| ファイル | 内容 |
|---|---|
| `src/server.cpp` | サーバー。`app().registerHandler("/users/{id}", ラムダ, {Get})` でルート定義（`{id}` はラムダの引数で受け取る）、`req->getParameter` でクエリ取得、`req->getJsonObject()`（Drogon 付属の jsoncpp `Json::Value`）で入力チェック、`HttpResponse::newHttpJsonResponse` でレスポンス、`setCustomErrorHandler` でフレームワークの 404 / 405 も JSON に。ストアは `std::map` + `std::mutex` |
| `src/client.cpp` | クライアント。`cpr::Session`（`SetUrl` / `SetParameters` でクエリを URL エンコード / `SetBody` + `Post()` など）、`NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE` で構造体 ⇔ JSON 変換 |
| `CMakeLists.txt` / `CMakePresets.json` | `find_package(Drogon / cpr / nlohmann_json)`。プリセット `dev` = Ninja / Debug → `build/`（`build/compile_commands.json` を clangd / clang-tidy が読む） |

```sh
task dev     # ホットリロード (watchexec で再ビルド + 再起動)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task build   # cmake --build --preset dev（初回は task configure が自動で走る）
task fmt     # clang-format
task lint    # clang-format --dry-run + clang-tidy
```

- jsoncpp の `Json::Value` はキーを名前順に並べるので、サーバーのレスポンスは `{"age":..,"email":..,"id":..,"name":..}` の順になる
- クライアントに Drogon の `HttpClient` ではなく cpr を使っているのは、`HttpClient` が非同期（イベントループ前提）で、上から順に投げるだけのクライアントには同期 API の cpr のほうが素直なため

ツール: g++ / CMake / Ninja / clangd・clang-format・clang-tidy (LLVM) / gdb（すべて `flake.nix`）
