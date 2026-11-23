%% OTP アプリケーション。ストアを supervisor で起動してから、Cowboy の HTTP リスナーを立てる。
-module(users_api_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    {ok, Sup} = users_api_sup:start_link(),
    %% ルート定義: パス → ハンドラモジュール + 初期 State（どのルートかを handler に渡す）
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/users", users_handler, collection},
            {"/users/:id", users_handler, item},
            %% それ以外のパスも {"error": ...} の 404 にする
            {"/[...]", users_handler, not_found}
        ]}
    ]),
    Port = list_to_integer(os:getenv("PORT", "8012")),
    {ok, _} = cowboy:start_clear(
        users_http,
        [{ip, {127, 0, 0, 1}}, {port, Port}],
        #{env => #{dispatch => Dispatch}}
    ),
    logger:notice("listening on http://127.0.0.1:~b", [Port]),
    {ok, Sup}.

stop(_State) ->
    cowboy:stop_listener(users_http).
