// REST API に CRUD + 検索を一通り投げるクライアント（libcurl easy interface + cJSON）。
#include <cjson/cJSON.h>
#include <curl/curl.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// User はレスポンスのユーザー（文字列はパースした cJSON の中を指す）。
typedef struct {
    int id;
    const char *name;
    const char *email;
    int age;
} User;

// UserInput は POST / PUT で送るボディ。
typedef struct {
    const char *name;
    const char *email;
    int age;
} UserInput;

// Buffer はレスポンスボディを貯めるバッファ（常に '\0' 終端）。
typedef struct {
    char *data;
    size_t len;
} Buffer;

static const char *base_url = "http://127.0.0.1:8001";
static CURL *curl; // easy ハンドルは使い回す（接続も再利用される）

// write_body は libcurl から届いたボディの断片を Buffer に追記する。
static size_t write_body(char *ptr, size_t size, size_t nmemb, void *userdata) {
    Buffer *buf = userdata;
    size_t n = size * nmemb;
    char *p = realloc(buf->data, buf->len + n + 1);
    if (p == nullptr) {
        return 0; // 受け取った量と違う値を返すと libcurl は転送を中止する
    }
    memcpy(p + buf->len, ptr, n);
    buf->data = p;
    buf->len += n;
    buf->data[buf->len] = '\0';
    return n;
}

// user_from_json はレスポンスの JSON を User にデコードする。
static bool user_from_json(const cJSON *json, User *out) {
    const cJSON *id = cJSON_GetObjectItemCaseSensitive(json, "id");
    const cJSON *name = cJSON_GetObjectItemCaseSensitive(json, "name");
    const cJSON *email = cJSON_GetObjectItemCaseSensitive(json, "email");
    const cJSON *age = cJSON_GetObjectItemCaseSensitive(json, "age");
    if (!cJSON_IsNumber(id) || !cJSON_IsString(name) || !cJSON_IsString(email) ||
        !cJSON_IsNumber(age)) {
        return false;
    }
    *out = (User){id->valueint, name->valuestring, email->valuestring, age->valueint};
    return true;
}

// call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。
// 戻り値はレスポンスボディ（呼び出し側で free する）。
static char *call(const char *method, const char *path, const UserInput *body) {
    char url[512];
    snprintf(url, sizeof url, "%s%s", base_url, path);

    curl_easy_reset(curl); // 前回のオプション（ボディ・ヘッダー）を消す
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);

    char *json = nullptr;
    struct curl_slist *headers = nullptr;
    if (body != nullptr) {
        // UserInput → JSON 文字列
        cJSON *obj = cJSON_CreateObject();
        cJSON_AddStringToObject(obj, "name", body->name);
        cJSON_AddStringToObject(obj, "email", body->email);
        cJSON_AddNumberToObject(obj, "age", body->age);
        json = cJSON_PrintUnformatted(obj);
        cJSON_Delete(obj);
        printf("> %s %s %s\n", method, path, json);

        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        // POSTFIELDS はコピーされないので perform が終わるまで json を解放しない
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);
    } else {
        printf("> %s %s\n", method, path);
    }

    Buffer res = {};
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_body);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &res);
    CURLcode rc = curl_easy_perform(curl);
    curl_slist_free_all(headers);
    cJSON_free(json);
    if (rc != CURLE_OK) {
        fprintf(stderr, "リクエスト失敗（サーバーは起動していますか？）: %s\n",
                curl_easy_strerror(rc));
        exit(1);
    }

    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    printf("< %ld %s\n\n", status, res.data != nullptr ? res.data : "");
    return res.data;
}

// search_path は "/users?key=value" を組み立てる（値は curl_easy_escape で URL エンコード）。
static void search_path(char *out, size_t size, const char *key, const char *value) {
    char *escaped = curl_easy_escape(curl, value, 0);
    snprintf(out, size, "/users?%s=%s", key, escaped);
    curl_free(escaped);
}

int main(void) {
    const char *env = getenv("API_URL");
    if (env != nullptr && env[0] != '\0') {
        base_url = env;
    }
    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();
    if (curl == nullptr) {
        fputs("curl_easy_init failed\n", stderr);
        return 1;
    }

    puts("--- 1. 一覧取得");
    free(call("GET", "/users", nullptr));

    puts("--- 2. 作成");
    char *data = call("POST", "/users", &(UserInput){"Carol", "carol@example.com", 35});
    cJSON *json = cJSON_Parse(data);
    free(data);
    User created;
    if (!user_from_json(json, &created)) {
        fputs("作成したユーザーを読み取れませんでした\n", stderr);
        return 1;
    }
    char user_path[32];
    snprintf(user_path, sizeof user_path, "/users/%d", created.id);
    cJSON_Delete(json);

    puts("--- 3. 1件取得");
    free(call("GET", user_path, nullptr));

    puts("--- 4. 更新");
    free(call("PUT", user_path, &(UserInput){"Carol Smith", "carol@example.com", 36}));

    char path[64];
    puts("--- 5. 検索（名前の部分一致）");
    search_path(path, sizeof path, "name", "car");
    free(call("GET", path, nullptr));

    puts("--- 6. 検索（年齢の下限）");
    search_path(path, sizeof path, "min_age", "30");
    free(call("GET", path, nullptr));

    puts("--- 7. 削除");
    free(call("DELETE", user_path, nullptr));

    puts("--- 8. 削除されたことを確認（404 になる）");
    free(call("GET", user_path, nullptr));

    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
