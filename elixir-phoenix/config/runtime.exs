import Config

# 起動時に読まれる設定。127.0.0.1:$PORT（既定 8011）で待ち受ける
config :users_api, UsersApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "8011"))]
