# c-libmicrohttpd

C (C23) + [GNU libmicrohttpd](https://www.gnu.org/software/libmicrohttpd/) の users REST API と、[libcurl](https://curl.se/libcurl/) で書いたクライアント。JSON はどちらも [cJSON](https://github.com/DaveGamble/cJSON)。ポートは **8001**。

| ファイル | 内容 |
|---|---|
| `src/server.c` | サーバー。`MHD_start_daemon` + アクセスハンドラ 1 つ（POST / PUT のボディは `upload_data` を貯めて最後に処理）、`route()` で `strcmp` ルーティング、`MHD_lookup_connection_value` でクエリ取得、`cJSON_ParseWithLength` + `cJSON_Is*` で入力チェック、`MHD_create_response_from_buffer_with_free_callback` でレスポンス。ストアは配列 + `pthread_mutex` |
| `src/client.c` | クライアント。easy interface（`curl_easy_setopt` + `curl_easy_perform`、`CURLOPT_CUSTOMREQUEST` / `CURLOPT_POSTFIELDS` / `CURLOPT_WRITEFUNCTION`）、`curl_easy_escape` でクエリ組み立て、`cJSON_PrintUnformatted` / `cJSON_Parse` で JSON 変換 |
| `Makefile` | `pkg-config` でライブラリのフラグを取って `bin/server` / `bin/client` をビルド |

```sh
task dev     # ホットリロード (watchexec で再ビルド + 再起動)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task build   # make + bear で compile_commands.json を生成（clangd / clang-tidy 用）
task fmt     # clang-format
task lint    # clang-format --dry-run + clang-tidy
```

ツール: gcc / make / pkg-config / clangd・clang-format・clang-tidy (LLVM) / bear / gdb（すべて `flake.nix`）
