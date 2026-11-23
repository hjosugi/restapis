defmodule UsersApiWeb.Endpoint do
  @moduledoc "HTTP の入口（Bandit）。リクエストは上から順に plug を通って Router に届く。"
  use Phoenix.Endpoint, otp_app: :users_api

  # task dev: リクエストのたびに変更されたコードを再コンパイルする（ホットリロード）
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  # リクエストログ（"GET /users" / "Sent 200 in 1ms"）
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # JSON ボディを conn.body_params にデコードする。
  # 壊れた JSON は Plug.Parsers.ParseError になり、ErrorJSON が 400 {"error": ...} を返す
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug UsersApiWeb.Router
end
