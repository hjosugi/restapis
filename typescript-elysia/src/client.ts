// REST API に CRUD + 検索を一通り投げるクライアント（標準の fetch のみ）。

type User = {
  id: number;
  name: string;
  email: string;
  age: number;
};

type UserInput = Omit<User, "id">;

const baseURL = Bun.env.API_URL ?? "http://127.0.0.1:8006";

// call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。ボディは文字列で返す。
async function call(method: string, path: string, body?: UserInput): Promise<string> {
  const json = body === undefined ? undefined : JSON.stringify(body);
  console.log(json === undefined ? `> ${method} ${path}` : `> ${method} ${path} ${json}`);

  let res: Response;
  try {
    res = await fetch(baseURL + path, {
      method,
      headers: json === undefined ? {} : { "Content-Type": "application/json" },
      body: json,
    });
  } catch (err) {
    console.error("リクエスト失敗（サーバーは起動していますか？）:", err);
    process.exit(1);
  }
  const text = await res.text();
  console.log(`< ${res.status} ${text}\n`);
  return text;
}

console.log("--- 1. 一覧取得");
await call("GET", "/users");

console.log("--- 2. 作成");
// JSON.parse の結果を User 型として扱う（実行時のチェックはしない）
const created = JSON.parse(
  await call("POST", "/users", { name: "Carol", email: "carol@example.com", age: 35 }),
) as User;
const userPath = `/users/${created.id}`;

console.log("--- 3. 1件取得");
await call("GET", userPath);

console.log("--- 4. 更新");
await call("PUT", userPath, { name: "Carol Smith", email: "carol@example.com", age: 36 });

console.log("--- 5. 検索（名前の部分一致）");
await call("GET", `/users?${new URLSearchParams({ name: "car" })}`);

console.log("--- 6. 検索（年齢の下限）");
await call("GET", `/users?${new URLSearchParams({ min_age: "30" })}`);

console.log("--- 7. 削除");
await call("DELETE", userPath);

console.log("--- 8. 削除されたことを確認（404 になる）");
await call("GET", userPath);
