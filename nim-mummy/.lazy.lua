-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter は Mason ではなく nix devShell（direnv）のものを使う
-- nvim-lint には Nim 用のリンターが無いので、診断は nimlangserver（nimsuggest）に任せる
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nim_langserver = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { nim = { "nph" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "nim", "nim_format_string" } } },
}
