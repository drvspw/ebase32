%%-------------------------------------------------------------------------------------------
%% Copyright (c) 2020 Venkatakumar Srinivasan
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% @author Venkatakumar Srinivasan
%% @since February 13, 2020
%%
%%-------------------------------------------------------------------------------------------
-module(ebase32).

%% API exports
-export([
         encode/1,
         encode/2,
         decode/1
        ]).

%%====================================================================
%% API functions
%%====================================================================
encode(Data) ->
  encode(Data, []).

encode(Data, Options) when is_list(Data) ->
  Base32 = encode(list_to_binary(Data), Options),
  binary_to_list(Base32);

encode(Data, Options) when is_binary(Data) ->
  Offset = 5 * (byte_size(Data) div 5),
  <<Block:Offset/binary, Rest/binary>> = Data,
  encode( fun enc/1, Block, Rest, Options );

encode(_, _) ->
  erlang:error(badarg).

decode(Base32) when is_list(Base32) ->
  Data = decode( list_to_binary(Base32) ),
  binary_to_list(Data);

decode(Base32) when is_binary(Base32) ->
  decode_block( fun dec/1, Base32, <<>>);

decode(_) ->
  erlang:error(badarg).


%%====================================================================
%% Internal functions
%%====================================================================
encode(Fun, Block, Rest, Options) ->
  %% encode block
  Enc1 = encode_block(Fun, Block),

  %% group Rest into 5 bits
  Offset = 5 * (bit_size(Rest) div 5),
  <<RestBlock:Offset/bits, LastBits/bits>> = Rest,

  %% encode RestBlock
  Enc2 = encode_block(Fun, RestBlock),

  %% Encode LastBits
  Enc3 = encode_last(Fun, LastBits, Options),

  %% return base32 encoding
  <<Enc1/binary, Enc2/binary, Enc3/binary>>.

encode_last(Fun, <<I:3>>, Options) ->
  encode_last(Fun, <<(I bsl 2)>>, 6, Options);

encode_last(Fun, <<I:1>>, Options) ->
  encode_last(Fun, <<(I bsl 4)>>, 4, Options);

encode_last(Fun, <<I:4>>, Options) ->
  encode_last(Fun, <<(I bsl 1)>>, 3, Options);

encode_last(Fun, <<I:2>>, Options) ->
  encode_last(Fun, <<(I bsl 3)>>, 1, Options);

encode_last(_, <<>>, _) ->
  <<>>.

encode_last(Fun, <<I>>, N, Options) ->
  Enc = <<(Fun(I))>>,
  Padding = padding(N, Options),
  <<Enc/binary, Padding/binary>>.


padding(N, [pad]) ->
  binary:copy(<<$=>>, N);

padding(_, _) ->
  <<>>.

encode_block(Fun, Block) ->
  << <<(Fun(I))>> || <<I:5>> <= Block >>.

enc(I) when is_integer(I) andalso I >= 26 andalso I =< 31 ->
  I + 24;

enc(I) when is_integer(I) andalso I >= 0 andalso I =< 25 ->
  I + $A.

decode_block(Fun, <<I, "======">>, Acc) ->
  <<Acc/bits, (Fun(I) bsr 2):3>>;

decode_block(Fun, <<I, "====">>, Acc) ->
  <<Acc/bits, (Fun(I) bsr 4):1>>;

decode_block(Fun, <<I, "===">>, Acc) ->
  <<Acc/bits, (Fun(I) bsr 1):4>>;

decode_block(Fun, <<I, "=">>, Acc) ->
  <<Acc/bits, (Fun(I) bsr 3):2>>;

decode_block(Fun, <<I>>, Acc) ->
  Size = bit_size(Acc),
  Req = (((Size div 8) + 1) * 8) - Size,
  Shift = 5 - Req,
  <<Acc/bits, (Fun(I) bsr Shift):Req>>;

decode_block(Fun, <<I, Rest/binary>>, Acc) ->
  decode_block(Fun, Rest, <<Acc/bits, (Fun(I)):5>>);

decode_block(_Fun, <<>>, Acc) ->
  Acc.

dec(I) when I >= $2 andalso I =< $7 ->
  I - 24;

dec(I) when I >= $A andalso I =< $Z ->
  I - $A.

%%=========================================================================
%% Unit Test Suite
%%=========================================================================
-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

encode_suite_test_() ->
  [
   ?_assertEqual(<<"MZXW6YTBOI">>, ebase32:encode(<<"foobar">>)),
   ?_assertEqual(<<>>, ebase32:encode(<<>>)),
   ?_assertEqual("MZXW6YTBOI", ebase32:encode("foobar")),
   ?_assertEqual("MFRA", ebase32:encode("ab")),
   ?_assertEqual("MFRGG", ebase32:encode("abc")),
   ?_assertEqual("MFRGGZA", ebase32:encode("abcd")),
   ?_assertEqual("MFRGGZDF", ebase32:encode("abcde")),
   ?_assertEqual("", ebase32:encode(""))
  ].

encode_padding_suite_test_() ->
  [
   ?_assertEqual(<<"MZXW6YTBOI======">>, ebase32:encode(<<"foobar">>, [pad])),
   ?_assertEqual(<<>>, ebase32:encode(<<>>, [pad])),
   ?_assertEqual("MZXW6YTBOI======", ebase32:encode("foobar", [pad])),
   ?_assertEqual("MFRA====", ebase32:encode("ab", [pad])),
   ?_assertEqual("MFRGG===", ebase32:encode("abc", [pad])),
   ?_assertEqual("MFRGGZA=", ebase32:encode("abcd", [pad])),
   ?_assertEqual("MFRGGZDF", ebase32:encode("abcde", [pad])),
   ?_assertEqual("", ebase32:encode("", [pad]))
  ].

decode_suite_test_() ->
  [
   ?_assertEqual(<<"foobar">>, ebase32:decode(<<"MZXW6YTBOI">>)),
   ?_assertEqual(<<"">>, ebase32:decode(<<>>)),
   ?_assertEqual("foobar", ebase32:decode("MZXW6YTBOI")),
   ?_assertEqual("ab", ebase32:decode("MFRA")),
   ?_assertEqual("abc", ebase32:decode("MFRGG")),
   ?_assertEqual("abcd", ebase32:decode("MFRGGZA")),
   ?_assertEqual("abcde", ebase32:decode("MFRGGZDF")),
   ?_assertEqual("", ebase32:decode(""))
  ].

decode_padding_suite_test_() ->
  [
   ?_assertEqual(<<"foobar">>, ebase32:decode(<<"MZXW6YTBOI======">>)),
   ?_assertEqual("foobar", ebase32:decode("MZXW6YTBOI======")),
   ?_assertEqual("ab", ebase32:decode("MFRA====")),
   ?_assertEqual("abc", ebase32:decode("MFRGG===")),
   ?_assertEqual("abcd", ebase32:decode("MFRGGZA="))
  ].

badarg_suite_test_() ->
  [
   ?_assertError(badarg, ebase32:encode(abc)),
   ?_assertError(badarg, ebase32:encode(abc, [pad])),
   ?_assertError(badarg, ebase32:decode(abc))
  ].

-endif.
