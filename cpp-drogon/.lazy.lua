-- LazyVim のプロジェクトローカル設定（このディレクトリで nvim を開くと読み込まれる）
-- LSP / formatter / linter は Mason ではなく nix devShell（direnv）のものを使う
-- clangd は `task configure`（CMake）で生成される build/compile_commands.json を読む
return {
  { "neovim/nvim-lspconfig", opts = { servers = { clangd = { mason = false } } } },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { cpp = { "clang-format" } } } },
  { "mfussenegger/nvim-lint", opts = { linters_by_ft = { cpp = { "clangtidy" } } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "cpp", "cmake" } } },
}
