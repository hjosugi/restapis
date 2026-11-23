-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = { mason = false, settings = { gopls = { gofumpt = true } } },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { go = { "gofumpt" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { go = { "golangcilint" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "go", "gomod", "gosum" } } },
}
