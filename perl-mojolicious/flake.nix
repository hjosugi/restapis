{
  description = "perl-mojolicious: users REST API (Mojolicious) + Perl client (Mojo::UserAgent)";

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
              # toolchain + ライブラリ / formatter / linter / デバッガ (VS Code の richterger.perl 用)
              (perl.withPackages (
                ps: with ps; [
                  Mojolicious
                  JSONValidator
                  PerlTidy
                  PerlCritic
                  PerlLanguageServer
                ]
              ))
              # LSP
              perlnavigator
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "perl-mojolicious";
          };
        }
      );
    };
}
