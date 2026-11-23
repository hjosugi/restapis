%% トップの supervisor。ストア（users_store）が落ちたら再起動する。
-module(users_api_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Store = #{id => users_store, start => {users_store, start_link, []}},
    {ok, {#{strategy => one_for_one}, [Store]}}.
