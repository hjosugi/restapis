plugins {
    kotlin("jvm") version "2.4.21"
    kotlin("plugin.spring") version "2.4.21" // Spring が使うクラスを自動で open にする
    id("org.springframework.boot") version "4.2.0"
    id("io.spring.dependency-management") version "1.1.7" // Spring Boot の BOM で依存のバージョンを決める
}

group = "example"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring MVC + 組み込み Tomcat + Jackson（RestClient もここに含まれる）
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    // Bean Validation (Hibernate Validator): @Valid / @NotBlank / @Min など
    implementation("org.springframework.boot:spring-boot-starter-validation")
    // data class を Jackson で JSON 変換するため
    implementation("tools.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
}

kotlin {
    compilerOptions {
        freeCompilerArgs.addAll("-Xjsr305=strict", "-Xemit-jvm-type-annotations")
    }
}

springBoot {
    mainClass = "example.users.UsersApplicationKt"
}

// gradle client: Spring Boot は起動せず、クライアントの main をプロジェクトのクラスパスで実行する
tasks.register<JavaExec>("client") {
    description = "Runs the users API client."
    classpath = sourceSets.main.get().runtimeClasspath
    mainClass = "example.users.client.UsersClientKt"
}
