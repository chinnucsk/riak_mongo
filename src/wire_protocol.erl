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

%% @author Pavlo Baron <pbat pbit dot org>
%% @doc This is the implementiation of the Mongo Wire protocol
%% @copyright 2012 Pavlo Baron

-module(wire_protocol).

-export([process_packet/2]).

-include_lib ("bson/include/bson_binary.hrl").

-define(MSG(OP), <<?get_int32(ID),
		   ?get_int32(_ResponseTo),
                   ?get_int32(OP), Rest/binary>>).

-define(OP_REPLY, 1).
-define(OP_INSERT, 2002).
-define(OP_QUERY, 2004).

-define(CMD, <<_Flags:32, "admin.$cmd", 0:8, _N1:32, _N2:32, Rest/binary>>).
-define(INSERT, <<_Flags:32, Rest/binary>>).
-define(QUERY, <<_Flags:32, Rest/binary>>).

-define(REPLY(I, T, OP, F, C, S, N, D), <<I:32/little, T:32/little,
					   OP:32/little, F:32/little, C:64/little,
					   S:32/little, N:32/little, D/binary>>).

process_packet(Sock, ?MSG(?OP_QUERY)) ->
    process_query(Sock, ID, Rest);

process_packet(Sock, ?MSG(?OP_INSERT)) ->
    process_insert(Sock, ID, Rest);

process_packet(Sock, _) ->
    reply_error(Sock, 0, "unsupported message").

process_insert(_Sock, _ID, ?INSERT) ->
    {Collection, Documents} = bson_binary:get_cstring(Rest),
    process_insert_loop(Collection, Documents);

process_insert(Sock, _, _) ->
    reply_error(Sock, 0, "unsupported insert").

process_insert_loop(_Collection, <<>>) ->
    ok;
process_insert_loop(Collection, Documents) ->
    {Document, Rest} = bson_binary:get_document(Documents),
    riak_mongo_logic:insert(Collection, Document),
    process_insert_loop(Collection, Rest).


process_query(Sock, ID, ?CMD) ->
    process_cmd(Sock, ID, bson_binary:get_document(Rest));

process_query(Sock, ID, ?QUERY) ->
    [Collection, B|_] = binary:split(Rest, <<0:8>>),
    <<_N1:32, NumberToReturn:32/little-signed, Query/binary>> = B,
    Value = riak_mongo_logic:find(Collection, NumberToReturn, Query),
    case Value of
	unsupported -> reply_error(Sock, ID, "unsuppoted query");
	Value -> reply(Sock, ID, Value)
    end;

process_query(Sock, _, _) ->
    reply_error(Sock, 0, "unsupported query").

process_cmd(Sock, ID, {{whatsmyuri, 1}, _}) ->
    You = riak_mongo_logic:you(inet:peername(Sock)),
    reply(Sock, ID, {you, list_to_binary(You), ok, 1});

process_cmd(Sock, ID, {{replSetGetStatus, 1, forShell, 1}, _}) ->
    reply_error(Sock, ID, "not running with --replSet");

process_cmd(Sock, _, _) ->
    reply_error(Sock, 0, "unsupported command").

reply(Sock, ID, T) ->
    Res = bson_binary:put_document(T),
    riak_mongo_server:send_packet(Sock, ?REPLY(ID, ID, ?OP_REPLY, 8, 0, 0, 1, Res)).

reply_error(Sock, ID, S) ->
    T = {errmsg, list_to_binary(S), ok, 0},
    reply(Sock, ID, T).