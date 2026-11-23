-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- Common Lisp は lspconfig / nvim-lint に使えるものが無いので、REPL 連携は Conjure + swank（task swank で起動）
return {
  { "Olical/conjure", ft = { "lisp" } }, -- 既定で 127.0.0.1:4005 の swank に接続する
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { lisp = { "cl_indentify" } },
      -- conform に組み込みが無いので、flake の cl-indentify（stdin → stdout）を formatter として登録
      formatters = { cl_indentify = { command = "cl-indentify", stdin = true } },
    },
  },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "commonlisp" } } },
}
