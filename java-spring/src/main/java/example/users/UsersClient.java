// REST API に CRUD + 検索を一通り投げるクライアント（Spring の RestClient。Spring Boot は起動しない普通の main）。
package example.users;

import java.nio.charset.StandardCharsets;
import java.util.Objects;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;
import tools.jackson.databind.json.JsonMapper;

public final class UsersClient {

  record User(long id, String name, String email, int age) {}

  record UserInput(String name, String email, int age) {}

  private static final String BASE_URL =
      Objects.requireNonNullElse(System.getenv("API_URL"), "http://127.0.0.1:8008");
  private static final RestClient CLIENT = RestClient.create(BASE_URL);
  private static final JsonMapper JSON = JsonMapper.shared();

  private UsersClient() {}

  // call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。戻り値はレスポンスのボディ。
  private static String call(HttpMethod method, String path, Object body) {
    var request = CLIENT.method(method).uri(path);
    if (body == null) {
      System.out.printf("> %s %s%n", method, path);
    } else {
      var json = JSON.writeValueAsString(body); // record → JSON
      System.out.printf("> %s %s %s%n", method, path, json);
      request = request.contentType(MediaType.APPLICATION_JSON).body(json);
    }
    // exchange はステータスコードで例外を投げないので 404 もそのまま扱える（retrieve() だと 4xx で例外）
    return request.exchange((_, response) -> {
      var text = new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
      System.out.printf("< %d %s%n%n", response.getStatusCode().value(), text);
      return text;
    });
  }

  private static String call(HttpMethod method, String path) {
    return call(method, path, null);
  }

  // /users?key=value を組み立てる（UriComponentsBuilder がクエリ文字列をつなぐ）
  private static String usersQuery(String key, Object value) {
    return UriComponentsBuilder.fromPath("/users").queryParam(key, value).build().toUriString();
  }

  public static void main(String[] args) {
    try {
      run();
    } catch (ResourceAccessException e) {
      System.err.println("リクエスト失敗（サーバーは起動していますか？）: " + e.getMostSpecificCause());
      System.exit(1);
    }
  }

  private static void run() {
    System.out.println("--- 1. 一覧取得");
    call(HttpMethod.GET, "/users");

    System.out.println("--- 2. 作成");
    var text = call(HttpMethod.POST, "/users", new UserInput("Carol", "carol@example.com", 35));
    var created = JSON.readValue(text, User.class); // JSON → record
    var userPath = "/users/" + created.id();

    System.out.println("--- 3. 1件取得");
    call(HttpMethod.GET, userPath);

    System.out.println("--- 4. 更新");
    call(HttpMethod.PUT, userPath, new UserInput("Carol Smith", "carol@example.com", 36));

    System.out.println("--- 5. 検索（名前の部分一致）");
    call(HttpMethod.GET, usersQuery("name", "car"));

    System.out.println("--- 6. 検索（年齢の下限）");
    call(HttpMethod.GET, usersQuery("min_age", 30));

    System.out.println("--- 7. 削除");
    call(HttpMethod.DELETE, userPath);

    System.out.println("--- 8. 削除されたことを確認（404 になる）");
    call(HttpMethod.GET, userPath);
  }
}
