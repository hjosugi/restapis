{
  description = "elixir-phoenix: users REST API (Phoenix) + Elixir client (Req)";

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
          beam = pkgs.beam29Packages;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain
              beam.erlang
              beam.elixir_1_20
              beam.rebar3
              # LSP
              beam.expert
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            # Hex / rebar3 は `mix local.hex` などで ~/.mix に入れず、nix のものを使う
            MIX_PATH = "${beam.hex}/lib/erlang/lib/hex-${beam.hex.version}/ebin";
            MIX_REBAR3 = "${beam.rebar3}/bin/rebar3";
            RESTAPI_PROJECT = "elixir-phoenix";
          };
        }
      );
    };
}
