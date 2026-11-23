// users リソースの CRUD を提供する REST API サーバー（libmicrohttpd + cJSON / インメモリ保存）。
#include <arpa/inet.h>
#include <cjson/cJSON.h>
#include <errno.h>
#include <limits.h>
#include <microhttpd.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>

enum { DEFAULT_PORT = 8001, MAX_BODY_SIZE = 1024 * 1024 };

// User は API で扱うリソース。
typedef struct {
    int id;
    char *name;
    char *email;
    int age;
} User;

// UserInput は POST / PUT のリクエストボディ（文字列はパースした cJSON の中を指す）。
typedef struct {
    const char *name;
    const char *email;
    int age;
} UserInput;

// store はメモリ上のユーザー一覧（id 昇順の可変長配列）。
// MHD は接続ごとのスレッドからハンドラを並行に呼ぶので mutex で守る。
static struct {
    pthread_mutex_t mu;
    User *items;
    size_t len;
    size_t cap;
    int next_id;
} store = {.mu = PTHREAD_MUTEX_INITIALIZER, .next_id = 1};

// メモリ確保に失敗したら即終了する（サンプルなので簡単に）。
static void *xrealloc(void *ptr, size_t size) {
    void *p = realloc(ptr, size);
    if (p == nullptr) {
        perror("realloc");
        abort();
    }
    return p;
}

static char *xstrdup(const char *s) {
    char *p = strdup(s);
    if (p == nullptr) {
        perror("strdup");
        abort();
    }
    return p;
}

static cJSON *user_to_json(const User *u) {
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddNumberToObject(obj, "id", u->id);
    cJSON_AddStringToObject(obj, "name", u->name);
    cJSON_AddStringToObject(obj, "email", u->email);
    cJSON_AddNumberToObject(obj, "age", u->age);
    return obj;
}

// ---- ストア操作（store_* はロックを取り、結果を cJSON にして返す）----

// add_user は末尾に追加する。id は増える一方なので配列は常に id 昇順。ロックは呼び出し側で取る。
static User *add_user(const UserInput *in) {
    if (store.len == store.cap) {
        store.cap = store.cap == 0 ? 8 : store.cap * 2;
        store.items = xrealloc(store.items, store.cap * sizeof(User));
    }
    User *u = &store.items[store.len++];
    *u = (User){store.next_id++, xstrdup(in->name), xstrdup(in->email), in->age};
    return u;
}

// find_user は id のユーザーを返す（無ければ nullptr）。ロックは呼び出し側で取る。
static User *find_user(int id) {
    for (size_t i = 0; i < store.len; i++) {
        if (store.items[i].id == id) {
            return &store.items[i];
        }
    }
    return nullptr;
}

// store_list は name（部分一致・大文字小文字無視）と min_age で絞り込んだ配列を返す。
static cJSON *store_list(const char *name, int min_age) {
    cJSON *arr = cJSON_CreateArray();
    pthread_mutex_lock(&store.mu);
    for (size_t i = 0; i < store.len; i++) {
        const User *u = &store.items[i];
        if (name != nullptr && strcasestr(u->name, name) == nullptr) {
            continue;
        }
        if (u->age < min_age) {
            continue;
        }
        cJSON_AddItemToArray(arr, user_to_json(u));
    }
    pthread_mutex_unlock(&store.mu);
    return arr;
}

static cJSON *store_get(int id) {
    pthread_mutex_lock(&store.mu);
    const User *u = find_user(id);
    cJSON *json = u != nullptr ? user_to_json(u) : nullptr;
    pthread_mutex_unlock(&store.mu);
    return json;
}

static cJSON *store_create(const UserInput *in) {
    pthread_mutex_lock(&store.mu);
    cJSON *json = user_to_json(add_user(in));
    pthread_mutex_unlock(&store.mu);
    return json;
}

