"""REST API に CRUD + 検索を一通り投げるクライアント（httpx）。"""

import os
import sys
from dataclasses import asdict, dataclass

import httpx

BASE_URL = os.environ.get("API_URL", "http://127.0.0.1:8007")


@dataclass
class User:
    id: int
    name: str
    email: str
    age: int


@dataclass
class UserInput:
    name: str
    email: str
    age: int


def call(
    client: httpx.Client,
    method: str,
    path: str,
    *,
    params: dict[str, str] | None = None,
    body: UserInput | None = None,
) -> httpx.Response:
    """リクエストを 1 本送り、送った内容と返ってきた内容を表示する。"""
    # json= に dict を渡すと httpx が JSON 文字列にして Content-Type: application/json を付ける。
    # params= はクエリ文字列（?name=car）に組み立てられる
    request = client.build_request(
        method, path, params=params, json=asdict(body) if body is not None else None
    )
    sent = f" {request.content.decode()}" if request.content else ""
    print(f"> {method} {request.url.raw_path.decode()}{sent}")

    try:
        response = client.send(request)
    except httpx.TransportError as e:
        sys.exit(f"リクエスト失敗（サーバーは起動していますか？）: {e}")
    print(f"< {response.status_code} {response.text}\n")
    return response


def main() -> None:
    with httpx.Client(base_url=BASE_URL) as client:
        print("--- 1. 一覧取得")
        call(client, "GET", "/users")

        print("--- 2. 作成")
        response = call(client, "POST", "/users", body=UserInput("Carol", "carol@example.com", 35))
        created = User(**response.json())  # JSON -> dict -> dataclass
        user_path = f"/users/{created.id}"

        print("--- 3. 1件取得")
        call(client, "GET", user_path)

        print("--- 4. 更新")
        call(client, "PUT", user_path, body=UserInput("Carol Smith", "carol@example.com", 36))

        print("--- 5. 検索（名前の部分一致）")
        call(client, "GET", "/users", params={"name": "car"})

        print("--- 6. 検索（年齢の下限）")
        call(client, "GET", "/users", params={"min_age": "30"})

        print("--- 7. 削除")
        call(client, "DELETE", user_path)

        print("--- 8. 削除されたことを確認（404 になる）")
        call(client, "GET", user_path)


if __name__ == "__main__":
    main()
