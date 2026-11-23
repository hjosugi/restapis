-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        hls = { mason = false, settings = { haskell = { formattingProvider = "fourmolu" } } },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { haskell = { "fourmolu" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { haskell = { "hlint" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "haskell" } } },
}
