// users リソースの CRUD を提供する REST API サーバー（Drogon / インメモリ保存）。
#include <drogon/drogon.h>

#include <algorithm>
#include <cctype>
#include <charconv>
#include <cstdlib>
#include <expected>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <ranges>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

using namespace drogon;

namespace {

constexpr int defaultPort = 8002;

// User は API で扱うリソース。
struct User {
    int id{};
    std::string name;
    std::string email;
    int age{};

    [[nodiscard]] Json::Value toJson() const {
        Json::Value json;
        json["id"] = id;
        json["name"] = name;
        json["email"] = email;
        json["age"] = age;
        return json;
    }
};

// UserInput は POST / PUT のリクエストボディ。
struct UserInput {
    std::string name;
    std::string email;
    int age{};
};

std::string toLower(std::string_view s) {
    std::string out(s);
    std::ranges::transform(
        out, out.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return out;
}

// Store はメモリ上のユーザー一覧。Drogon は複数の IO スレッドでハンドラを呼ぶので mutex で守る。
class Store {
  public:
    Store() {
        create({.name = "Alice", .email = "alice@example.com", .age = 30});
        create({.name = "Bob", .email = "bob@example.com", .age = 25});
    }

    // list は name（部分一致・大文字小文字無視）と minAge で絞り込む。std::map なので id 昇順。
    std::vector<User> list(std::string_view name, std::optional<int> minAge) {
        const std::scoped_lock lock(mu_);
        const auto needle = toLower(name);
        return users_ | std::views::values | std::views::filter([&](const User &u) {
                   return toLower(u.name).contains(needle) && (!minAge || u.age >= *minAge);
               }) |
               std::ranges::to<std::vector>();
    }

    std::optional<User> get(int id) {
        const std::scoped_lock lock(mu_);
        if (const auto it = users_.find(id); it != users_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    User create(const UserInput &in) {
        const std::scoped_lock lock(mu_);
        const int id = nextId_++;
        return users_[id] = User{.id = id, .name = in.name, .email = in.email, .age = in.age};
    }

    // update は全置換。id が無ければ nullopt。
    std::optional<User> update(int id, const UserInput &in) {
        const std::scoped_lock lock(mu_);
        const auto it = users_.find(id);
        if (it == users_.end()) {
            return std::nullopt;
        }
        return it->second = User{.id = id, .name = in.name, .email = in.email, .age = in.age};
    }

    bool remove(int id) {
        const std::scoped_lock lock(mu_);
        return users_.erase(id) > 0;
    }

  private:
    std::mutex mu_;
    std::map<int, User> users_;
    int nextId_ = 1;
};

using Callback = std::function<void(const HttpResponsePtr &)>;

// newHttpJsonResponse は Content-Type: application/json のレスポンスを作る。
HttpResponsePtr jsonResponse(const Json::Value &body, HttpStatusCode code = k200OK) {
    auto resp = HttpResponse::newHttpJsonResponse(body);
    resp->setStatusCode(code);
    return resp;
}

HttpResponsePtr errorResponse(HttpStatusCode code, const std::string &message) {
    Json::Value body;
    body["error"] = message;
    return jsonResponse(body, code);
}

// parseInt は文字列全体が整数のときだけ値を返す（"" や "12abc" は nullopt）。
std::optional<int> parseInt(std::string_view s) {
    int value{};
    const auto *first = std::to_address(s.begin());
    const auto *last = std::to_address(s.end());
    auto [ptr, ec] = std::from_chars(first, last, value);
    if (ec != std::errc{} || ptr != last) {
        return std::nullopt;
    }
    return value;
}

// parseInput はボディの JSON を検証して UserInput にする。だめならエラーメッセージを返す。
std::expected<UserInput, std::string> parseInput(const HttpRequestPtr &req) {
    // ボディは Drogon が Json::Value にパース済み（壊れた JSON や Content-Type 違いなら nullptr）
    const auto &json = req->getJsonObject();
    if (!json) {
        return std::unexpected("invalid JSON: " + req->getJsonError());
    }
    // const 参照の operator[] は、無いキーなら null を返す（キーを追加しない）
    const Json::Value &body = *json;
    if (!body.isObject()) {
        return std::unexpected("request body must be a JSON object");
    }
    const auto &name = body["name"];
    const auto &email = body["email"];
    const auto &age = body["age"];
    if (!name.isString() || name.asString().empty()) {
        return std::unexpected("name must be a non-empty string");
    }
    if (!email.isString() || email.asString().empty()) {
        return std::unexpected("email must be a non-empty string");
    }
    if (!age.isInt() || age.asInt() < 0) { // 文字列 "1" は isInt() が false
        return std::unexpected("age must be an integer >= 0");
    }
    return UserInput{.name = name.asString(), .email = email.asString(), .age = age.asInt()};
}

} // namespace

int main() {
    Store store; // app().run() が戻るまで生きているので、ハンドラから参照でキャプチャしてよい

    // GET /users?name=al&min_age=20
    app().registerHandler(
        "/users",
        [&store](const HttpRequestPtr &req, Callback &&callback) {
            // getParameter はクエリの値（URL デコード済み、無ければ空文字列）
            const auto &minAgeText = req->getParameter("min_age");
            const auto minAge = parseInt(minAgeText); // 空なら nullopt（絞り込まない）
            if (!minAgeText.empty() && !minAge) {
                callback(errorResponse(k400BadRequest, "min_age must be an integer"));
                return;
            }
            Json::Value users(Json::arrayValue);
            for (const auto &user : store.list(req->getParameter("name"), minAge)) {
                users.append(user.toJson());
            }
            callback(jsonResponse(users));
        },
        {Get});

    // POST /users
    app().registerHandler(
        "/users",
        [&store](const HttpRequestPtr &req, Callback &&callback) {
            const auto input = parseInput(req);
            if (!input) {
                callback(errorResponse(k400BadRequest, input.error()));
                return;
            }
            callback(jsonResponse(store.create(*input).toJson(), k201Created));
        },
        {Post});

    // パス中の {id} はハンドラの引数で受け取る。int で受けると "abc" で 500 になるので
    // 文字列で受けて自分で変換し、数値でなければ 0（存在しない id）として 404 にする。
    // GET /users/{id}
    app().registerHandler(
        "/users/{id}",
        [&store](const HttpRequestPtr & /*req*/, Callback &&callback, const std::string &id) {
            const auto user = store.get(parseInt(id).value_or(0));
            if (!user) {
                callback(errorResponse(k404NotFound, "user not found"));
                return;
            }
            callback(jsonResponse(user->toJson()));
        },
        {Get});

    // PUT /users/{id}（全置換）
    app().registerHandler(
        "/users/{id}",
        [&store](const HttpRequestPtr &req, Callback &&callback, const std::string &id) {
            const auto input = parseInput(req);
            if (!input) {
                callback(errorResponse(k400BadRequest, input.error()));
                return;
            }
            const auto user = store.update(parseInt(id).value_or(0), *input);
            if (!user) {
                callback(errorResponse(k404NotFound, "user not found"));
                return;
            }
            callback(jsonResponse(user->toJson()));
        },
        {Put});

    // DELETE /users/{id}
    app().registerHandler(
        "/users/{id}",
        [&store](const HttpRequestPtr & /*req*/, Callback &&callback, const std::string &id) {
            if (!store.remove(parseInt(id).value_or(0))) {
                callback(errorResponse(k404NotFound, "user not found"));
                return;
            }
            const auto resp = HttpResponse::newHttpResponse();
            resp->setStatusCode(k204NoContent);
            callback(resp);
        },
        {Delete});

    // フレームワークが返すエラー（存在しないパス・許可されていないメソッド等）も JSON にする
    app().setCustomErrorHandler([](HttpStatusCode code, const HttpRequestPtr & /*req*/) {
        return errorResponse(code, std::string(statusCodeToString(code)));
    });

    // アクセスログ（レスポンスを返した後に呼ばれる）
    app().registerPostHandlingAdvice([](const HttpRequestPtr &req, const HttpResponsePtr &resp) {
        LOG_INFO << req->methodString() << ' ' << req->path() << " -> "
                 << static_cast<int>(resp->statusCode());
    });

    int port = defaultPort;
    if (const char *env = std::getenv("PORT"); env != nullptr) {
        port = parseInt(env).value_or(defaultPort);
    }
    LOG_INFO << "listening on http://127.0.0.1:" << port;
    // スレッド数 0 = CPU コア数ぶんの IO スレッド。Ctrl+C / SIGTERM で終了する
    app().addListener("127.0.0.1", static_cast<uint16_t>(port)).setThreadNum(0).run();
}
