-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter は Mason ではなく nix devShell（direnv）の gleam（`gleam lsp` / `gleam format`）を使う
-- コンパイラ警告は gleam lsp が診断として出すので nvim-lint は使わない（nvim-lint に gleam 用 linter も無い）
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gleam = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { gleam = { "gleam" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "gleam", "toml" } } },
}
