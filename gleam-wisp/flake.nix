{
  description = "gleam-wisp: users REST API (Wisp + Mist) + Gleam client (gleam_httpc)";

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
              # toolchain (LSP / formatter も gleam 本体: gleam lsp / gleam format)
              gleam
              beam29Packages.erlang
              beam29Packages.rebar3 # mist の依存 hpack_erl (rebar3 プロジェクト) のビルドに使う
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "gleam-wisp";
          };
        }
      );
    };
}
