-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jdtls = { mason = false },
      },
    },
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { java = { "google-java-format" } } } },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = { java = { "pmd" } },
      -- task lint と同じ pmd.xml のルールを使う
      linters = {
        pmd = { args = { "check", "--format", "sarif", "--rulesets", "pmd.xml", "--no-progress", "--dir" } },
      },
    },
  },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "java", "xml", "properties" } } },
}
