# java-spring

Java + [Spring Boot](https://spring.io/projects/spring-boot)（Spring MVC / Maven）の users REST API と、Spring の `RestClient` で書いたクライアント。ポートは **8008**。

| ファイル | 内容 |
|---|---|
| `src/main/java/example/users/UsersApplication.java` | サーバー。`@RestController` + `@GetMapping("/{id}")` などでルート定義、`@Valid` + record の `@NotBlank` / `@Min` で入力チェック、`@RestControllerAdvice` でエラーを `{"error": ...}` に統一、`JsonMapperBuilderCustomizer` で JSON の型を厳密に（`"1"` を数値にしない） |
| `src/main/java/example/users/UsersClient.java` | クライアント（Spring は起動しない普通の `main`）。`RestClient.create(baseUrl)` + `.method(...).uri(...).body(...)`、`exchange` で 404 も例外にせず受け取る、`UriComponentsBuilder` でクエリ組み立て、Jackson の `JsonMapper` で record ⇔ JSON |
| `src/main/resources/application.properties` | `server.address=127.0.0.1` / `server.port=${PORT:8008}` |
| `pom.xml` | `spring-boot-starter-webmvc` + `spring-boot-starter-validation`（バージョンは親 POM が管理） |

```sh
task dev     # ファイル変更で再起動 (watchexec + mvn spring-boot:run)
task run     # サーバー起動 (別名: task main / task server)
task client  # 別ターミナルで CRUD + 検索を実行
task build   # 実行可能 jar を target/ に作る
task check   # curl で API 仕様どおりか検証
task fmt     # google-java-format
task lint    # google-java-format の差分チェック + PMD (pmd.xml)
```

ツール: JDK 25 / Maven / jdtls / google-java-format / PMD（すべて `flake.nix`）。Spring Boot 4.2 / Jackson 3 は Maven が取得
