-module(riak_search_op_term).
-export([
         preplan_op/2,
         chain_op/3
        ]).

-include("riak_search.hrl").

%% This is a stub for debugging purposes. This generates data by
%% taking the search term and splitting it into characters, which
%% makes it easy to write test queries.
%%
%% For example, the word 'fat' is in documents 'f', 'a', and 't'. The
%% document 'cat' is in 'c', 'a', and 't'. So if you search for 'fat
%% AND cat', then you should get the documents 'a' and 't' in the
%% result.

preplan_op(Op, _F) -> Op.

chain_op(Op, OutputPid, OutputRef) ->
    String = Op#term.string,
    Facets = proplists:get_all_values(facets, Op#term.options),
    DEBUG = false,
    case DEBUG of
        true ->
            spawn(fun() -> send_results(String, OutputPid, OutputRef) end);
        false ->
            spawn(fun() -> start_loop(String, Facets, OutputPid, OutputRef) end)
    end,
    {ok, 1}.

send_results(String, OutputPid, OutputRef) ->
    Term1 = lists:nth(3, string:tokens(String, ".")),
    Term2 = lists:sort(Term1),
    [OutputPid!{results, [X], OutputRef} || X <- Term2],
    OutputPid!{disconnect, OutputRef}.

start_loop(String, Facets, OutputPid, OutputRef) ->
    [Index, Field, Term] = string:tokens(String, "."),

    %% Stream the results...
    Fun = fun(_Value, Props) ->
        riak_search_facets:passes_facets(Props, Facets)
    end,
    {ok, Ref} = riak_search:stream(Index, Field, Term, Fun),

    %% Gather the results...
    loop(Ref, OutputPid, OutputRef).

loop(Ref, OutputPid, OutputRef) ->
    receive 
        {result, '$end_of_table', Ref} ->
            OutputPid!{disconnect, OutputRef};

        {result, {Key, Props}, Ref} ->
            OutputPid!{results, [{Key, Props}], OutputRef},
            loop(Ref, OutputPid, OutputRef)
    end.
