-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        perlnavigator = {
          mason = false,
          settings = {
            perlnavigator = {
              perltidyProfile = "$workspaceFolder/.perltidyrc",
              perlcriticProfile = "$workspaceFolder/.perlcriticrc",
            },
          },
        },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { perl = { "perltidy" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { perl = { "perlcritic" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "perl" } } },
}
