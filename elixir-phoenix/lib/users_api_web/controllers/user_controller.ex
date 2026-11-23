defmodule UsersApiWeb.UserController do
  @moduledoc """
  users リソースの CRUD。

  失敗したら `{:error, ...}` を返すだけで、action_fallback の FallbackController が
  400 / 404 の `{"error": ...}` にする。
  """
  use Phoenix.Controller, formats: [:json]

  alias UsersApi.Store

  action_fallback UsersApiWeb.FallbackController

  # GET /users?name=al&min_age=20（クエリパラメータは params に入る）
  def index(conn, params) do
    with {:ok, min_age} <- parse_min_age(params["min_age"]) do
      json(conn, Store.list(params["name"], min_age))
    end
  end

  # GET /users/:id
  def show(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, user} <- Store.get(id) do
      json(conn, user)
    end
  end

  # POST /users → 201
  def create(conn, _params) do
    with {:ok, attrs} <- validate(conn.body_params) do
      conn
      |> put_status(:created)
      |> json(Store.create(attrs))
    end
  end

  # PUT /users/:id（全置換）
  def update(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         {:ok, attrs} <- validate(conn.body_params),
         {:ok, user} <- Store.update(id, attrs) do
      json(conn, user)
    end
  end

  # DELETE /users/:id → 204（ボディなし）
  def delete(conn, %{"id" => id}) do
    with {:ok, id} <- parse_id(id),
         :ok <- Store.delete(id) do
      send_resp(conn, :no_content, "")
    end
  end

  # 入力チェック: name / email は空でない文字列、age は 0 以上の整数（文字列 "1" は不可）
  defp validate(%{"name" => name, "email" => email, "age" => age})
       when is_binary(name) and name != "" and is_binary(email) and email != "" and
              is_integer(age) and age >= 0 do
    {:ok, %{name: name, email: email, age: age}}
  end

  defp validate(_body) do
    {:error, "name and email must be non-empty strings, age must be an integer >= 0"}
  end

  # /users/:id の id が数値でなければ「見つからない」扱い
  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :not_found}
    end
  end

  defp parse_min_age(value) when value in [nil, ""], do: {:ok, nil}

  defp parse_min_age(value) do
    case Integer.parse(value) do
      {min_age, ""} -> {:ok, min_age}
      _ -> {:error, "min_age must be an integer"}
    end
  end
end
