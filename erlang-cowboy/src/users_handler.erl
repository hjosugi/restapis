%% users リソースの CRUD（素の cowboy_handler）。
%% State はルート定義で渡したアトム（collection = /users、item = /users/:id、not_found = その他）。
-module(users_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, Route) ->
    Req = handle(cowboy_req:method(Req0), Route, Req0),
    {ok, Req, Route}.

%% GET /users?name=al&min_age=20
handle(~"GET", collection, Req) ->
    %% クエリパラメータ: min_age は int 制約で整数に変換（失敗すると例外）
    try cowboy_req:match_qs([{name, [], ~""}, {min_age, int, undefined}], Req) of
        #{name := Name, min_age := MinAge} ->
            reply(200, users_store:list(Name, MinAge), Req)
    catch
        exit:{request_error, {match_qs, _}, _} ->
            error_reply(400, ~"min_age must be an integer", Req)
    end;
%% POST /users → 201
handle(~"POST", collection, Req0) ->
    case read_input(Req0) of
        {ok, Input, Req} -> reply(201, users_store:create(Input), Req);
        {error, Message, Req} -> error_reply(400, Message, Req)
    end;
%% GET /users/:id
handle(~"GET", item, Req) ->
    maybe
        {ok, Id} ?= path_id(Req),
        {ok, User} ?= users_store:get(Id),
        reply(200, User, Req)
    else
        {error, not_found} -> not_found(Req)
    end;
%% PUT /users/:id（全置換）
handle(~"PUT", item, Req0) ->
    maybe
        {ok, Id} ?= path_id(Req0),
        {ok, Input, Req} ?= read_input(Req0),
        {ok, User} ?= users_store:update(Id, Input),
        reply(200, User, Req)
    else
        {error, not_found} -> not_found(Req0);
        {error, Message, Req1} -> error_reply(400, Message, Req1)
    end;
%% DELETE /users/:id → 204（ボディなし）
handle(~"DELETE", item, Req) ->
    maybe
        {ok, Id} ?= path_id(Req),
        ok ?= users_store:delete(Id),
        cowboy_req:reply(204, Req)
    else
        {error, not_found} -> not_found(Req)
    end;
handle(_Method, not_found, Req) ->
    error_reply(404, ~"not found", Req);
handle(_Method, _Route, Req) ->
    error_reply(405, ~"method not allowed", Req).

%% /users/:id の id。数値でなければ「見つからない」扱い
path_id(Req) ->
    try
        {ok, binary_to_integer(cowboy_req:binding(id, Req))}
    catch
        error:badarg -> {error, not_found}
    end.

%% ボディを読んで JSON をデコードし、入力チェックする
read_input(Req0) ->
    {ok, Body, Req} = cowboy_req:read_body(Req0),
    try json:decode(Body) of
        Json -> validate(Json, Req)
    catch
        error:_ -> {error, ~"invalid JSON", Req}
    end.

%% name / email は空でない文字列、age は 0 以上の整数（文字列 "1" は不可）
validate(#{~"name" := Name, ~"email" := Email, ~"age" := Age}, Req) when
    is_binary(Name),
    Name =/= ~"",
    is_binary(Email),
    Email =/= ~"",
    is_integer(Age),
    Age >= 0
->
    {ok, #{name => Name, email => Email, age => Age}, Req};
validate(_Json, Req) ->
    {error, ~"name and email must be non-empty strings, age must be an integer >= 0", Req}.

not_found(Req) ->
    error_reply(404, ~"user not found", Req).

error_reply(Status, Message, Req) ->
    reply(Status, #{error => Message}, Req).

%% Erlang の値を JSON にして返す（OTP 標準の json モジュール）
reply(Status, Body, Req) ->
    cowboy_req:reply(Status, #{~"content-type" => ~"application/json"}, encode(Body), Req).

%% ユーザーは {"id", "name", "email", "age"} の順で出したいので、キーの並びを決めて
%% json:encode_key_value_list/2 で書き出す（map のままだとキーの順番は決まらない）
encode(Term) ->
    json:encode(Term, fun
        (#{id := _, name := _, email := _, age := _} = User, Encode) ->
            json:encode_key_value_list(
                [{K, maps:get(K, User)} || K <- [id, name, email, age]], Encode
            );
        (Other, Encode) ->
            json:encode_value(Other, Encode)
    end).
