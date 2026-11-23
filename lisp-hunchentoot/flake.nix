{
  description = "lisp-hunchentoot: users REST API (Hunchentoot) + Common Lisp client (dexador)";

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

          # alive-lsp: VS Code の Alive 拡張が使う LSP サーバー（Common Lisp 製）。nixpkgs に無いので GitHub からビルド
          alive-lsp = pkgs.sbcl.buildASDFSystem rec {
            pname = "alive-lsp";
            version = "0.4.6";
            src = pkgs.fetchFromGitHub {
              owner = "nobody-famous";
              repo = "alive-lsp";
              tag = "v${version}";
              hash = "sha256-fgvTspmiWgocnQopFDyW+3Ioo7WkcVY264Dcz8abOhw=";
            };
            lispLibs = with pkgs.sbcl.pkgs; [
              usocket
              cl-json
              bordeaux-threads
              flexi-streams
            ];
          };

          # SBCL + ライブラリ（ASDF から見える。Quicklisp は使わない）
          sbcl = pkgs.sbcl.withPackages (
            ps: with ps; [
              # server / client
              hunchentoot
              easy-routes
              com_dot_inuoe_dot_jzon
              dexador
              # エディタ連携: swank (nvim の Conjure) / alive-lsp (VS Code の Alive)
              swank
              alive-lsp
            ]
          );

          # mallet: Common Lisp のリンター。nixpkgs に無いので GitHub のソースからビルド（依存は .bundle-libs に同梱）
          mallet = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "mallet";
            version = "0.9.2";
            src = pkgs.fetchFromGitHub {
              owner = "fukamachi";
              repo = "mallet";
              tag = finalAttrs.version;
              hash = "sha256-9LVmkzsEGQOgKwRh5Nofu/D0uNEH21bGtPsTm/D0ifw=";
            };
            nativeBuildInputs = [ pkgs.sbcl ];
            buildPhase = ''
              export HOME=$TMPDIR
              sbcl --noinform --non-interactive --load init.lisp --eval '(asdf:make :mallet/executable)'
            '';
            installPhase = "install -Dm755 mallet $out/bin/mallet";
            # SBCL の実行ファイルは末尾にコアイメージを持つので strip / patchelf しない
            dontStrip = true;
            dontPatchELF = true;
          });

          # cl-indentify: Common Lisp のインデント整形。nixpkgs のライブラリを小さな CLI で包む
          #   cl-indentify FILE...          インデントを直して上書き
          #   cl-indentify --check FILE...  整形済みでなければ終了コード 1（lint 用）
          #   cl-indentify                  stdin を整形して stdout へ（エディタ用）
          # カレントディレクトリの .cl-indentify.lisp を追加のテンプレート（マクロのインデント）として読む
          cl-indentify = pkgs.writeShellScriptBin "cl-indentify" ''
            exec ${
              pkgs.sbcl.withPackages (ps: [ ps.cl-indentify ])
            }/bin/sbcl --script ${pkgs.writeText "cl-indentify.lisp" ''
              (require :asdf)
              (asdf:load-system "cl-indentify")
              (indentify:load-default-templates)
              (indentify:load-template-file ".cl-indentify.lisp")
              (defun indent-string (string)
                (with-output-to-string (out)
                  (with-input-from-string (in string)
                    (indentify:indentify in out))))
              (let* ((args (uiop:command-line-arguments))
                     (check (equal (first args) "--check"))
                     (files (if check (rest args) args))
                     (dirty nil))
                (if (null files)
                    (indentify:indentify *standard-input* *standard-output*)
                    (dolist (file files)
                      (let* ((old (uiop:read-file-string file))
                             (new (indent-string old)))
                        (unless (string= old new)
                          (setf dirty t)
                          (if check
                              (format *error-output* "~A: インデントが cl-indentify と異なります~%" file)
                              (with-open-file (out file :direction :output :if-exists :supersede)
                                (write-string new out)))))))
                (uiop:quit (if (and check dirty) 1 0)))
            ''} "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            packages = [
              # toolchain + libs / LSP
              sbcl
              # formatter / linter
              cl-indentify
              mallet
              # 共通: タスクランナー / ファイル監視 / HTTP
              pkgs.go-task
              pkgs.watchexec
              pkgs.curl
              pkgs.jq
            ];
            RESTAPI_PROJECT = "lisp-hunchentoot";
            # このディレクトリを ASDF の探索先に入れる（REPL から (asdf:load-system "users/server") できる）。
            # 末尾に ":" を付けないこと: sbcl のラッパーが付けるものと合わせて「継承」が 2 つになりエラーになる
            shellHook = ''
              export CL_SOURCE_REGISTRY="$PWD"
            '';
          };
        }
      );
    };
}
