-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
-- （LazyVim の lang.rust extra を使っている場合は rustaceanvim が PATH の rust-analyzer を起動する）
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { rust = { "rustfmt" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { rust = { "clippy" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "rust", "toml" } } },
}
