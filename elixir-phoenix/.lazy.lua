-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        expert = { mason = false },
        -- lang.elixir extra の ElixirLS とは二重に起動しないようにする
        elixirls = { enabled = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { elixir = { "mix" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { elixir = { "credo" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "elixir" } } },
}
