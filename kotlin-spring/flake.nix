{
  description = "kotlin-spring: users REST API (Spring Boot, Gradle) + Kotlin client (RestClient)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain（Kotlin コンパイラは Gradle の Kotlin プラグインが build.gradle.kts の版を取得する）
              jdk25
              gradle_9
              # LSP / formatter + linter
              kotlin-language-server
              ktlint
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "kotlin-spring";
            # Gradle Wrapper を置いていないので、IDE（Gradle for Java / Kotlin LSP）にも nix の Gradle を使わせる
            GRADLE_HOME = "${pkgs.gradle_9}/libexec/gradle";
          };
        }
      );
    };
}
