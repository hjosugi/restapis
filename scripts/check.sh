#!/usr/bin/env bash
# API 仕様（README.md）どおりに動くかを curl + jq で確認する。
#   使い方: scripts/check.sh http://127.0.0.1:8003
# 自分で作ったユーザーだけを操作するので、何度実行しても OK。
set -uo pipefail

BASE=${1:-${API_URL:-http://127.0.0.1:8003}}
pass=0
fail=0
STATUS=""
BODY=""
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# req METHOD PATH [JSON_BODY] -> STATUS / BODY / CTYPE をセット
req() {
  local method=$1 path=$2 data=${3:-} out
  local args=(-s -o "$TMP" -w '%{http_code} %{content_type}' -X "$method" "$BASE$path")
  [[ -n $data ]] && args+=(-H 'Content-Type: application/json' --data-raw "$data")
  out=$(curl "${args[@]}") || {
    echo "接続できません: $BASE （サーバーを起動しましたか？）"
    exit 2
  }
  STATUS=${out%% *}
  CTYPE=${out#* }
  BODY=$(cat "$TMP")
}

ok() { echo "  ok   $1"; pass=$((pass + 1)); }
ng() { echo "  FAIL $1 (status=$STATUS body=$BODY)"; fail=$((fail + 1)); }
expect_status() { [[ $STATUS == "$1" ]] && ok "$2" || ng "$2 -> 期待 $1"; }
expect_jq() { jq -e "$1" >/dev/null 2>&1 <<<"$BODY" && ok "$2" || ng "$2 -> jq '$1'"; }
expect_json() { [[ $CTYPE == application/json* ]] && ok "$1: Content-Type が JSON" || ng "$1: Content-Type=$CTYPE"; }

echo "== $BASE"

req GET /users
expect_status 200 "GET /users"
expect_json "GET /users"
expect_jq 'type == "array"' "GET /users は配列"
expect_jq '[.[].id] == ([.[].id] | sort)' "GET /users は id 昇順"

tag="Zz$RANDOM$RANDOM"
req POST /users "{\"name\":\"Check $tag\",\"email\":\"$tag@example.com\",\"age\":41}"
expect_status 201 "POST /users"
expect_json "POST /users"
expect_jq ".id > 0 and .name == \"Check $tag\" and .email == \"$tag@example.com\" and .age == 41" "POST の結果"
id=$(jq -r '.id' <<<"$BODY" 2>/dev/null)

req GET "/users/$id"
expect_status 200 "GET /users/{id}"
expect_jq ".id == $id and .name == \"Check $tag\"" "GET /users/{id} の結果"

req PUT "/users/$id" "{\"name\":\"Updated $tag\",\"email\":\"u$tag@example.com\",\"age\":42}"
expect_status 200 "PUT /users/{id}"
expect_jq ".id == $id and .name == \"Updated $tag\" and .email == \"u$tag@example.com\" and .age == 42" "PUT の結果"

lower=$(tr '[:upper:]' '[:lower:]' <<<"$tag")
req GET "/users?name=$lower"
expect_status 200 "GET /users?name= (大文字小文字無視の部分一致)"
expect_jq "length == 1 and .[0].id == $id" "name 検索で 1 件ヒット"

req GET "/users?name=$lower&min_age=43"
expect_jq 'length == 0' "name + min_age は AND 条件"

req GET "/users?min_age=42"
expect_status 200 "GET /users?min_age=42"
expect_jq "all(.[]; .age >= 42) and any(.[]; .id == $id)" "min_age 検索"

req GET "/users?min_age=abc"
expect_status 400 "min_age が整数でない -> 400"
expect_jq 'has("error")' "エラーは {\"error\": ...}"

req POST /users '{"name":'
expect_status 400 "壊れた JSON -> 400"
req POST /users '{"email":"x@example.com","age":1}'
expect_status 400 "name なし -> 400"
req POST /users '{"name":"","email":"x@example.com","age":1}'
expect_status 400 "name が空 -> 400"
req POST /users '{"name":"x","email":"x@example.com","age":-1}'
expect_status 400 "age が負 -> 400"
req POST /users '{"name":"x","email":"x@example.com","age":"1"}'
expect_status 400 "age が文字列 -> 400"
expect_jq 'has("error")' "400 のボディは {\"error\": ...}"

req PUT /users/999999 '{"name":"x","email":"x@example.com","age":1}'
expect_status 404 "存在しない id を PUT -> 404"

req DELETE "/users/$id"
expect_status 204 "DELETE /users/{id}"
req DELETE "/users/$id"
expect_status 404 "削除済みを DELETE -> 404"
req GET "/users/$id"
expect_status 404 "削除済みを GET -> 404"
expect_json "404"
expect_jq 'has("error")' "404 のボディは {\"error\": ...}"

echo "== pass=$pass fail=$fail"
[[ $fail == 0 ]]
