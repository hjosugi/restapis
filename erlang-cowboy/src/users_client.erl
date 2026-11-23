%% REST API に CRUD + 検索を一通り投げるクライアント（OTP 標準の httpc + json のみ）。
%% 接続先は API_URL（既定 http://127.0.0.1:8012）。
-module(users_client).

-export([main/0]).

%% レスポンスのデコード先
-record(user, {id :: integer(), name :: binary(), email :: binary(), age :: integer()}).

main() ->
    %% httpc は inets アプリケーションの一部なので先に起動する
    {ok, _} = application:ensure_all_started(inets),

    io:format("--- 1. 一覧取得~n"),
    call(get, "/users"),

    io:format("--- 2. 作成~n"),
    Created = to_user(
        call(post, "/users", [{name, ~"Carol"}, {email, ~"carol@example.com"}, {age, 35}])
    ),
    Path = "/users/" ++ integer_to_list(Created#user.id),

    io:format("--- 3. 1件取得~n"),
    call(get, Path),

    io:format("--- 4. 更新~n"),
    call(put, Path, [{name, ~"Carol Smith"}, {email, ~"carol@example.com"}, {age, 36}]),

    io:format("--- 5. 検索（名前の部分一致）~n"),
    call(get, "/users?" ++ uri_string:compose_query([{"name", "car"}])),

    io:format("--- 6. 検索（年齢の下限）~n"),
    call(get, "/users?" ++ uri_string:compose_query([{"min_age", "30"}])),

    io:format("--- 7. 削除~n"),
    call(delete, Path),

    io:format("--- 8. 削除されたことを確認（404 になる）~n"),
    call(get, Path).

%% リクエストを 1 本送り、送った内容と返ってきた内容を表示してボディを返す
call(Method, Path) ->
    io:format("> ~s ~s~n", [method_name(Method), Path]),
    send(Method, {base_url() ++ Path, []}).

%% Input はキーの順番を保つため [{Key, Value}] で受け取り、JSON オブジェクトにする
call(Method, Path, Input) ->
    Json = json:encode(Input, fun
        ([{_, _} | _] = KeyValues, Encode) -> json:encode_key_value_list(KeyValues, Encode);
        (Other, Encode) -> json:encode_value(Other, Encode)
    end),
    io:format("> ~s ~s ~s~n", [method_name(Method), Path, Json]),
    send(Method, {base_url() ++ Path, [], "application/json", Json}).

send(Method, Request) ->
    %% body_format binary: ボディを文字列（リスト）ではなく binary で受け取る
    case httpc:request(Method, Request, [], [{body_format, binary}]) of
        {ok, {{_Version, Status, _Reason}, _Headers, Body}} ->
            io:format("< ~b ~s~n~n", [Status, Body]),
            Body;
        {error, Reason} ->
            io:format(standard_error, "リクエスト失敗（サーバーは起動していますか？）: ~p~n", [Reason]),
            halt(1)
    end.

%% JSON → #user{} レコード
to_user(Body) ->
    #{~"id" := Id, ~"name" := Name, ~"email" := Email, ~"age" := Age} = json:decode(Body),
    #user{id = Id, name = Name, email = Email, age = Age}.

method_name(Method) ->
    string:uppercase(atom_to_list(Method)).

base_url() ->
    os:getenv("API_URL", "http://127.0.0.1:8012").
