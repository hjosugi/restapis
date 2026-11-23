# kotlin-spring

Kotlin + [Spring Boot](https://spring.io/projects/spring-boot)（Spring MVC / Gradle Kotlin DSL）の users REST API と、Spring の `RestClient` + Kotlin 拡張で書いたクライアント。ポートは **8009**。

| ファイル | 内容 |
|---|---|
| `src/main/kotlin/example/users/UsersApplication.kt` | サーバー。`@RestController` + `@GetMapping("/{id}")` などでルート定義、`@Valid` + data class の `@field:NotBlank` / `@field:Min` で入力チェック（欠けた項目・null は null 非許容の型で 400）、`@RestControllerAdvice` でエラーを `{"error": ...}` に統一、`JsonMapperBuilderCustomizer` で JSON の型を厳密に（`"1"` を数値にしない） |
| `src/main/kotlin/example/users/client/UsersClient.kt` | クライアント（Spring は起動しない普通の `main`）。`RestClient.create(baseUrl)` + `.method(...).uri(...)`、`onStatus` で 404 も例外にせず `toEntity<String>()`（Kotlin 拡張）で受け取る、`UriComponentsBuilder` でクエリ組み立て、`jacksonObjectMapper()` + `readValue<User>()` で data class ⇔ JSON |
| `src/main/resources/application.properties` | `server.address=127.0.0.1` / `server.port=${PORT:8009}` |
| `build.gradle.kts` | `spring-boot-starter-webmvc` + `spring-boot-starter-validation` + `jackson-module-kotlin`、クライアント用の `client` タスク |

```sh
task dev     # ファイル変更で再起動 (watchexec + gradle bootRun)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task build   # 実行可能 jar を build/libs/ に作る
task check   # curl で API 仕様どおりか検証
task fmt     # ktlint --format
task lint    # ktlint
task stop    # Gradle デーモンを止める
```

ツール: JDK 25 / Gradle 9 / kotlin-language-server / ktlint（すべて `flake.nix`。Gradle Wrapper は置かない）。Kotlin 2.4 / Spring Boot 4.2 / Jackson 3 は Gradle が取得
