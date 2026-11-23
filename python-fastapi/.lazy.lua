-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter は Mason ではなく nix devShell（direnv）のものを使う
-- lint は ruff と ty の LSP が診断を出すので nvim-lint は使わない（入れると同じ警告が二重に出る）
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruff = { mason = false }, -- lint + code action (`ruff server`)
        ty = { mason = false }, -- 型チェック + 補完 (`ty server`)
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = { formatters_by_ft = { python = { "ruff_organize_imports", "ruff_format" } } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "python", "toml", "html" } },
  },
}
