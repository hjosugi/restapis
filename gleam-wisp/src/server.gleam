//// users リソースの CRUD を提供する REST API サーバー（Wisp + Mist / インメモリ保存）。

import envoy
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http.{Delete, Get, Post, Put}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

/// API で扱うリソース。
pub type User {
  User(id: Int, name: String, email: String, age: Int)
}

/// POST / PUT のリクエストボディ。
pub type UserInput {
  UserInput(name: String, email: String, age: Int)
}

/// User → JSON（キーはこのリストの順で出力される）。
fn user_to_json(user: User) -> json.Json {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
    #("age", json.int(user.age)),
  ])
}

/// 入力の JSON デコーダー。項目が欠けている・型が違う（age が "1" など）とエラー。
fn input_decoder() -> decode.Decoder(UserInput) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use age <- decode.field("age", decode.int)
  decode.success(UserInput(name:, email:, age:))
}

/// 型は合っているが値がおかしい入力を弾く。
fn validate(input: UserInput) -> Result(UserInput, String) {
  case input {
    UserInput(name: "", ..) -> Error("name must not be empty")
    UserInput(email: "", ..) -> Error("email must not be empty")
    UserInput(age:, ..) if age < 0 -> Error("age must be >= 0")
    _ -> Ok(input)
  }
}

// ---------------------------------------------------------------------------
// ストア: 状態を持つ actor。メッセージを 1 つずつ順番に処理するので、
// 並行にリクエストが来てもロックは要らない。

type Store {
  Store(users: Dict(Int, User), next_id: Int)
}

/// actor が受け取るメッセージ。reply に結果を送り返す。
type Message {
  ListUsers(reply: Subject(List(User)))
  GetUser(id: Int, reply: Subject(Result(User, Nil)))
  CreateUser(input: UserInput, reply: Subject(User))
  UpdateUser(id: Int, input: UserInput, reply: Subject(Result(User, Nil)))
  DeleteUser(id: Int, reply: Subject(Result(Nil, Nil)))
}

/// 起動時のデータ（次の id は 3）。
fn initial_store() -> Store {
  Store(
    users: dict.from_list([
      #(1, User(1, "Alice", "alice@example.com", 30)),
      #(2, User(2, "Bob", "bob@example.com", 25)),
    ]),
    next_id: 3,
  )
}

fn handle_message(
  store: Store,
  message: Message,
) -> actor.Next(Store, Message) {
  case message {
    ListUsers(client) ->
      dict.values(store.users)
      |> list.sort(fn(a, b) { int.compare(a.id, b.id) })
      |> reply(store, client, _)

    GetUser(id, client) -> reply(store, client, dict.get(store.users, id))

    CreateUser(input, client) -> {
      let user = User(store.next_id, input.name, input.email, input.age)
      Store(
        users: dict.insert(store.users, user.id, user),
        next_id: user.id + 1,
      )
      |> reply(client, user)
    }

    UpdateUser(id, input, client) ->
      case dict.has_key(store.users, id) {
        True -> {
          let user = User(id, input.name, input.email, input.age)
          Store(..store, users: dict.insert(store.users, id, user))
          |> reply(client, Ok(user))
        }
        False -> reply(store, client, Error(Nil))
      }

    DeleteUser(id, client) ->
      case dict.has_key(store.users, id) {
        True ->
          Store(..store, users: dict.delete(store.users, id))
          |> reply(client, Ok(Nil))
        False -> reply(store, client, Error(Nil))
      }
  }
}

/// 結果を送り返して、新しい状態で次のメッセージを待つ。
fn reply(store: Store, client: Subject(a), value: a) -> actor.Next(Store, b) {
  process.send(client, value)
  actor.continue(store)
}

/// actor.call の待ち時間（ミリ秒）
const timeout = 1000

// ---------------------------------------------------------------------------
// HTTP ハンドラー

fn handle_request(req: Request, store: Subject(Message)) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes

  // ルート定義: パスの区切りと HTTP メソッドでパターンマッチする
  case wisp.path_segments(req), req.method {
    ["users"], Get -> list_users(req, store)
    ["users"], Post -> create_user(req, store)
    ["users", id], Get -> get_user(id, store)
    ["users", id], Put -> update_user(req, id, store)
    ["users", id], Delete -> delete_user(id, store)
    _, _ -> error_response(404, "not found")
  }
}

