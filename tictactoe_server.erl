-module(tictactoe_server).
-author('Randall Blake').

-export([listen/1]).

-define(TCP_OPTIONS, [binary, {packet, 0}, {active, false}, {reuseaddr, true}]).

listen(Port) ->
    {ok, LSocket} = gen_tcp:listen(Port, ?TCP_OPTIONS),
    accept(LSocket).

accept(LSocket) ->
    {ok, Socket1} = gen_tcp:accept(LSocket),
    {ok, Socket2} = gen_tcp:accept(LSocket),
    spawn(fun() -> loop(Socket1, Socket2) end),
    accept(LSocket).

loop(Socket1, Socket2) ->
    _ = rand:seed(exs1024),
    Ran = rand:uniform(2) - 1,
    loop(Socket1, Socket2, Ran, array:from_list([1,2,3,4,5,6,7,8,9])).

loop(Socket1, Socket2, Turn, State) ->
    if
        Turn rem 2 == 0 ->
            New_state = turn(Socket1, State, Turn),
            Winner = check_winner(New_state, x);
        Turn rem 2 == 1 ->
            New_state = turn(Socket2, State, Turn),
            Winner = check_winner(New_state, o)
    end,
    case Winner of
        x ->
            gen_tcp:send(Socket1, "You win\n"),
            gen_tcp:send(Socket2, "You lose\n"),
            gen_tcp:close(Socket1),
            gen_tcp:close(Socket2);
        o ->
            gen_tcp:send(Socket1, "You lose\n"),
            gen_tcp:send(Socket2, "You win\n"),
            gen_tcp:close(Socket1),
            gen_tcp:close(Socket2);
        null when Turn == 9 ->
            gen_tcp:send(Socket1, "Tie\n"),
            gen_tcp:send(Socket2, "Tie\n"),
            gen_tcp:close(Socket1),
            gen_tcp:close(Socket2);
        null when Turn < 9 ->
            loop(Socket1, Socket2, Turn + 1, New_state)
    end.

turn(Socket, State, Turn) ->
    gen_tcp:send(Socket, io_lib:format("~w | ~w | ~w~n", [array:get(0, State), array:get(1, State), array:get(2, State)])),
    gen_tcp:send(Socket, "---------\n"),
    gen_tcp:send(Socket, io_lib:format("~w | ~w | ~w~n", [array:get(3, State), array:get(4, State), array:get(5, State)])),
    gen_tcp:send(Socket, "---------\n"),
    gen_tcp:send(Socket, io_lib:format("~w | ~w | ~w~n", [array:get(6, State), array:get(7, State), array:get(8, State)])),
    gen_tcp:send(Socket, "Your turn: "),
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            Index = binary:at(Data, 0) - 49,
            At = array:get(Index, State),
            if
                Turn rem 2 == 0 ->
                    if
                        is_atom(At) orelse At == 32 ->
                            turn(Socket, State, Turn);
                        true ->
                            array:set(Index, x, State)
                    end;
                Turn rem 2 == 1 ->
                    if
                        is_atom(At) orelse At == 32 ->
                            turn(Socket, State, Turn);
                        true ->
                            array:set(Index, o, State)
                    end
            end;
        {error, closed} ->
            ok
    end.

check_winner(State, Player) ->
    Result =
        check_row(State, Player, {0, 1, 2}) orelse
        check_row(State, Player, {3, 4, 5}) orelse
        check_row(State, Player, {6, 7, 8}) orelse
        check_row(State, Player, {0, 3, 6}) orelse
        check_row(State, Player, {1, 4, 7}) orelse
        check_row(State, Player, {2, 5, 8}) orelse
        check_row(State, Player, {0, 4, 8}) orelse
        check_row(State, Player, {2, 4, 6}) orelse
        false,
    case Result of
        true -> Player;
        false -> null
    end.

check_row(State, Player, {First, Second, Third}) ->
    Row = {array:get(First, State), array:get(Second, State), array:get(Third, State)},
    case Row of
    {Player, Player, Player} ->
        true;
    _Else ->
        false
    end.
