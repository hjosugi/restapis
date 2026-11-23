{
  description = "cpp-drogon: users REST API (Drogon) + C++ client (cpr)";

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
              # toolchain / libs (コンパイラは stdenv の g++)
              cmake
              ninja
              drogon
              libcpr
              nlohmann_json
              # LSP (clangd) / formatter (clang-format) / linter (clang-tidy)
              llvmPackages_latest.clang-tools
              # debugger
              gdb
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            # -O0 のデバッグビルドで _FORTIFY_SOURCE の警告が出ないように
            hardeningDisable = [ "fortify" ];
            RESTAPI_PROJECT = "cpp-drogon";
          };
        }
      );
    };
}
