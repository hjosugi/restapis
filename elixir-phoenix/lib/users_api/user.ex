defmodule UsersApi.User do
  @moduledoc "API で扱うリソース。`@derive JSON.Encoder` で Elixir 標準の JSON モジュールがそのまま JSON にできる。"
  @derive JSON.Encoder
  defstruct [:id, :name, :email, :age]
end
