// REST API に CRUD + 検索を一通り投げるクライアント（Spring の RestClient + Kotlin 拡張。Spring Boot は起動しない）。
package example.users.client

import org.springframework.http.HttpMethod
import org.springframework.http.MediaType
import org.springframework.web.client.ResourceAccessException
import org.springframework.web.client.RestClient
import org.springframework.web.client.toEntity
import org.springframework.web.util.UriComponentsBuilder
import tools.jackson.module.kotlin.jacksonObjectMapper
import tools.jackson.module.kotlin.readValue
import kotlin.system.exitProcess

data class User(
    val id: Long,
    val name: String,
    val email: String,
    val age: Int,
)

data class UserInput(
    val name: String,
    val email: String,
    val age: Int,
)

private val baseUrl = System.getenv("API_URL") ?: "http://127.0.0.1:8009"
private val client = RestClient.create(baseUrl)
private val mapper = jacksonObjectMapper()

// call はリクエストを 1 本送り、送った内容と返ってきた内容を表示する。戻り値はレスポンスのボディ
private fun call(
    method: HttpMethod,
    path: String,
    body: Any? = null,
): String {
    val json = body?.let { mapper.writeValueAsString(it) } // data class → JSON
    println(listOfNotNull(">", method, path, json).joinToString(" "))

    val response =
        client
            .method(method)
            .uri(path)
            .apply { if (json != null) contentType(MediaType.APPLICATION_JSON).body(json) }
            .retrieve()
            .onStatus({ it.isError }) { _, _ -> } // 4xx/5xx でも例外にしない（404 をそのまま表示する）
            .toEntity<String>() // Kotlin 拡張: 型引数でボディの型を指定
    val text = response.body.orEmpty()
    println("< ${response.statusCode.value()} $text\n")
    return text
}

// /users?key=value を組み立てる（UriComponentsBuilder がクエリ文字列をつなぐ）
private fun usersQuery(
    key: String,
    value: Any,
) = UriComponentsBuilder
    .fromPath("/users")
    .queryParam(key, value)
    .build()
    .toUriString()

fun main() {
    try {
        run()
    } catch (e: ResourceAccessException) {
        System.err.println("リクエスト失敗（サーバーは起動していますか？）: ${e.mostSpecificCause}")
        exitProcess(1)
    }
}

private fun run() {
    println("--- 1. 一覧取得")
    call(HttpMethod.GET, "/users")

    println("--- 2. 作成")
    val created = mapper.readValue<User>(call(HttpMethod.POST, "/users", UserInput("Carol", "carol@example.com", 35)))
    val userPath = "/users/${created.id}"

    println("--- 3. 1件取得")
    call(HttpMethod.GET, userPath)

    println("--- 4. 更新")
    call(HttpMethod.PUT, userPath, UserInput("Carol Smith", "carol@example.com", 36))

    println("--- 5. 検索（名前の部分一致）")
    call(HttpMethod.GET, usersQuery("name", "car"))

    println("--- 6. 検索（年齢の下限）")
    call(HttpMethod.GET, usersQuery("min_age", 30))

    println("--- 7. 削除")
    call(HttpMethod.DELETE, userPath)

    println("--- 8. 削除されたことを確認（404 になる）")
    call(HttpMethod.GET, userPath)
}
