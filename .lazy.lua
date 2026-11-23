-- LazyVim のプロジェクトローカル設定（ルート: flake.nix の編集用）
-- 各言語の設定は <言語>-<フレームワーク>/.lazy.lua にある（そのディレクトリで nvim を開く）
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = { mason = false, settings = { nixd = { formatting = { command = { "nixfmt" } } } } },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { nix = { "nixfmt" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "nix", "http" } } },
}
