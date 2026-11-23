# python-fastapi

Python + [FastAPI](https://fastapi.tiangolo.com/) の users REST API（+ [htmx](https://htmx.org/) の小さな画面）と、[httpx](https://www.python-httpx.org/) で書いたクライアント。ポートは **8007**。

| ファイル | 内容 |
|---|---|
| `server.py` | サーバー。`@app.get("/users/{user_id}")` でルート定義、引数の型ヒント + pydantic の `BaseModel` / `Field` で入力チェック、戻り値の型からレスポンスの JSON を作る。`@app.exception_handler` で既定の 422 / `{"detail": ...}` を 400 / `{"error": ...}` にそろえる |
| `templates/*.html` | htmx の画面（Jinja2）。`GET /` が全体、`/ui/users` が一覧の行（HTML 断片）を返し、`hx-get` で名前検索、`hx-post` で作成、`hx-delete` で削除 |
| `client.py` | クライアント。`httpx.Client(base_url=...)` + `build_request` / `send`、`json=` で JSON 送信、`params=` でクエリ組み立て、`response.json()` を dataclass に詰める |

```sh
task dev     # ホットリロード (uvicorn --reload)。画面は http://127.0.0.1:8007/
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task check   # curl で API 仕様どおりか検証
task fmt     # ruff format + import の並べ替え
task lint    # ruff check + ty check（型チェック）
```

依存は `pyproject.toml` + `uv.lock`。`uv run` が初回に `.venv` を作って自動で入れる（Python 本体は nix のものを使う）。

ツール: Python 3.15 / uv / ruff / ty（すべて `flake.nix`）
