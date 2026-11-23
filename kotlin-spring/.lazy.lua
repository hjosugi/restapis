-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        kotlin_language_server = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { kotlin = { "ktlint" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { kotlin = { "ktlint" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "kotlin" } } },
}
