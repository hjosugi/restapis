defmodule UsersApiWeb.FallbackController do
  @moduledoc "UserController が返した `{:error, ...}` をエラーレスポンス `{\"error\": ...}` にする（action_fallback）。"
  use Phoenix.Controller, formats: [:json]

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "user not found"})
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: message})
  end
end
