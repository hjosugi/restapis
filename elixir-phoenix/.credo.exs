# Credo の設定。チェック項目は既定のまま、優先度の低いものも含めて表示する（mix credo --strict 相当）
%{
  configs: [
    %{
      name: "default",
      files: %{included: ["mix.exs", "config/", "lib/"]},
      strict: true
    }
  ]
}
