defmodule UsersApiWeb.Router do
  @moduledoc "ルート定義。`resources \"/users\", UserController, only: [...]` と書いても同じ（PATCH も増える）。"
  use Phoenix.Router, helpers: false

  scope "/", UsersApiWeb do
    get "/users", UserController, :index
    get "/users/:id", UserController, :show
    post "/users", UserController, :create
    put "/users/:id", UserController, :update
    delete "/users/:id", UserController, :delete
  end
end
