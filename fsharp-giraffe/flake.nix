{
  description = "fsharp-giraffe: users REST API (Giraffe) + F# client (HttpClient)";

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
          dotnet = pkgs.dotnet-sdk_11;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain
              dotnet
              # LSP / debugger (VS Code は C# 拡張同梱の vsdbg、Neovim は netcoredbg)
              fsautocomplete
              netcoredbg
              # formatter / linter
              fantomas
              fsharplint
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "fsharp-giraffe";
            # fsautocomplete / fantomas / fsharplint なども この SDK を使う
            DOTNET_ROOT = "${dotnet}/share/dotnet";
            DOTNET_CLI_TELEMETRY_OPTOUT = "1";
            DOTNET_NOLOGO = "1";
            DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";
          };
        }
      );
    };
}
