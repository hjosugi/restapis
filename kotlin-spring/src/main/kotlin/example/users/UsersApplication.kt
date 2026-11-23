// users リソースの CRUD を提供する REST API サーバー（Spring Boot / Spring MVC / インメモリ保存）。
package example.users

import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.http.HttpStatus
import org.springframework.http.HttpStatusCode
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.stereotype.Component
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import org.springframework.web.server.ResponseStatusException
import tools.jackson.core.JacksonException
import tools.jackson.databind.DeserializationFeature
import tools.jackson.databind.MapperFeature
import tools.jackson.databind.cfg.CoercionAction
import tools.jackson.databind.cfg.CoercionInputShape
import tools.jackson.databind.type.LogicalType
import java.util.concurrent.ConcurrentSkipListMap
import java.util.concurrent.atomic.AtomicLong

@SpringBootApplication
class UsersApplication {
    // JSON の型を厳密にする（型違いは 400）。Jackson の既定では "1" → 1 などと自動変換してしまう
    @Bean
    fun strictJsonTypes() =
        JsonMapperBuilderCustomizer { builder ->
            builder
                .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS) // "1" → 1
                .disable(DeserializationFeature.ACCEPT_FLOAT_AS_INT) // 1.5 → 1
                // 123 / true → "123" / "true"
                .withCoercionConfig(LogicalType.Textual) {
                    it
                        .setCoercion(CoercionInputShape.Integer, CoercionAction.Fail)
                        .setCoercion(CoercionInputShape.Float, CoercionAction.Fail)
                        .setCoercion(CoercionInputShape.Boolean, CoercionAction.Fail)
                }
        }
}

fun main(args: Array<String>) {
    runApplication<UsersApplication>(*args)
}

// API で扱うリソース。data class は jackson-module-kotlin がそのまま JSON に変換する
data class User(
    val id: Long,
    val name: String,
    val email: String,
    val age: Int,
)

// POST / PUT のリクエストボディ。null 非許容の型なので項目の欠け・null は JSON 変換の時点で 400、
// 空文字や負の数は Bean Validation のアノテーション（@field: でフィールドに付ける）で 400
data class UserInput(
    @field:NotBlank val name: String,
    @field:NotBlank val email: String,
    @field:Min(0) val age: Int,
) {
    fun toUser(id: Long) = User(id, name, email, age)
}

data class ErrorBody(
    val error: String,
)

// メモリ上のユーザー一覧。Spring MVC はリクエストを並行処理するので、ロック不要の並行コレクションを使う
@Component
class UserStore {
    private val users = ConcurrentSkipListMap<Long, User>() // id 順に並ぶスレッドセーフなマップ
    private val nextId = AtomicLong(1)

    init {
        create(UserInput("Alice", "alice@example.com", 30))
        create(UserInput("Bob", "bob@example.com", 25))
    }

    fun list(
        name: String?,
        minAge: Int?,
    ): List<User> =
        users.values.filter { u ->
            (name == null || u.name.contains(name, ignoreCase = true)) && (minAge == null || u.age >= minAge)
        }

    fun get(id: Long): User? = users[id]

    fun create(input: UserInput): User = input.toUser(nextId.getAndIncrement()).also { users[it.id] = it }

    // computeIfPresent: id があるときだけ置き換える（無ければ null）
    fun update(
        id: Long,
        input: UserInput,
    ): User? = users.computeIfPresent(id) { _, _ -> input.toUser(id) }

    fun delete(id: Long): Boolean = users.remove(id) != null
}

// ルート定義。戻り値は Jackson で JSON に変換される（Content-Type: application/json）
@RestController
@RequestMapping("/users")
class UserController(
    private val store: UserStore,
) {
    // GET /users?name=al&min_age=20 （null 許容の引数は省略可。min_age が整数でなければ型変換エラー → 400）
    @GetMapping
    fun list(
        @RequestParam name: String?,
        @RequestParam("min_age") minAge: Int?,
    ): List<User> = store.list(name, minAge)

    @GetMapping("/{id}")
    fun get(
        @PathVariable id: Long,
    ): User = store.get(id) ?: throw notFound()

    // @Valid で UserInput のアノテーションを検査。NG なら MethodArgumentNotValidException → 400
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @Valid @RequestBody input: UserInput,
    ): User = store.create(input)

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @Valid @RequestBody input: UserInput,
    ): User = store.update(id, input) ?: throw notFound()

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(
        @PathVariable id: Long,
    ) {
        if (!store.delete(id)) throw notFound()
    }

    private fun notFound() = ResponseStatusException(HttpStatus.NOT_FOUND, "user not found")
}

// 例外を {"error": "..."} + application/json に揃える（Spring の既定は problem+json などになる）
@RestControllerAdvice
class ErrorHandler {
    // 404 など ResponseStatusException で投げたもの
    @ExceptionHandler
    fun handle(e: ResponseStatusException) = error(e.statusCode, e.reason.orEmpty())

    // @Valid の検査 NG（name が空、age が負 など）
    @ExceptionHandler
    fun handle(e: MethodArgumentNotValidException): ResponseEntity<ErrorBody> {
        val message =
            e.fieldErrors
                .map { "${it.field} ${it.defaultMessage}" }
                .sorted()
                .joinToString()
        return error(HttpStatus.BAD_REQUEST, message)
    }

    // 壊れた JSON、項目の欠け、型違い（age が文字列 "1" など）
    @ExceptionHandler
    fun handle(e: HttpMessageNotReadableException): ResponseEntity<ErrorBody> {
        val detail = (e.mostSpecificCause as? JacksonException)?.originalMessage.orEmpty()
        return error(HttpStatus.BAD_REQUEST, "invalid JSON body: $detail")
    }

    // クエリやパスの型変換エラー（min_age=abc, /users/abc）
    @ExceptionHandler
    fun handle(e: MethodArgumentTypeMismatchException) = error(HttpStatus.BAD_REQUEST, "${e.name} must be an integer")

    private fun error(
        status: HttpStatusCode,
        message: String,
    ) = ResponseEntity.status(status).body(ErrorBody(message))
}