// GET /users?name=al&min_age=20
fn list_users(req: Request, store: Subject(Message)) -> Response {
  // クエリパラメータは #(キー, 値) のリスト
  let query = wisp.get_query(req)
  let name = list.key_find(query, "name") |> result.unwrap("")
  let min_age = case list.key_find(query, "min_age") {
    Error(Nil) | Ok("") -> Ok(None)
    Ok(value) -> int.parse(value) |> result.map(Some)
  }

  case min_age {
    Error(Nil) -> error_response(400, "min_age must be an integer")
    Ok(min_age) ->
      actor.call(store, waiting: timeout, sending: ListUsers)
      |> list.filter(matches(_, name, min_age))
      |> json.array(user_to_json)
      |> json.to_string
      |> wisp.json_response(200)
  }
}

/// name は大文字小文字を無視した部分一致、min_age は age >= min_age（両方なら AND）。
fn matches(user: User, name: String, min_age: Option(Int)) -> Bool {
  let name_ok =
    string.contains(string.lowercase(user.name), string.lowercase(name))
  case min_age {
    Some(min_age) -> name_ok && user.age >= min_age
    None -> name_ok
  }
}

fn get_user(id: String, store: Subject(Message)) -> Response {
  use id <- require_id(id)
  case actor.call(store, waiting: timeout, sending: GetUser(id, _)) {
    Ok(user) ->
      user |> user_to_json |> json.to_string |> wisp.json_response(200)
    Error(Nil) -> not_found()
  }
}

fn create_user(req: Request, store: Subject(Message)) -> Response {
  use input <- require_input(req)
  actor.call(store, waiting: timeout, sending: CreateUser(input, _))
  |> user_to_json
  |> json.to_string
  |> wisp.json_response(201)
}

fn update_user(req: Request, id: String, store: Subject(Message)) -> Response {
  use id <- require_id(id)
  use input <- require_input(req)
  case actor.call(store, waiting: timeout, sending: UpdateUser(id, input, _)) {
    Ok(user) ->
      user |> user_to_json |> json.to_string |> wisp.json_response(200)
    Error(Nil) -> not_found()
  }
}

fn delete_user(id: String, store: Subject(Message)) -> Response {
  use id <- require_id(id)
  case actor.call(store, waiting: timeout, sending: DeleteUser(id, _)) {
    Ok(Nil) -> wisp.no_content()
    Error(Nil) -> not_found()
  }
}

/// /users/{id} の id を整数にする。数値でなければ「見つからない」扱い。
fn require_id(id: String, next: fn(Int) -> Response) -> Response {
  case int.parse(id) {
    Ok(id) -> next(id)
    Error(Nil) -> not_found()
  }
}

/// ボディを JSON として読み、型（decoder）と値（validate）をチェックする。失敗したら 400。
/// （wisp.require_json は Content-Type 必須で、エラーも text/plain なので使わない）
fn require_input(req: Request, next: fn(UserInput) -> Response) -> Response {
  use body <- wisp.require_bit_array_body(req)
  let input =
    json.parse_bits(body, input_decoder())
    |> result.map_error(json_error_message)
    |> result.try(validate)
  case input {
    Ok(input) -> next(input)
    Error(message) -> error_response(400, message)
  }
}

/// JSON の構文エラー / デコードエラーを {"error": ...} 用のメッセージにする。
fn json_error_message(error: json.DecodeError) -> String {
  case error {
    json.UnableToDecode([decode.DecodeError(expected:, found:, path:), ..]) ->
      string.join(path, ".") <> ": expected " <> expected <> ", found " <> found
    _ -> "invalid JSON"
  }
}

/// エラーは {"error": "..."}（Content-Type: application/json）で返す。
fn error_response(status: Int, message: String) -> Response {
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

fn not_found() -> Response {
  error_response(404, "user not found")
}

pub fn main() -> Nil {
  wisp.configure_logger()
  let port = envoy.get("PORT") |> result.try(int.parse) |> result.unwrap(8013)

  // ストアの actor を起動し、その Subject（宛先）をハンドラーに渡す
  let assert Ok(store) =
    actor.new(initial_store())
    |> actor.on_message(handle_message)
    |> actor.start

  let assert Ok(_) =
    wisp_mist.handler(handle_request(_, store.data), wisp.random_string(64))
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start

  process.sleep_forever()
}
