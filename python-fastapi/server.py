"""users リソースの CRUD を提供する REST API サーバー（FastAPI / インメモリ保存）と htmx の画面。"""

import os
import threading
from pathlib import Path
from typing import Annotated

import uvicorn
from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, ConfigDict, Field
from starlette.exceptions import HTTPException as StarletteHTTPException


class User(BaseModel):
    """API で扱うリソース。レスポンスはこのモデルから JSON に変換される。"""

    id: int
    name: str
    email: str
    age: int


class UserInput(BaseModel):
    """POST / PUT のリクエストボディ。型と値の範囲は pydantic がチェックする。"""

    # strict: "1" -> 1 のような型の自動変換をしない（文字列の age は 400）
    model_config = ConfigDict(strict=True)

    name: str = Field(min_length=1)
    email: str = Field(min_length=1)
    age: int = Field(ge=0)


class UserStore:
    """メモリ上のユーザー一覧。def のエンドポイントはスレッドプールで並行に動くので Lock で守る。"""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._users: dict[int, User] = {}
        self._next_id = 1
        self.create(UserInput(name="Alice", email="alice@example.com", age=30))
        self.create(UserInput(name="Bob", email="bob@example.com", age=25))

    def search(self, name: str | None = None, min_age: int | None = None) -> list[User]:
        with self._lock:
            users = sorted(self._users.values(), key=lambda u: u.id)
        if name:
            users = [u for u in users if name.casefold() in u.name.casefold()]
        if min_age is not None:
            users = [u for u in users if u.age >= min_age]
        return users

    def get(self, user_id: int) -> User | None:
        with self._lock:
            return self._users.get(user_id)

    def create(self, data: UserInput) -> User:
        with self._lock:
            user = User(id=self._next_id, **data.model_dump())
            self._users[user.id] = user
            self._next_id += 1
            return user

    def update(self, user_id: int, data: UserInput) -> User | None:
        with self._lock:
            if user_id not in self._users:
                return None
            user = User(id=user_id, **data.model_dump())
            self._users[user_id] = user
            return user

    def delete(self, user_id: int) -> bool:
        with self._lock:
            return self._users.pop(user_id, None) is not None


app = FastAPI(title="users API")
store = UserStore()
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


# --- エラーを仕様どおり {"error": "..."} + JSON にそろえる -----------------------------


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    """入力チェックの失敗（既定は 422 + {"detail": [...]}）を 400 にする。

    壊れた JSON・項目の欠け・型違い・min_age=abc・/users/abc はすべてここに来る。
    """
    message = "; ".join(f"{'.'.join(map(str, e['loc']))}: {e['msg']}" for e in exc.errors())
    return JSONResponse({"error": message}, status_code=400)


@app.exception_handler(StarletteHTTPException)
async def http_error_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    """raise HTTPException と、存在しないパスの 404 / 405 を {"error": ...} にする。"""
    return JSONResponse({"error": exc.detail}, status_code=exc.status_code, headers=exc.headers)


# --- JSON API: ルートはデコレーター、引数の型ヒントがそのまま入力チェックになる ----------


# GET /users?name=al&min_age=20 （クエリパラメータは関数の引数。int に変換できなければ 400）
@app.get("/users")
def list_users(name: str | None = None, min_age: int | None = None) -> list[User]:
    return store.search(name, min_age)


# パスの {user_id} は int に変換される
@app.get("/users/{user_id}")
def get_user(user_id: int) -> User:
    if (user := store.get(user_id)) is None:
        raise HTTPException(status_code=404, detail="user not found")
    return user


# ボディは JSON から UserInput に変換・検証される。成功時のステータスはデコレーターで指定
@app.post("/users", status_code=201)
def create_user(data: UserInput) -> User:
    return store.create(data)


@app.put("/users/{user_id}")
def update_user(user_id: int, data: UserInput) -> User:
    if (user := store.update(user_id, data)) is None:
        raise HTTPException(status_code=404, detail="user not found")
    return user


# 204 はボディなし
@app.delete("/users/{user_id}", status_code=204)
def delete_user(user_id: int) -> None:
    if not store.delete(user_id):
        raise HTTPException(status_code=404, detail="user not found")


# --- htmx の画面: HTML（断片）を返すルートは /ui/... に分ける ----------------------------


@app.get("/", response_class=HTMLResponse)
def index(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "index.html", {"users": store.search()})


# 検索ボックスから hx-get され、一覧の <tr> だけを返す
@app.get("/ui/users", response_class=HTMLResponse)
def ui_list_users(request: Request, name: str | None = None) -> HTMLResponse:
    return templates.TemplateResponse(request, "rows.html", {"users": store.search(name)})


# フォーム（application/x-www-form-urlencoded）から作成し、追加した 1 行を返す
@app.post("/ui/users", response_class=HTMLResponse)
def ui_create_user(
    request: Request,
    name: Annotated[str, Form(min_length=1)],
    email: Annotated[str, Form(min_length=1)],
    age: Annotated[int, Form(ge=0)],
) -> HTMLResponse:
    user = store.create(UserInput(name=name, email=email, age=age))
    return templates.TemplateResponse(request, "rows.html", {"users": [user]})


# htmx は 204 だと何もしないので、200 + 空ボディを返して行を消させる
@app.delete("/ui/users/{user_id}", response_class=HTMLResponse)
def ui_delete_user(user_id: int) -> HTMLResponse:
    if not store.delete(user_id):
        raise HTTPException(status_code=404, detail="user not found")
    return HTMLResponse("")


if __name__ == "__main__":
    # task run（python server.py）で起動。task dev は uvicorn --reload で server:app を読み込む
    uvicorn.run(app, host="127.0.0.1", port=int(os.environ.get("PORT", "8007")))
