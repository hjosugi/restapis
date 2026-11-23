## REST API に CRUD + 検索を一通り投げるクライアント（標準ライブラリ std/httpclient のみ）。
import std/[httpclient, json, os, uri]

type
  User = object
    id: int
    name: string
    email: string
    age: int

  UserInput = object
    name: string
    email: string
    age: int

let
  baseUrl = getEnv("API_URL", "http://127.0.0.1:8016")
  client = newHttpClient()

proc call(
    httpMethod: HttpMethod, path: string, body: JsonNode = nil
): string {.discardable.} =
  ## リクエストを 1 本送り、送った内容と返ってきた内容を表示して、レスポンスのボディを返す
  var
    payload = ""
    headers = newHttpHeaders()
  if body.isNil:
    echo "> ", httpMethod, " ", path
  else:
    payload = $body
    headers["Content-Type"] = "application/json"
    echo "> ", httpMethod, " ", path, " ", payload

  let res =
    try:
      client.request(baseUrl & path, httpMethod, payload, headers)
    except OSError as e:
      stderr.writeLine "リクエスト失敗（サーバーは起動していますか？）"
      quit e.msg # stderr に出して終了コード 1
  echo "< ", res.code.int, " ", res.body, "\n"
  res.body

echo "--- 1. 一覧取得"
call(HttpGet, "/users")

echo "--- 2. 作成"
let carol = UserInput(name: "Carol", email: "carol@example.com", age: 35)
# レスポンスの JSON を User 型にデコードして、作成された id を取り出す
let created = call(HttpPost, "/users", %carol).parseJson.to(User)
let userPath = "/users/" & $created.id

echo "--- 3. 1件取得"
call(HttpGet, userPath)

echo "--- 4. 更新"
let carolSmith = UserInput(name: "Carol Smith", email: "carol@example.com", age: 36)
call(HttpPut, userPath, %carolSmith)

echo "--- 5. 検索（名前の部分一致）"
call(HttpGet, "/users?" & encodeQuery({"name": "car"}))

echo "--- 6. 検索（年齢の下限）"
call(HttpGet, "/users?" & encodeQuery({"min_age": "30"}))

echo "--- 7. 削除"
call(HttpDelete, userPath)

echo "--- 8. 削除されたことを確認（404 になる）"
call(HttpGet, userPath)

client.close()
