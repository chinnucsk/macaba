-module(mcbd_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    VMaster = { mcbd_vnode_master,
                  {riak_core_vnode_master, start_link, [mcbd_vnode]},
                  permanent, 5000, worker, [riak_core_vnode_master]},

    WriteFSM = {mcbd_write_fsm_sup,
                {mcbd_write_fsm_sup, start_link, []},
                permanent, infinity, supervisor, [mcbd_write_fsm_sup]},

    ReadFSM = {mcbd_read_fsm_sup,
               {mcbd_read_fsm_sup, start_link, []},
               permanent, infinity, supervisor, [mcbd_read_fsm_sup]},
    
    { ok,
        { {one_for_one, 5, 10},
          [VMaster, WriteFSM, ReadFSM]}}.

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End: