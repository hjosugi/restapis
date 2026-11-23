{
  description = "typescript-elysia: users REST API (Elysia on Bun) + TypeScript client (fetch)";

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
              # toolchain（デバッガは Bun 内蔵）
              bun
              # 型チェック + LSP（TypeScript 7 ネイティブ版: `tsc --noEmit` / `tsc --lsp`）
              typescript
              # formatter / linter（どちらも LSP モードあり）
              oxfmt
              oxlint
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "typescript-elysia";
          };
        }
      );
    };
}
