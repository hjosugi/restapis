import Config

config :users_api, UsersApiWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  # 例外（壊れた JSON・存在しないルートなど）を ErrorJSON で {"error": ...} にする
  render_errors: [formats: [json: UsersApiWeb.ErrorJSON], layout: false]

# JSON は Elixir 標準の JSON モジュールを使う（Jason は不要）
config :phoenix, :json_library, JSON

if config_env() == :dev do
  # task dev: 変更されたコードを次のリクエストで再コンパイルする
  config :users_api, UsersApiWeb.Endpoint, code_reloader: true
end

if config_env() == :prod do
  # task run: デバッグログ（パラメータの表示など）を出さない
  config :logger, level: :info
end
