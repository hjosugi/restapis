{
  description = "rust-axum: users REST API (axum) + Rust client (reqwest)";

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
              # toolchain
              rustc
              cargo
              # LSP / formatter / linter
              rust-analyzer
              rustfmt
              clippy
              # デバッガは VS Code の CodeLLDB に同梱の lldb を使う
              # （nixpkgs の lldb は依存込みで約 1.4GB あるので入れない）
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            # rust-analyzer が標準ライブラリのソースを見つけられるように
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
            RESTAPI_PROJECT = "rust-axum";
          };
        }
      );
    };
}
