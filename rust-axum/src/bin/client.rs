//! REST API に CRUD + 検索を一通り投げるクライアント（reqwest の blocking API）。

use std::{env, process};

use reqwest::blocking::{Client, RequestBuilder};
use serde::{Deserialize, Serialize};

/// サーバーが返すユーザー。レスポンスの JSON をこの型にデコードする。
#[derive(Deserialize)]
#[expect(dead_code, reason = "このクライアントでは id しか使わない")]
struct User {
    id: u64,
    name: String,
    email: String,
    age: u32,
}

/// POST / PUT で送るボディ。`.json(&input)` でこの型が JSON になる。
#[derive(Serialize)]
struct UserInput<'a> {
    name: &'a str,
    email: &'a str,
    age: u32,
}

/// リクエストを 1 本送り、送った内容と返ってきた内容を表示してボディを返す。
fn call(builder: RequestBuilder) -> String {
    let (client, request) = builder.build_split();
    let request = request.expect("リクエストを組み立てられません");

    // 表示用にメソッド・パス（+ クエリ）・JSON ボディを取り出す
    let method = request.method();
    let url = request.url();
    let target = match url.query() {
        Some(query) => format!("{}?{query}", url.path()),
        None => url.path().to_owned(),
    };
    match request.body().and_then(|body| body.as_bytes()) {
        Some(json) => println!("> {method} {target} {}", String::from_utf8_lossy(json)),
        None => println!("> {method} {target}"),
    }

    let response = client.execute(request).unwrap_or_else(|err| {
        eprintln!("リクエスト失敗（サーバーは起動していますか？）: {err}");
        process::exit(1);
    });
    let status = response.status().as_u16();
    let body = response.text().expect("レスポンスを読めません");
    println!("< {status} {body}\n");
    body
}

fn main() {
    let base_url = env::var("API_URL").unwrap_or_else(|_| "http://127.0.0.1:8004".into());
    let url = |path: &str| format!("{base_url}{path}");
    let client = Client::new();

    println!("--- 1. 一覧取得");
    call(client.get(url("/users")));

    println!("--- 2. 作成");
    let carol = UserInput {
        name: "Carol",
        email: "carol@example.com",
        age: 35,
    };
    let body = call(client.post(url("/users")).json(&carol));
    let created: User = serde_json::from_str(&body).expect("作成したユーザーを読めません");
    let user_url = url(&format!("/users/{}", created.id));

    println!("--- 3. 1件取得");
    call(client.get(&user_url));

    println!("--- 4. 更新");
    let carol_smith = UserInput {
        name: "Carol Smith",
        email: "carol@example.com",
        age: 36,
    };
    call(client.put(&user_url).json(&carol_smith));

    // .query() がクエリ文字列を組み立てる（URL エンコードも行う）
    println!("--- 5. 検索（名前の部分一致）");
    call(client.get(url("/users")).query(&[("name", "car")]));

    println!("--- 6. 検索（年齢の下限）");
    call(client.get(url("/users")).query(&[("min_age", 30)]));

    println!("--- 7. 削除");
    call(client.delete(&user_url));

    println!("--- 8. 削除されたことを確認（404 になる）");
    call(client.get(&user_url));
}
