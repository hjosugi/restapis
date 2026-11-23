// REST API に CRUD + 検索を一通り投げるクライアント（cpr + nlohmann/json）。
#include <cpr/cpr.h>
#include <nlohmann/json.hpp>

#include <cstdio>
#include <cstdlib>
#include <optional>
#include <print>
#include <string>
#include <string_view>

namespace {

struct User {
    int id{};
    std::string name;
    std::string email;
    int age{};
};
// JSON <-> 構造体の変換（to_json / from_json）をマクロで生成する
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(User, id, name, email, age)

struct UserInput {
    std::string name;
    std::string email;
    int age{};
};
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(UserInput, name, email, age)

// Request は送るリクエスト 1 本分。
struct Request {
    std::string_view method;
    std::string path;
    cpr::Parameters query{};         // クエリ文字列（cpr が URL エンコードして付ける）
    std::optional<UserInput> body{}; // JSON で送るボディ
};

std::string baseUrl() {
    const char *env = std::getenv("API_URL");
    return env != nullptr && *env != '\0' ? env : "http://127.0.0.1:8002";
}

// call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。
cpr::Response call(const Request &req) {
    const auto base = baseUrl();
    cpr::Session session;
    session.SetUrl(cpr::Url{base + req.path});
    session.SetParameters(req.query);
    const auto target = session.GetFullRequestUrl().substr(base.size()); // 例: /users?name=car

    if (req.body) {
        // ordered_json はキーを定義順（name, email, age）のまま出力する
        const auto json = nlohmann::ordered_json(*req.body).dump();
        std::println("> {} {} {}", req.method, target, json);
        session.SetHeader(cpr::Header{{"Content-Type", "application/json"}});
        session.SetBody(cpr::Body{json});
    } else {
        std::println("> {} {}", req.method, target);
    }

    cpr::Response res;
    if (req.method == "POST") {
        res = session.Post();
    } else if (req.method == "PUT") {
        res = session.Put();
    } else if (req.method == "DELETE") {
        res = session.Delete();
    } else {
        res = session.Get();
    }
    if (res.error) {
        std::println(
            stderr, "リクエスト失敗（サーバーは起動していますか？）: {}", res.error.message);
        std::exit(1);
    }
    std::println("< {} {}\n", res.status_code, res.text);
    return res;
}

} // namespace

int main() {
    std::println("--- 1. 一覧取得");
    call({.method = "GET", .path = "/users"});

    std::println("--- 2. 作成");
    const UserInput carol{.name = "Carol", .email = "carol@example.com", .age = 35};
    const auto res = call({.method = "POST", .path = "/users", .body = carol});
    // レスポンスの JSON を User 構造体にデコードして id を取り出す
    const auto created = nlohmann::json::parse(res.text).get<User>();
    const auto userPath = "/users/" + std::to_string(created.id);

    std::println("--- 3. 1件取得");
    call({.method = "GET", .path = userPath});

    std::println("--- 4. 更新");
    const UserInput carolSmith{.name = "Carol Smith", .email = "carol@example.com", .age = 36};
    call({.method = "PUT", .path = userPath, .body = carolSmith});

    std::println("--- 5. 検索（名前の部分一致）");
    call({.method = "GET", .path = "/users", .query = {{"name", "car"}}});

    std::println("--- 6. 検索（年齢の下限）");
    call({.method = "GET", .path = "/users", .query = {{"min_age", "30"}}});

    std::println("--- 7. 削除");
    call({.method = "DELETE", .path = userPath});

    std::println("--- 8. 削除されたことを確認（404 になる）");
    call({.method = "GET", .path = userPath});
}
