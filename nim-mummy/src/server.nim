## users リソースの CRUD を提供する REST API サーバー（Mummy / インメモリ保存）。
import std/[algorithm, json, locks, options, os, strutils, tables]
import mummy, mummy/routers

type
  User = object ## API で扱うリソース
    id: int
    name: string
    email: string
    age: int

  UserInput = object ## POST / PUT のリクエストボディ
    name: string
    email: string
    age: int

# ストア。Mummy はハンドラーを複数のワーカースレッドで並行に呼ぶので Lock で守る。
# {.guard.} を付けると、ロックを取らずに触るコードはコンパイルエラーになる。
var
  lock: Lock
  users {.guard: lock.}: Table[int, User]
  nextId {.guard: lock.}: int = 1

template withStore(body: untyped) =
  ## ロックを取って共有データを触る。ハンドラーは gcsafe（GC 管理のグローバル変数に触れない）
  ## 必要があるが、ロックで排他しているので cast(gcsafe) で許可する
  withLock lock:
    {.cast(gcsafe).}:
      body

proc listUsers(name: string, minAge: int): seq[User] =
  withStore:
    for user in users.values:
      if name.toLowerAscii in user.name.toLowerAscii and user.age >= minAge:
        result.add user
  result = result.sortedByIt(it.id) # id 昇順

proc findUser(id: int): Option[User] =
  withStore:
    if id in users:
      result = some(users[id])

proc createUser(input: UserInput): User =
  withStore:
    result = User(id: nextId, name: input.name, email: input.email, age: input.age)
    users[result.id] = result
    inc nextId

proc updateUser(id: int, input: UserInput): Option[User] =
  withStore:
    if id in users:
      users[id] = User(id: id, name: input.name, email: input.email, age: input.age)
      result = some(users[id])

proc deleteUser(id: int): bool =
  withStore:
    result = id in users
    users.del(id)

# --- レスポンスと入力チェックのヘルパー

proc respondJson(request: Request, status: int, body: JsonNode) =
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  request.respond(status, headers, $body)

proc respondError(request: Request, status: int, message: string) =
  request.respondJson(status, %*{"error": message})

proc parseInput(body: string): UserInput =
  ## JSON ボディを UserInput に変換して検証する。不正なら ValueError
  try:
    # 壊れた JSON → JsonParsingError、型違い（"age": "1" など）→ JsonKindError
    result = parseJson(body).to(UserInput)
  except KeyError as e: # 項目が欠けている
    raise newException(ValueError, e.msg)
  if result.name == "" or result.email == "":
    raise newException(ValueError, "name and email must not be empty")
  if result.age < 0:
    raise newException(ValueError, "age must be >= 0")

proc pathId(request: Request): int =
  ## /users/@id の id。数値でなければ存在しない id (0) として 404 にする
  try:
    parseInt(request.pathParams["id"])
  except ValueError:
    0

# --- ハンドラー

proc listUsersHandler(request: Request) =
  # GET /users?name=al&min_age=20（指定がなければ絞り込まない）
  var minAge = int.low
  let minAgeParam = request.queryParams["min_age"]
  if minAgeParam != "":
    try:
      minAge = parseInt(minAgeParam)
    except ValueError:
      request.respondError(400, "min_age must be an integer")
      return
  request.respondJson(200, %listUsers(request.queryParams["name"], minAge))

proc getUserHandler(request: Request) =
  let user = findUser(request.pathId)
  if user.isNone:
    request.respondError(404, "user not found")
    return
  request.respondJson(200, %user.get)

proc createUserHandler(request: Request) =
  let input =
    try:
      parseInput(request.body)
    except ValueError as e:
      request.respondError(400, e.msg)
      return
  request.respondJson(201, %createUser(input))

proc updateUserHandler(request: Request) =
  let input =
    try:
      parseInput(request.body)
    except ValueError as e:
      request.respondError(400, e.msg)
      return
  let user = updateUser(request.pathId, input)
  if user.isNone:
    request.respondError(404, "user not found")
    return
  request.respondJson(200, %user.get)

proc deleteUserHandler(request: Request) =
  if not deleteUser(request.pathId):
    request.respondError(404, "user not found")
    return
  request.respond(204)

# ルートが無い / メソッドが違うときも、Mummy 既定の HTML ではなく JSON で返す
proc notFoundHandler(request: Request) =
  request.respondError(404, "not found")

proc methodNotAllowedHandler(request: Request) =
  request.respondError(405, "method not allowed")

when isMainModule:
  initLock(lock)
  discard createUser(UserInput(name: "Alice", email: "alice@example.com", age: 30))
  discard createUser(UserInput(name: "Bob", email: "bob@example.com", age: 25))

  # ルート定義。@id は名前付きパスパラメーター（request.pathParams["id"]）
  var router: Router
  router.get("/users", listUsersHandler)
  router.get("/users/@id", getUserHandler)
  router.post("/users", createUserHandler)
  router.put("/users/@id", updateUserHandler)
  router.delete("/users/@id", deleteUserHandler)
  router.notFoundHandler = notFoundHandler
  router.methodNotAllowedHandler = methodNotAllowedHandler

  let port = parseInt(getEnv("PORT", "8016"))
  let server = newServer(router)
  echo "Serving on http://127.0.0.1:", port
  server.serve(Port(port), "127.0.0.1")
