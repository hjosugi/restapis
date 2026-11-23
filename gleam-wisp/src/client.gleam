//// REST API に CRUD + 検索を一通り投げるクライアント（gleam_httpc + gleam_http）。

import envoy
import gleam/dynamic/decode
import gleam/http.{type Method, Delete, Get, Post, Put}
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri

pub type User {
  User(id: Int, name: String, email: String, age: Int)
}

pub type UserInput {
  UserInput(name: String, email: String, age: Int)
}

/// レスポンスの JSON を User 型にするデコーダー。
fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(User(id:, name:, email:, age:))
}

/// リクエストボディ（UserInput → JSON）。
fn input_to_json(input: UserInput) -> json.Json {
  json.object([
    #("name", json.string(input.name)),
    #("email", json.string(input.email)),
    #("age", json.int(input.age)),
  ])
}

/// 接続先は API_URL（未指定なら gleam-wisp サーバー）。
fn base_url() -> String {
  envoy.get("API_URL") |> result.unwrap("http://127.0.0.1:8013")
}

/// リクエストを 1 本送り、送った内容と返ってきた内容を表示する。
fn call(
  method: Method,
  path: String,
  body: Option(UserInput),
) -> Response(String) {
  let assert Ok(req) = request.to(base_url() <> path)
  let req = request.set_method(req, method)
  let line = "> " <> http.method_to_string(method) <> " " <> path

  let req = case body {
    Some(input) -> {
      let body = input |> input_to_json |> json.to_string
      io.println(line <> " " <> body)
      req
      |> request.set_header("content-type", "application/json")
      |> request.set_body(body)
    }
    None -> {
      io.println(line)
      req
    }
  }

  let assert Ok(res) = httpc.send(req) as "リクエスト失敗（サーバーは起動していますか？）"
  io.println("< " <> int.to_string(res.status) <> " " <> res.body <> "\n")
  res
}

pub fn main() -> Nil {
  io.println("--- 1. 一覧取得")
  call(Get, "/users", None)

  io.println("--- 2. 作成")
  let res =
    call(Post, "/users", Some(UserInput("Carol", "carol@example.com", 35)))
  let assert Ok(created) = json.parse(res.body, user_decoder())
  let user_path = "/users/" <> int.to_string(created.id)

  io.println("--- 3. 1件取得")
  call(Get, user_path, None)

  io.println("--- 4. 更新")
  call(Put, user_path, Some(UserInput("Carol Smith", "carol@example.com", 36)))

  io.println("--- 5. 検索（名前の部分一致）")
  call(Get, "/users?" <> uri.query_to_string([#("name", "car")]), None)

  io.println("--- 6. 検索（年齢の下限）")
  call(Get, "/users?" <> uri.query_to_string([#("min_age", "30")]), None)

  io.println("--- 7. 削除")
  call(Delete, user_path, None)

  io.println("--- 8. 削除されたことを確認（404 になる）")
  call(Get, user_path, None)

  Nil
}