static cJSON *store_update(int id, const UserInput *in) {
    pthread_mutex_lock(&store.mu);
    User *u = find_user(id);
    cJSON *json = nullptr;
    if (u != nullptr) {
        free(u->name);
        free(u->email);
        *u = (User){id, xstrdup(in->name), xstrdup(in->email), in->age};
        json = user_to_json(u);
    }
    pthread_mutex_unlock(&store.mu);
    return json;
}

static bool store_delete(int id) {
    pthread_mutex_lock(&store.mu);
    User *u = find_user(id);
    if (u != nullptr) {
        free(u->name);
        free(u->email);
        // 後ろの要素を詰めて id 昇順を保つ
        size_t rest = store.len - (size_t)(u - store.items) - 1;
        memmove(u, u + 1, rest * sizeof(User));
        store.len--;
    }
    pthread_mutex_unlock(&store.mu);
    return u != nullptr;
}

// ---- HTTP ハンドラ ----

// Body は POST / PUT のボディを貯めるバッファ（リクエストごとに 1 つ、req_cls に入れておく）。
typedef struct {
    char *data;
    size_t len;
} Body;

// Reply はハンドラの結果。body が nullptr ならボディなし（204）。
typedef struct {
    unsigned int status;
    cJSON *body;
} Reply;

static Reply error_reply(unsigned int status, const char *message) {
    cJSON *body = cJSON_CreateObject();
    cJSON_AddStringToObject(body, "error", message);
    return (Reply){status, body};
}

// parse_int は文字列全体が整数のときだけ true を返す（"" や "12abc" は false）。
static bool parse_int(const char *s, int *out) {
    if (s == nullptr || *s == '\0') {
        return false;
    }
    char *end = nullptr;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno != 0 || *end != '\0' || v < INT_MIN || v > INT_MAX) {
        return false;
    }
    *out = (int)v;
    return true;
}

// parse_input はボディの JSON を検証して in に詰める。エラーならメッセージを返す。
// *root は成否にかかわらず呼び出し側で cJSON_Delete する（in の文字列は *root の中を指す）。
static const char *parse_input(const Body *body, cJSON **root, UserInput *in) {
    *root = cJSON_ParseWithLength(body->data, body->len);
    if (!cJSON_IsObject(*root)) {
        return "request body must be a JSON object";
    }
    const cJSON *name = cJSON_GetObjectItemCaseSensitive(*root, "name");
    const cJSON *email = cJSON_GetObjectItemCaseSensitive(*root, "email");
    const cJSON *age = cJSON_GetObjectItemCaseSensitive(*root, "age");
    if (!cJSON_IsString(name) || name->valuestring[0] == '\0') {
        return "name must be a non-empty string";
    }
    if (!cJSON_IsString(email) || email->valuestring[0] == '\0') {
        return "email must be a non-empty string";
    }
    // cJSON の数値は double なので 0 以上の整数かを自分で確かめる（文字列 "1" は IsNumber で弾く）
    if (!cJSON_IsNumber(age) || age->valuedouble < 0 || age->valuedouble > INT_MAX ||
        age->valuedouble != (int)age->valuedouble) {
        return "age must be an integer >= 0";
    }
    *in = (UserInput){name->valuestring, email->valuestring, (int)age->valuedouble};
    return nullptr;
}

// GET /users?name=al&min_age=20
static Reply list_users(struct MHD_Connection *conn) {
    // クエリパラメータは MHD が URL デコード済みの値を返す（無ければ nullptr）
    const char *name = MHD_lookup_connection_value(conn, MHD_GET_ARGUMENT_KIND, "name");
    const char *min_age_str = MHD_lookup_connection_value(conn, MHD_GET_ARGUMENT_KIND, "min_age");
    int min_age = INT_MIN; // 指定なしなら全員
    if (min_age_str != nullptr && min_age_str[0] != '\0' && !parse_int(min_age_str, &min_age)) {
        return error_reply(MHD_HTTP_BAD_REQUEST, "min_age must be an integer");
    }
    return (Reply){MHD_HTTP_OK, store_list(name, min_age)};
}

// GET /users/{id}
static Reply get_user(int id) {
    cJSON *user = store_get(id);
    if (user == nullptr) {
        return error_reply(MHD_HTTP_NOT_FOUND, "user not found");
    }
    return (Reply){MHD_HTTP_OK, user};
}

