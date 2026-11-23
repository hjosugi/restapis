defmodule UsersApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :users_api,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # task dev のホットリロード: Phoenix.CodeReloader がコンパイル結果を受け取る
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # UsersApi.Application（Store と Endpoint を起動する supervisor）がエントリポイント
  def application do
    [
      mod: {UsersApi.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.17"},
      {:bandit, "~> 1.15"},
      # クライアント（mix client）用。サーバーと一緒には起動しない
      {:req, "~> 0.7.5", runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false}
    ]
  end
end
