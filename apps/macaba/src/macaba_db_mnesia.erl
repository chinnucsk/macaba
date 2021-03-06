%%%------------------------------------------------------------------------
%%% @doc Database layer for using Mnesia as distributed storage
%%% We only use mnesia for operations which require transactions and locking,
%%% that's thread counters. Other data is stored in RIAK (see macaba_db_riak)
%%% Created: 2013-02-19 Dmytro Lytovchenko <kvakvs@yandex.ru>
%%%------------------------------------------------------------------------
-module(macaba_db_mnesia).

-export([ start/0
        , read/2
        , update/3
        , write/2
        , delete/2
        ]).

-include_lib("macaba/include/macaba_types.hrl").

%%--------------------------------------------------------------------
%% @doc Prepare database for use
start() ->
  lager:info("macaba_db_mnesia: starting"),
  {ok, Nodes0} = macaba_conf:get_or_fatal([<<"cluster">>, <<"nodes">>]),
  Nodes = lists:map(fun(X) -> erlang:binary_to_atom(X, latin1) end, Nodes0),
  CS = mnesia:create_schema(Nodes),
  lager:debug("create schema: ~p", [CS]),
  macaba:ensure_started(mnesia),
  BD = mnesia:create_table(
         mcb_board_dynamic,
         [ {ram_copies, [node()]}
         , {attributes, record_info(fields, mcb_board_dynamic)}
         , {type, set}
         ]),
  lager:info("creating board-dynamics table: ~p", [BD]),
  TD = mnesia:create_table(
         mcb_thread_dynamic,
         [ {ram_copies, [node()]}
         , {attributes, record_info(fields, mcb_thread_dynamic)}
         , {type, set}
         ]),
  lager:info("creating thread-dynamics table: ~p", [TD]),
  SC = mnesia:create_table(
         mcb_site_config,
         [ {ram_copies, [node()]}
         , {attributes, record_info(fields, mcb_site_config)}
         , {type, set}
         ]),
  lager:info("creating site-config table: ~p", [SC]).

%%--------------------------------------------------------------------
-spec read(Type :: macaba_mnesia_object(),
           Key  :: binary()) ->
              {ok, macaba_mnesia_record()} | {error, not_found}.

read(Tab, Key) when is_binary(Key) ->
  RFun = fun() -> mnesia:read({Tab, Key}) end,
  case mnesia:transaction(RFun) of
    {atomic, [Row]} ->
      {ok, Row};
    _ ->
      {error, not_found}
  end.

%%--------------------------------------------------------------------
-spec write(Type :: macaba_mnesia_object(),
            Value :: macaba_mnesia_record()) ->
               {atomic, any()} | {error, any()}.
write(Tab, Value) ->
  WF = fun() -> mnesia:write(Value) end,
  case mnesia:transaction(WF) of
    {atomic, _} = X ->
      Key = macaba_db:get_key_for_object(Value),
      gen_leader:leader_call(macaba_masternode, {updated_in_mnesia, Tab, Key}),
      X;
    Y ->
      lager:error("mnesia: write ~p:", [Y]),
      Y
  end.

%%--------------------------------------------------------------------
%% @doc Start transaction, read, do Fun(Object), write, return new value. If
%% object was not found, Fun is called with Fun({error, not_found))
%% if it didn't crash, return value is written to database
-spec update(Tab :: atom(), Key :: binary(), Fun :: fun()) ->
                {atomic, any()} | {error, any()}.
update(Tab, Key, Fun) when is_binary(Key) ->
  UF = fun() ->
           case mnesia:read(Tab, Key, read) of
             [Object1] ->
               Object = Fun(Object1),
               mnesia:write(Object),
               Object;
             [] ->
               Object = Fun({error, not_found}),
               mnesia:write(Object),
               Object
           end
       end,
  case mnesia:transaction(UF) of
    {atomic, _} = X ->
      gen_leader:leader_call(macaba_masternode, {updated_in_mnesia, Tab, Key}),
      X;
    Y ->
      lager:error("macaba_db_mnesia: update ~p:", [Y]),
      Y
  end.

%%--------------------------------------------------------------------
delete(Tab, Key) when is_binary(Key) ->
  DF = fun() ->
           mnesia:delete(Tab, Key, write)
       end,
  case mnesia:transaction(DF) of
    {atomic, _} = X ->
      gen_leader:leader_call(macaba_masternode, {updated_in_mnesia, Tab, Key}),
      X;
    Y ->
      lager:error("macaba_db_mnesia: delete ~p:", [Y]),
      Y
  end.

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
