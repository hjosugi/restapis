-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clojure_lsp = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { clojure = { "cljfmt" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { clojure = { "clj-kondo" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "clojure" } } },
}
