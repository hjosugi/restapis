# rust-axum

Rust + [axum](https://github.com/tokio-rs/axum) の users REST API と、[reqwest](https://docs.rs/reqwest)（blocking API）で書いたクライアント。ポートは **8004**。

| ファイル | 内容 |
|---|---|
| `src/bin/server.rs` | サーバー。`Router::new().route("/users/{id}", get(...).put(...))` でルート定義、`Json<UserInput>` / `Query<Search>` / `Path<u64>` 抽出器 + serde の型で入力チェック（失敗は `Result<Json<_>, JsonRejection>` で受けて `?` で 400 + JSON に変換）、`Arc<Mutex<Store>>` を `State` で共有 |
| `src/bin/client.rs` | クライアント。`reqwest::blocking::Client` の `.get()` / `.post(..).json(&input)` / `.query(&[..])`、`serde_json::from_str` で `User` 構造体にデコード |

```sh
task dev     # ホットリロード (watchexec)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # cargo fmt (rustfmt)
task lint    # cargo clippy（pedantic、警告もエラー扱い）
```

ツール: Rust (rustc / cargo) / rust-analyzer / rustfmt / clippy（すべて `flake.nix`）。VS Code のデバッグは CodeLLDB（拡張に同梱の lldb）
