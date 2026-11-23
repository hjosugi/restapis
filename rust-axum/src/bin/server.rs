//! users リソースの CRUD を提供する REST API サーバー（axum / インメモリ保存）。

use std::collections::BTreeMap;
use std::env;
use std::sync::{Arc, Mutex};

use axum::extract::rejection::{JsonRejection, PathRejection, QueryRejection};
use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use axum::{Json, Router};
use serde::{Deserialize, Serialize};
use serde_json::json;

/// API で扱うリソース。`Serialize` で JSON に変換される。
#[derive(Clone, Serialize)]
struct User {
    id: u64,
    name: String,
    email: String,
    age: u32,
}

/// POST / PUT のリクエストボディ。欠けた項目・型違い（age が文字列や負数）は serde が弾く。
#[derive(Deserialize)]
struct UserInput {
    name: String,
    email: String,
    age: u32,
}

impl UserInput {
    /// 型だけでは表せない入力チェック（空文字は不可）。
    fn validate(&self) -> Result<(), ApiError> {
        if self.name.is_empty() {
            return Err(ApiError::BadRequest("name must not be empty".into()));
        }
        if self.email.is_empty() {
            return Err(ApiError::BadRequest("email must not be empty".into()));
        }
        Ok(())
    }
}

/// GET /users のクエリパラメータ（どちらも省略可）。
#[derive(Deserialize)]
struct Search {
    name: Option<String>,
    min_age: Option<i64>,
}

/// メモリ上のユーザー一覧。`BTreeMap` なので `values()` が id 昇順になる。
struct Store {
    users: BTreeMap<u64, User>,
    next_id: u64,
}

impl Store {
    fn new() -> Self {
        let mut store = Self {
            users: BTreeMap::new(),
            next_id: 1,
        };
        store.insert(UserInput {
            name: "Alice".into(),
            email: "alice@example.com".into(),
            age: 30,
        });
        store.insert(UserInput {
            name: "Bob".into(),
            email: "bob@example.com".into(),
            age: 25,
        });
        store
    }

    fn insert(&mut self, input: UserInput) -> User {
        let user = User {
            id: self.next_id,
            name: input.name,
            email: input.email,
            age: input.age,
        };
        self.users.insert(user.id, user.clone());
        self.next_id += 1; // 削除しても id は再利用しない
        user
    }
}

/// axum はリクエストを並行処理するので、ストアを Mutex で守って全ハンドラーで共有する。
type AppState = Arc<Mutex<Store>>;

/// エラーレスポンス。どれも `{"error": "..."}` の JSON で返す。
enum ApiError {
    BadRequest(String),
    NotFound,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            Self::BadRequest(message) => (StatusCode::BAD_REQUEST, message),
            Self::NotFound => (StatusCode::NOT_FOUND, "user not found".into()),
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}

// 抽出器の失敗（壊れた JSON・型違い・min_age=abc・/users/abc）は axum の既定だと
// 422 やプレーンテキストになるので、`?` で ApiError（400 + JSON）に変換する。
impl From<JsonRejection> for ApiError {
    fn from(rejection: JsonRejection) -> Self {
        Self::BadRequest(rejection.body_text())
    }
}

impl From<QueryRejection> for ApiError {
    fn from(rejection: QueryRejection) -> Self {
        Self::BadRequest(rejection.body_text())
    }
}

impl From<PathRejection> for ApiError {
    fn from(rejection: PathRejection) -> Self {
        Self::BadRequest(rejection.body_text())
    }
}

// GET /users?name=al&min_age=20
async fn list_users(
    State(state): State<AppState>,
    query: Result<Query<Search>, QueryRejection>,
) -> Result<Json<Vec<User>>, ApiError> {
    let Query(search) = query?;
    let name = search.name.unwrap_or_default().to_lowercase();
    let store = state.lock().unwrap();
    let users = store
        .users
        .values()
        .filter(|u| u.name.to_lowercase().contains(&name))
        .filter(|u| search.min_age.is_none_or(|min| i64::from(u.age) >= min))
        .cloned()
        .collect();
    Ok(Json(users))
}

// GET /users/{id}
async fn get_user(
    State(state): State<AppState>,
    id: Result<Path<u64>, PathRejection>,
) -> Result<Json<User>, ApiError> {
    let Path(id) = id?;
    let store = state.lock().unwrap();
    let user = store.users.get(&id).ok_or(ApiError::NotFound)?;
    Ok(Json(user.clone()))
}

// POST /users -> 201
async fn create_user(
    State(state): State<AppState>,
    body: Result<Json<UserInput>, JsonRejection>,
) -> Result<(StatusCode, Json<User>), ApiError> {
    let Json(input) = body?;
    input.validate()?;
    let user = state.lock().unwrap().insert(input);
    Ok((StatusCode::CREATED, Json(user)))
}

// PUT /users/{id}（全置換）
async fn update_user(
    State(state): State<AppState>,
    id: Result<Path<u64>, PathRejection>,
    body: Result<Json<UserInput>, JsonRejection>,
) -> Result<Json<User>, ApiError> {
    let Path(id) = id?;
    let Json(input) = body?;
    input.validate()?;
    let mut store = state.lock().unwrap();
    let user = store.users.get_mut(&id).ok_or(ApiError::NotFound)?;
    *user = User {
        id,
        name: input.name,
        email: input.email,
        age: input.age,
    };
    Ok(Json(user.clone()))
}

// DELETE /users/{id} -> 204（ボディなし）
async fn delete_user(
    State(state): State<AppState>,
    id: Result<Path<u64>, PathRejection>,
) -> Result<StatusCode, ApiError> {
    let Path(id) = id?;
    let mut store = state.lock().unwrap();
    store.users.remove(&id).ok_or(ApiError::NotFound)?;
    Ok(StatusCode::NO_CONTENT)
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // ルート定義（axum 0.8 ではパスパラメータを {id} と書く）
    let app = Router::new()
        .route("/users", get(list_users).post(create_user))
        .route(
            "/users/{id}",
            get(get_user).put(update_user).delete(delete_user),
        )
        .with_state(Arc::new(Mutex::new(Store::new())));

    let port = env::var("PORT").unwrap_or_else(|_| "8004".into());
    let listener = tokio::net::TcpListener::bind(format!("127.0.0.1:{port}")).await?;
    println!("listening on http://{}", listener.local_addr()?);
    axum::serve(listener, app).await
}
