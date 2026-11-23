-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- TypeScript 7 の言語サーバー（tsc --lsp）。lang.typescript.tsc extra と同じもの
        tsc = { mason = false, enabled = true },
        vtsls = { enabled = false },
        -- oxlint は LSP（oxlint --lsp）で動かすので nvim-lint には登録しない
        oxlint = { mason = false },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        typescript = { "oxfmt" },
        json = { "oxfmt" },
        jsonc = { "oxfmt" },
        yaml = { "oxfmt" },
      },
    },
  },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "typescript", "json", "yaml" } } },
}
