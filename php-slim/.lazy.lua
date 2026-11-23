-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        phpactor = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { php = { "php_cs_fixer" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { php = { "phpstan" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "php", "phpdoc" } } },
}
