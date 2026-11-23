defmodule UsersApiWeb.ErrorJSON do
  @moduledoc """
  コントローラーに届く前の例外を `{"error": ...}` にする（config.exs の render_errors で指定）。

  壊れた JSON（Plug.Parsers.ParseError）→ 400、存在しないルート → 404、それ以外 → 500 など。
  """

  def render("400.json", %{reason: %Plug.Parsers.ParseError{}}), do: %{error: "invalid JSON"}

  # "404.json" → "Not Found" のようにステータスの説明文を返す
  def render(template, _assigns) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end
end
