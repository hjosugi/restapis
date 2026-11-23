defmodule Mix.Tasks.Client do
  @shortdoc "REST API に CRUD + 検索を一通り投げるクライアント（Req）"
  @moduledoc """
  `mix client` で実行する。接続先は `API_URL`（既定 http://127.0.0.1:8011）。
  """
  use Mix.Task

  # レスポンスのデコード先
  defmodule User do
    @moduledoc false
    defstruct [:id, :name, :email, :age]
  end

  # リクエストボディ。JSON のキーをこの順で出す
  defmodule UserInput do
    @moduledoc false
    @derive {JSON.Encoder, only: [:name, :email, :age]}
    defstruct [:name, :email, :age]
  end

  # 設定を読むだけで、サーバー（UsersApi.Application）は起動しない
  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:req)

    # decode_body: false で生のボディを受け取り、表示してから自分でデコードする
    req =
      Req.new(
        base_url: System.get_env("API_URL", "http://127.0.0.1:8011"),
        retry: false,
        decode_body: false
      )

    IO.puts("--- 1. 一覧取得")
    call(req, :get, "/users")

    IO.puts("--- 2. 作成")
    carol = %UserInput{name: "Carol", email: "carol@example.com", age: 35}
    created = req |> call(:post, "/users", carol) |> to_user()
    path = "/users/#{created.id}"

    IO.puts("--- 3. 1件取得")
    call(req, :get, path)

    IO.puts("--- 4. 更新")
    call(req, :put, path, %UserInput{name: "Carol Smith", email: "carol@example.com", age: 36})

    IO.puts("--- 5. 検索（名前の部分一致）")
    call(req, :get, "/users?" <> URI.encode_query(name: "car"))

    IO.puts("--- 6. 検索（年齢の下限）")
    call(req, :get, "/users?" <> URI.encode_query(min_age: 30))

    IO.puts("--- 7. 削除")
    call(req, :delete, path)

    IO.puts("--- 8. 削除されたことを確認（404 になる）")
    call(req, :get, path)
  end

  # リクエストを 1 本送り、送った内容と返ってきた内容を表示してボディを返す
  defp call(req, method, path, input \\ nil) do
    method_name = method |> Atom.to_string() |> String.upcase()

    opts =
      if input do
        json = JSON.encode!(input)
        IO.puts("> #{method_name} #{path} #{json}")
        [body: json, headers: [content_type: "application/json"]]
      else
        IO.puts("> #{method_name} #{path}")
        []
      end

    case Req.request(req, [method: method, url: path] ++ opts) do
      {:ok, resp} ->
        IO.puts("< #{resp.status} #{resp.body}\n")
        resp.body

      {:error, exception} ->
        Mix.raise("リクエスト失敗（サーバーは起動していますか？）: " <> Exception.message(exception))
    end
  end

  # JSON 文字列 → %User{}
  defp to_user(body) do
    map = JSON.decode!(body)
    %User{id: map["id"], name: map["name"], email: map["email"], age: map["age"]}
  end
end
