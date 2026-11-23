{
  description = "erlang-cowboy: users REST API (Cowboy) + Erlang client (httpc)";

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
              beam29Packages.erlang
              beam29Packages.rebar3
              # LSP / formatter / linter
              erlang-language-platform
              beam29Packages.erlfmt
              beam29Packages.elvis-erlang
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "erlang-cowboy";
          };
        }
      );
    };
}