// POST /users
static Reply create_user(const Body *body) {
    cJSON *root = nullptr;
    UserInput in;
    const char *err = parse_input(body, &root, &in);
    Reply reply = err != nullptr ? error_reply(MHD_HTTP_BAD_REQUEST, err)
                                 : (Reply){MHD_HTTP_CREATED, store_create(&in)};
    cJSON_Delete(root);
    return reply;
}

// PUT /users/{id}（全置換）
static Reply update_user(int id, const Body *body) {
    cJSON *root = nullptr;
    UserInput in;
    const char *err = parse_input(body, &root, &in);
    Reply reply;
    if (err != nullptr) {
        reply = error_reply(MHD_HTTP_BAD_REQUEST, err);
    } else {
        cJSON *user = store_update(id, &in);
        reply = user != nullptr ? (Reply){MHD_HTTP_OK, user}
                                : error_reply(MHD_HTTP_NOT_FOUND, "user not found");
    }
    cJSON_Delete(root);
    return reply;
}

// DELETE /users/{id}
static Reply delete_user(int id) {
    if (!store_delete(id)) {
        return error_reply(MHD_HTTP_NOT_FOUND, "user not found");
    }
    return (Reply){MHD_HTTP_NO_CONTENT, nullptr};
}

// route はパスとメソッドでハンドラを選ぶ（ルート定義）。
static Reply route(struct MHD_Connection *conn, const char *url, const char *method,
                   const Body *body) {
    static const char prefix[] = "/users/";
    if (strcmp(url, "/users") == 0) {
        if (strcmp(method, MHD_HTTP_METHOD_GET) == 0) {
            return list_users(conn);
        }
        if (strcmp(method, MHD_HTTP_METHOD_POST) == 0) {
            return create_user(body);
        }
        return error_reply(MHD_HTTP_METHOD_NOT_ALLOWED, "method not allowed");
    }
    if (strncmp(url, prefix, strlen(prefix)) == 0) {
        // id が数値でなければ「見つからない」扱い
        int id = 0;
        if (!parse_int(url + strlen(prefix), &id)) {
            return error_reply(MHD_HTTP_NOT_FOUND, "user not found");
        }
        if (strcmp(method, MHD_HTTP_METHOD_GET) == 0) {
            return get_user(id);
        }
        if (strcmp(method, MHD_HTTP_METHOD_PUT) == 0) {
            return update_user(id, body);
        }
        if (strcmp(method, MHD_HTTP_METHOD_DELETE) == 0) {
            return delete_user(id);
        }
        return error_reply(MHD_HTTP_METHOD_NOT_ALLOWED, "method not allowed");
    }
    return error_reply(MHD_HTTP_NOT_FOUND, "not found");
}

// send_reply は Reply を JSON（Content-Type: application/json）にして送る。
static enum MHD_Result send_reply(struct MHD_Connection *conn, Reply reply) {
    struct MHD_Response *res = nullptr;
    if (reply.body == nullptr) {
        res = MHD_create_response_empty(MHD_RF_NONE);
    } else {
        char *text = cJSON_PrintUnformatted(reply.body);
        cJSON_Delete(reply.body);
        if (text == nullptr) {
            return MHD_NO;
        }
        // text は送信後に MHD が cJSON_free で解放する
        res = MHD_create_response_from_buffer_with_free_callback(strlen(text), text, cJSON_free);
        if (res == nullptr) {
            cJSON_free(text);
            return MHD_NO;
        }
        MHD_add_response_header(res, MHD_HTTP_HEADER_CONTENT_TYPE, "application/json");
    }
    if (res == nullptr) {
        return MHD_NO;
    }
    enum MHD_Result ret = MHD_queue_response(conn, reply.status, res);
    MHD_destroy_response(res);
    return ret;
}

