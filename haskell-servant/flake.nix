{
  description = "haskell-servant: users REST API (Servant) + Haskell client (servant-client)";

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
          # GHC は nixpkgs 既定の haskellPackages（GHC 9.10）。
          # 9.12 / 9.14 は servant 一式や HLS がバイナリキャッシュに無く、ソースからのビルドになるため使わない。
          # Haskell の依存は Hackage ではなく nix から入れる（cabal はこの GHC のパッケージ DB だけで build できる）。
          ghc = pkgs.haskellPackages.ghcWithPackages (
            p: with p; [
              servant-server
              servant-client
              warp
              aeson
              http-client
            ]
          );
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              # toolchain
              ghc
              cabal-install
              # LSP / formatter / linter / ホットリロード
              haskell-language-server
              fourmolu
              hlint
              ghcid
              # 共通: タスクランナー / ファイル監視 / HTTP
              go-task
              watchexec
              curl
              jq
            ];
            RESTAPI_PROJECT = "haskell-servant";
          };
        }
      );
    };
}
