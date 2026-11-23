defmodule UsersApi.Application do
  @moduledoc "OTP アプリケーション。ストア（Agent）と Phoenix の Endpoint を supervisor の下で起動する。"
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      # 先にストアを起動してから HTTP を受け付ける
      UsersApi.Store,
      UsersApiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: UsersApi.Supervisor)
  end
end
