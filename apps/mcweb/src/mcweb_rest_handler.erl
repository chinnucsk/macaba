%%%-----------------------------------------------------------------------------
%%% @doc This module has few predefined handlers (init, handle and terminate)
%%% which are called by cowboy on incoming HTTP request.
%%% Serves HTML templates, and provides basic HTTP access to the board.
%%% Created: 2013-02-16 Dmytro Lytovchenko <kvakvs@yandex.ru>
%%%-----------------------------------------------------------------------------
-module(mcweb_rest_handler).

-export([ init/3
        , handle/2
        , terminate/3]).
-export([ macaba_handle_rest/3
        , macaba_handle_util_preview/3
        , macaba_handle_thread_manage/3
        ]).
%% -export([ chain_check_admin_login/2
%%         , chain_check_mod_login/2
%%         ]).

-include_lib("macaba/include/macaba_types.hrl").
-include_lib("mcweb/include/mcweb.hrl").

%%%-----------------------------------------------------------------------------
init({_Transport, http}, Req, [Mode]) ->
  {ok, Req, #mcb_html_state{
         mode = Mode
        }}.

-spec handle(cowboy_req:req(), mcweb:html_state()) ->
                {ok, cowboy_req:req(), mcweb:html_state()}.

handle(Req0, State0) ->
  mcweb:handle_helper(?MODULE, Req0, State0).

terminate(_Reason, _Req, _State) ->
  ok.

%%%-----------------------------------------------------------------------------
%% @doc /rest - entry point for REST calls
%%%-----------------------------------------------------------------------------
-spec macaba_handle_rest(Method :: binary(),
                         Req :: cowboy_req:req(),
                         State :: mcweb:html_state()) ->
                            mcweb:handler_return().

macaba_handle_rest(_Method, Req0, State0) ->
  mcweb:response_json(200, "{\"result\":\"ok\"}", Req0, State0).

%%%-----------------------------------------------------------------------------
%%% Utility: Preview markup
%%%-----------------------------------------------------------------------------
-spec macaba_handle_util_preview(Method :: binary(),
                                 Req :: cowboy_req:req(),
                                 State :: mcweb:html_state()) ->
                                    mcweb:handler_return().

macaba_handle_util_preview(<<"POST">>, Req0, State0) ->
  lager:debug("http POST util/preview"),
  PD = State0#mcb_html_state.post_data,
  Message = macaba:propget(<<"markup">>, PD, <<>>),
  MessageProcessed = macaba_plugins:call(markup, [Message]),
  ReplyJson = [{html, iolist_to_binary(MessageProcessed)}],
  mcweb:response_json(200, ReplyJson, Req0, State0).

%%%-----------------------------------------------------------------------------
%%% Thread manage
%%%-----------------------------------------------------------------------------
-spec macaba_handle_thread_manage(Method :: binary(),
                                  Req :: cowboy_req:req(),
                                  State :: mcweb:html_state()) ->
                                     mcweb:handler_return().

macaba_handle_thread_manage(<<"POST">>, Req0, State0) ->
  lager:debug("http POST /rest/thread/manage"),
  {_, Req, State} = mcweb:chain_run(
                        [ fun mcweb:chain_fail_if_below_admin/2
                        , fun chain_thread_manage_do/2
                        ], Req0, State0),
  {Req, State}.

chain_thread_manage_do(Req0, State0) ->
  {_BoardId, Req1} = cowboy_req:binding(mcb_board, Req0),
  {_ThreadId, Req2} = cowboy_req:binding(mcb_thread, Req1),

  ReplyJson = [{result, "ok"}],
  mcweb:response_json(200, ReplyJson, Req2, State0).

%%%-----------------------------------------------------------------------------
%%% HELPER FUNCTIONS
%%%-----------------------------------------------------------------------------


%%% Local Variables:
%%% erlang-indent-level: 2
%%% End: