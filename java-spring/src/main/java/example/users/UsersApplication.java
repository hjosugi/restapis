// users リソースの CRUD を提供する REST API サーバー（Spring Boot / Spring MVC / インメモリ保存）。
package example.users;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.concurrent.ConcurrentNavigableMap;
import java.util.concurrent.ConcurrentSkipListMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.cfg.CoercionAction;
import tools.jackson.databind.cfg.CoercionInputShape;
import tools.jackson.databind.type.LogicalType;

@SpringBootApplication
public class UsersApplication {

  /** API で扱うリソース。record は Jackson がそのまま JSON に変換する。 */
  public record User(long id, String name, String email, int age) {}

  /** POST / PUT のリクエストボディ。アノテーションで入力チェック（age は未指定を弾くため Integer）。 */
  public record UserInput(
      @NotBlank String name, @NotBlank String email, @NotNull @Min(0) Integer age) {}

  /** エラーレスポンス {"error": "..."}。 */
  public record ErrorBody(String error) {}

  /** JSON の型を厳密にする（型違いは 400）。Jackson の既定では "1" → 1 などと自動変換してしまう。 */
  @Bean
  JsonMapperBuilderCustomizer strictJsonTypes() {
    return builder ->
        builder
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS) // "1" → 1
            .disable(DeserializationFeature.ACCEPT_FLOAT_AS_INT) // 1.5 → 1
            .withCoercionConfig( // 123 / true → "123" / "true"
                LogicalType.Textual,
                c ->
                    c.setCoercion(CoercionInputShape.Integer, CoercionAction.Fail)
                        .setCoercion(CoercionInputShape.Float, CoercionAction.Fail)
                        .setCoercion(CoercionInputShape.Boolean, CoercionAction.Fail));
  }

  /** メモリ上のユーザー一覧。Spring MVC はリクエストを並行処理するので、ロック不要の並行コレクションを使う。 */
  @Component
  public static class UserStore {
    // id 順に並ぶスレッドセーフなマップ
    private final ConcurrentNavigableMap<Long, User> users = new ConcurrentSkipListMap<>();
    private final AtomicLong nextId = new AtomicLong(1);

    public UserStore() {
      create(new UserInput("Alice", "alice@example.com", 30));
      create(new UserInput("Bob", "bob@example.com", 25));
    }

    public List<User> list(String name, Integer minAge) {
      return users.values().stream()
          .filter(u -> name == null || lower(u.name()).contains(lower(name)))
          .filter(u -> minAge == null || u.age() >= minAge)
          .toList();
    }

    public Optional<User> get(long id) {
      return Optional.ofNullable(users.get(id));
    }

    public User create(UserInput in) {
      var user = new User(nextId.getAndIncrement(), in.name(), in.email(), in.age());
      users.put(user.id(), user);
      return user;
    }

    public Optional<User> update(long id, UserInput in) {
      // computeIfPresent: id があるときだけ置き換える（無ければ null）
      return Optional.ofNullable(
          users.computeIfPresent(id, (key, _) -> new User(key, in.name(), in.email(), in.age())));
    }

    public boolean delete(long id) {
      return users.remove(id) != null;
    }

    private static String lower(String s) {
      return s.toLowerCase(Locale.ROOT);
    }
  }

  /** ルート定義。戻り値は Jackson で JSON に変換される（Content-Type: application/json）。 */
  @RestController
  @RequestMapping("/users")
  public static class UserController {
    private final UserStore store;

    public UserController(UserStore store) {
      this.store = store;
    }

    // GET /users?name=al&min_age=20 （min_age が整数でなければ型変換エラー → ErrorHandler で 400）
    @GetMapping
    public List<User> list(
        @RequestParam(required = false) String name,
        @RequestParam(name = "min_age", required = false) Integer minAge) {
      return store.list(name, minAge);
    }

    @GetMapping("/{id}")
    public User get(@PathVariable long id) {
      return store.get(id).orElseThrow(UserController::notFound);
    }

    // @Valid で UserInput のアノテーションを検査。NG なら MethodArgumentNotValidException → 400
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public User create(@Valid @RequestBody UserInput in) {
      return store.create(in);
    }

    @PutMapping("/{id}")
    public User update(@PathVariable long id, @Valid @RequestBody UserInput in) {
      return store.update(id, in).orElseThrow(UserController::notFound);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
      if (!store.delete(id)) {
        throw notFound();
      }
    }

    private static ResponseStatusException notFound() {
      return new ResponseStatusException(HttpStatus.NOT_FOUND, "user not found");
    }
  }

  /** 例外を {"error": "..."} + application/json に揃える（Spring の既定は problem+json などになる）。 */
  @RestControllerAdvice
  public static class ErrorHandler {

    // 404 など ResponseStatusException で投げたもの
    @ExceptionHandler
    public ResponseEntity<ErrorBody> handle(ResponseStatusException e) {
      return error(e.getStatusCode(), e.getReason());
    }

    // @Valid の検査 NG（name が空、age が負 など）
    @ExceptionHandler
    public ResponseEntity<ErrorBody> handle(MethodArgumentNotValidException e) {
      var message =
          e.getFieldErrors().stream()
              .map(f -> f.getField() + " " + f.getDefaultMessage())
              .sorted()
              .collect(Collectors.joining(", "));
      return error(HttpStatus.BAD_REQUEST, message);
    }

    // 壊れた JSON、型違い（age が文字列 "1" など）
    @ExceptionHandler
    public ResponseEntity<ErrorBody> handle(HttpMessageNotReadableException e) {
      var detail =
          e.getMostSpecificCause() instanceof JacksonException je ? je.getOriginalMessage() : "";
      return error(HttpStatus.BAD_REQUEST, "invalid JSON body: " + detail);
    }

    // クエリやパスの型変換エラー（min_age=abc, /users/abc）
    @ExceptionHandler
    public ResponseEntity<ErrorBody> handle(MethodArgumentTypeMismatchException e) {
      return error(HttpStatus.BAD_REQUEST, e.getName() + " must be an integer");
    }

    private static ResponseEntity<ErrorBody> error(HttpStatusCode status, String message) {
      return ResponseEntity.status(status).body(new ErrorBody(message));
    }
  }

  public static void main(String[] args) {
    SpringApplication.run(UsersApplication.class, args);
  }
}