// handle_request は 1 リクエストにつき複数回呼ばれる。
//   1 回目: *req_cls が nullptr → ボディ用バッファを用意するだけ
//   2 回目以降: upload_data にボディの断片が来る → 貯める
//   最後: *upload_data_size == 0 → ルーティングしてレスポンスを返す
static enum MHD_Result handle_request([[maybe_unused]] void *cls, struct MHD_Connection *conn,
                                      const char *url, const char *method,
                                      [[maybe_unused]] const char *version, const char *upload_data,
                                      size_t *upload_data_size, void **req_cls) {
    if (*req_cls == nullptr) {
        *req_cls = calloc(1, sizeof(Body));
        return *req_cls != nullptr ? MHD_YES : MHD_NO;
    }
    Body *body = *req_cls;
    if (*upload_data_size > 0) {
        if (body->len + *upload_data_size > MAX_BODY_SIZE) {
            return MHD_NO; // 大きすぎるボディは接続ごと切る
        }
        body->data = xrealloc(body->data, body->len + *upload_data_size);
        memcpy(body->data + body->len, upload_data, *upload_data_size);
        body->len += *upload_data_size;
        *upload_data_size = 0; // 「全部受け取った」と MHD に伝える
        return MHD_YES;
    }
    Reply reply = route(conn, url, method, body);
    printf("%s %s -> %u\n", method, url, reply.status);
    return send_reply(conn, reply);
}

// request_completed はリクエスト終了時に呼ばれる。ボディ用バッファを解放する。
static void request_completed([[maybe_unused]] void *cls,
                              [[maybe_unused]] struct MHD_Connection *conn, void **req_cls,
                              [[maybe_unused]] enum MHD_RequestTerminationCode toe) {
    Body *body = *req_cls;
    if (body != nullptr) {
        free(body->data);
        free(body);
        *req_cls = nullptr;
    }
}

int main(void) {
    setvbuf(stdout, nullptr, _IOLBF, 0); // パイプ越しでもログを 1 行ずつ出す

    int port = DEFAULT_PORT;
    const char *port_env = getenv("PORT");
    if (port_env != nullptr && (!parse_int(port_env, &port) || port <= 0 || port > UINT16_MAX)) {
        fprintf(stderr, "invalid PORT: %s\n", port_env);
        return 1;
    }

    add_user(&(UserInput){"Alice", "alice@example.com", 30});
    add_user(&(UserInput){"Bob", "bob@example.com", 25});

    // Ctrl+C / SIGTERM を main で sigwait するため、MHD のスレッドを作る前にブロックしておく
    sigset_t signals;
    sigemptyset(&signals);
    sigaddset(&signals, SIGINT);
    sigaddset(&signals, SIGTERM);
    pthread_sigmask(SIG_BLOCK, &signals, nullptr);

    struct sockaddr_in addr = {.sin_family = AF_INET, .sin_port = htons((uint16_t)port)};
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

    // 接続ごとにスレッドを立てるモードで起動（ハンドラは並行に呼ばれる）。
    // MHD_OPTION_* と値の組を MHD_OPTION_END まで並べてオプションを渡す
    const unsigned int flags =
        MHD_USE_INTERNAL_POLLING_THREAD | MHD_USE_THREAD_PER_CONNECTION | MHD_USE_ERROR_LOG;
    struct MHD_Daemon *server = MHD_start_daemon(
        flags, 0, nullptr, nullptr, // ポート（SOCK_ADDR_LEN で指定）/ 接続の許可判定（なし）
        &handle_request, nullptr,   // リクエストハンドラ
        MHD_OPTION_SOCK_ADDR_LEN, (socklen_t)sizeof addr, (struct sockaddr *)&addr, // 127.0.0.1
        MHD_OPTION_NOTIFY_COMPLETED, &request_completed, nullptr, // 終わったらバッファを解放
        MHD_OPTION_END);
    if (server == nullptr) {
        fprintf(stderr, "failed to listen on 127.0.0.1:%d\n", port);
        return 1;
    }
    printf("listening on http://127.0.0.1:%d\n", port);

    int sig = 0;
    sigwait(&signals, &sig);
    MHD_stop_daemon(server);
    return 0;
}
