{
  description = "php-slim: users REST API (Slim) + PHP client (Guzzle)";

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
          # PHP 8.5 + Xdebug（普段は off。VS Code の xdebug.php-debug から起動したときだけ -dxdebug.mode=debug で有効）
          php = pkgs.php85.buildEnv {
            extensions = { enabled, all }: enabled ++ [ all.xdebug ];
            extraConfig = "xdebug.mode = off";
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain
              php
              php85Packages.composer
              # LSP / formatter / linter
              phpactor
              php85Packages.php-cs-fixer
              phpstan
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "php-slim";
          };
        }
      );
    };
}
