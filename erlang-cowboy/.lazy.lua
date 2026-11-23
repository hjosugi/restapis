-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter は Mason ではなく nix devShell（direnv）のものを使う
-- （elvis は nvim-lint に無いので `task lint` で実行する）
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        elp = { mason = false },
        -- lang.erlang extra の erlang_ls とは二重に起動しないようにする
        erlangls = { enabled = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { erlang = { "erlfmt" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "erlang" } } },
}
