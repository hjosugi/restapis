%% メモリ上のユーザー一覧（gen_server）。
%% 状態はこのプロセスだけが持ち、呼び出しは 1 件ずつ順に処理されるのでロックは要らない。
-module(users_store).
-behaviour(gen_server).

-export([start_link/0, list/2, get/1, create/1, update/2, delete/1]).
-export([init/1, handle_call/3, handle_cast/2]).

-type user() :: #{id := integer(), name := binary(), email := binary(), age := non_neg_integer()}.
-type input() :: #{name := binary(), email := binary(), age := non_neg_integer()}.
-export_type([user/0, input/0]).

%% --- API（呼び出し側のプロセスで動き、gen_server:call でストアに頼む）

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Name: 大文字小文字を無視した部分一致（<<>> なら条件なし）、MinAge: age >= MinAge（undefined なら条件なし）
-spec list(binary(), integer() | undefined) -> [user()].
list(Name, MinAge) -> gen_server:call(?MODULE, {list, Name, MinAge}).

-spec get(integer()) -> {ok, user()} | {error, not_found}.
get(Id) -> gen_server:call(?MODULE, {get, Id}).

-spec create(input()) -> user().
create(Input) -> gen_server:call(?MODULE, {create, Input}).

-spec update(integer(), input()) -> {ok, user()} | {error, not_found}.
update(Id, Input) -> gen_server:call(?MODULE, {update, Id, Input}).

-spec delete(integer()) -> ok | {error, not_found}.
delete(Id) -> gen_server:call(?MODULE, {delete, Id}).

%% --- gen_server コールバック（ストアのプロセスで動く）

init([]) ->
    Users = #{
        1 => #{id => 1, name => ~"Alice", email => ~"alice@example.com", age => 30},
        2 => #{id => 2, name => ~"Bob", email => ~"bob@example.com", age => 25}
    },
    {ok, #{users => Users, next_id => 3}}.

handle_call({list, Name, MinAge}, _From, #{users := Users} = State) ->
    Needle = string:casefold(Name),
    %% maps:iterator(_, ordered) で id 昇順に取り出しながら絞り込む
    Result = [
        U
     || _ := U <- maps:iterator(Users, ordered),
        string:find(string:casefold(maps:get(name, U)), Needle) =/= nomatch,
        MinAge =:= undefined orelse maps:get(age, U) >= MinAge
    ],
    {reply, Result, State};
handle_call({get, Id}, _From, #{users := Users} = State) ->
    case Users of
        #{Id := User} -> {reply, {ok, User}, State};
        #{} -> {reply, {error, not_found}, State}
    end;
handle_call({create, Input}, _From, #{users := Users, next_id := Id} = State) ->
    User = Input#{id => Id},
    {reply, User, State#{users := Users#{Id => User}, next_id := Id + 1}};
handle_call({update, Id, Input}, _From, #{users := Users} = State) ->
    case Users of
        #{Id := _} ->
            User = Input#{id => Id},
            {reply, {ok, User}, State#{users := Users#{Id := User}}};
        #{} ->
            {reply, {error, not_found}, State}
    end;
handle_call({delete, Id}, _From, #{users := Users} = State) ->
    case maps:take(Id, Users) of
        {_, Rest} -> {reply, ok, State#{users := Rest}};
        error -> {reply, {error, not_found}, State}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.
