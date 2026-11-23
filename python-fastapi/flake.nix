{
  description = "python-fastapi: users REST API (FastAPI + htmx) + Python client (httpx)";

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
          python = pkgs.python315;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain（Python 本体は nix、ライブラリは uv で .venv に入れる）
              python
              uv
              # formatter / linter / type checker (LSP も兼ねる: `ruff server` / `ty server`)
              ruff
              ty
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "python-fastapi";
            # uv が使う Python を nix のものに固定し、Python 本体のダウンロードを禁止する
            UV_PYTHON = python.interpreter;
            UV_PYTHON_DOWNLOADS = "never";
          };
        }
      );
    };
}
