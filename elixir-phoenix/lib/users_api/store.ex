defmodule UsersApi.Store do
  @moduledoc """
  メモリ上のユーザー一覧（Agent）。Application の supervisor から起動する。

  Agent は 1 つのプロセスで、更新は 1 件ずつ順番に処理されるのでロックは要らない。
  """
  use Agent

  alias UsersApi.User

  def start_link(_opts) do
    users = %{
      1 => %User{id: 1, name: "Alice", email: "alice@example.com", age: 30},
      2 => %User{id: 2, name: "Bob", email: "bob@example.com", age: 25}
    }

    Agent.start_link(fn -> %{users: users, next_id: 3} end, name: __MODULE__)
  end

  # name は大文字小文字を無視した部分一致、min_age は age >= min_age（どちらも nil なら条件なし）
  def list(name, min_age) do
    name = String.downcase(name || "")

    Agent.get(__MODULE__, &Map.values(&1.users))
    |> Enum.filter(fn user ->
      String.contains?(String.downcase(user.name), name) and
        (min_age == nil or user.age >= min_age)
    end)
    |> Enum.sort_by(& &1.id)
  end

  def get(id) do
    case Agent.get(__MODULE__, &Map.fetch(&1.users, id)) do
      {:ok, user} -> {:ok, user}
      :error -> {:error, :not_found}
    end
  end

  def create(attrs) do
    Agent.get_and_update(__MODULE__, fn state ->
      user = struct(User, Map.put(attrs, :id, state.next_id))
      {user, %{users: Map.put(state.users, user.id, user), next_id: state.next_id + 1}}
    end)
  end

  def update(id, attrs) do
    Agent.get_and_update(__MODULE__, fn state ->
      if Map.has_key?(state.users, id) do
        user = struct(User, Map.put(attrs, :id, id))
        {{:ok, user}, put_in(state.users[id], user)}
      else
        {{:error, :not_found}, state}
      end
    end)
  end

  def delete(id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.pop(state.users, id) do
        {nil, _} -> {{:error, :not_found}, state}
        {_user, users} -> {:ok, %{state | users: users}}
      end
    end)
  end
end
