// users リソースの CRUD を提供する REST API サーバー（Elysia on Bun / インメモリ保存）。
import { Elysia, t } from "elysia";

// POST / PUT のリクエストボディ。t（TypeBox）のスキーマで入力チェックし、型もここから作る。
// error はチェックに落ちたときのメッセージ。
const UserInput = t.Object({
  name: t.String({ minLength: 1, error: "name must be a non-empty string" }),
  email: t.String({ minLength: 1, error: "email must be a non-empty string" }),
  // t.Integer は文字列 "1" も数値に変換して通すので、t.Number + multipleOf: 1 で整数に限る
  age: t.Number({ minimum: 0, multipleOf: 1, error: "age must be an integer >= 0" }),
});
type UserInput = typeof UserInput.static;

// User は API で扱うリソース。
type User = { id: number } & UserInput;

// GET /users のクエリ。クエリ文字列の min_age は t.Integer で整数に変換・チェックされる。
const SearchQuery = t.Object({
  name: t.Optional(t.String()),
  min_age: t.Optional(t.Integer({ error: "min_age must be an integer" })),
});

// メモリ上のユーザー一覧。Bun は 1 スレッドのイベントループで処理するのでロックは不要。
// Map は挿入順を保つ（id は増える一方）ので、values() はそのまま id 昇順。
const users = new Map<number, User>();
let nextId = 1;

function createUser(input: UserInput): User {
  const user = { id: nextId++, ...input };
  users.set(user.id, user);
  return user;
}

createUser({ name: "Alice", email: "alice@example.com", age: 30 });
createUser({ name: "Bob", email: "bob@example.com", age: 25 });

const notFound = { error: "user not found" };

const app = new Elysia()
  // Elysia 既定のエラー（チェック失敗の 422、壊れた JSON、存在しないルート）を {"error": ...} に揃える
  .onError(({ code, error, status }) => {
    switch (code) {
      case "VALIDATION":
        return status(400, { error: error.customError ?? error.all[0]?.summary });
      case "PARSE":
        return status(400, { error: "invalid JSON body" });
      case "NOT_FOUND":
        return status(404, { error: "not found" });
    }
  })

  // GET /users?name=al&min_age=20（両方指定したら AND）
  .get(
    "/users",
    ({ query: { name, min_age } }) =>
      [...users.values()].filter(
        (u) =>
          (name === undefined || u.name.toLowerCase().includes(name.toLowerCase())) &&
          (min_age === undefined || u.age >= min_age),
      ),
    { query: SearchQuery },
  )

  // パスの :id は文字列。Number() で変換し、数値でなければ NaN → 見つからない（404）。
  // （params: t.Object({ id: t.Integer() }) は Elysia 1.4.32 + Bun 1.4 だと 500 になるため使わない）
  // オブジェクトを返すと JSON になり、status() でステータスコードを指定できる。
  .get("/users/:id", ({ params: { id }, status }) => users.get(Number(id)) ?? status(404, notFound))

  .post("/users", ({ body, status }) => status(201, createUser(body)), { body: UserInput })

  .put(
    "/users/:id",
    ({ params, body, status }) => {
      const id = Number(params.id);
      if (!users.has(id)) return status(404, notFound);
      const user = { id, ...body };
      users.set(id, user);
      return user;
    },
    { body: UserInput },
  )

  // 204 はボディなし
  .delete("/users/:id", ({ params: { id }, status }) =>
    users.delete(Number(id)) ? status(204) : status(404, notFound),
  )

  .listen({ hostname: "127.0.0.1", port: Number(Bun.env.PORT ?? 8006) });

console.log(`listening on ${app.server?.url}`);
