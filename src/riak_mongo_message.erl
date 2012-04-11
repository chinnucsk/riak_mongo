%%
%% This file is part of riak_mongo
%%
%% Copyright (c) 2012 by Pavlo Baron (pb at pbit dot org)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%

%% @author Pavlo Baron <pb at pbit dot org>
%% @doc Here we process all kind of messages
%% @copyright 2012 Pavlo Baron

-module(riak_mongo_message).

-export([process_message/2]).

-include ("riak_mongo_protocol.hrl").
-include_lib("riak_mongo_state.hrl").

process_message(#mongo_query{ dbcoll= <<"admin.$cmd">>, selector={whatsmyuri, 1}}, State) ->
    {reply, #mongo_reply{ documents=[{binary_to_atom(iolist_to_binary(you(State)), utf8), 1}]}, State};

process_message(#mongo_query{ dbcoll= <<"admin.$cmd">>, selector={replSetGetStatus, 1, forShell, 1}}, State) ->
    {reply, #mongo_reply{ documents=[{binary_to_atom(iolist_to_binary("not running with --replSet"),
						     utf8), 1}]}, State};

process_message(#mongo_query{}=Message, State) ->
    error_logger:info_msg("unhandled query: ~p~n", [Message]),
    {reply, #mongo_reply{ queryerror=true }, State};

process_message(Message, State) ->
    error_logger:info_msg("unhandled message: ~p~n", [Message]),
    {noreply, State}.

%% internals
you(#state{peer=Peer}) ->
    {ok, {{A, B, C, D}, P}} = Peer, %IPv6???
    io_lib:format("~p.~p.~p.~p:~p", [A, B, C, D, P]).