-module(cth_styledout).
-behaviour(gen_server).

%% Commont Test hooks.

-export([id/1, init/2]).

-export([pre_init_per_suite/3]).
-export([post_init_per_suite/4]).
-export([pre_end_per_suite/3]).
-export([post_end_per_suite/4]).

-export([pre_init_per_group/3]).
-export([post_init_per_group/4]).
-export([pre_end_per_group/3]).
-export([post_end_per_group/4]).

-export([pre_init_per_testcase/3]).
-export([post_init_per_testcase/4]).
-export([pre_end_per_testcase/3]).
-export([post_end_per_testcase/4]).

%-export([on_tc_fail/3]).
%-export([on_tc_skip/3]).

-export([terminate/1]).

-include_lib("common_test/include/ct.hrl").

%% gen_server callbacks.
-export(
   [
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
   ]).

-define(def_gl, ct_default_gl).

-record(state, {
          nodes = [],
          group_leader_for = []
         }).

-record(suite, {
          name,
          line,
          init_end_return,
          pre_init_time,
          post_init_time,
          pre_end_time,
          post_end_time
         }).

-record(group, {
          path,
          name,
          line,
          init_end_return,
          total_runs = 1,
          pre_init_time,
          post_init_time,
          pre_end_time,
          post_end_time
         }).

-record(test, {
          path,
          name,
          line,
          result,
          total_runs = 1,
          runs = []
         }).

-record(run, {
          index,
          return,
          result,
          pre_init_time,
          post_init_time,
          pre_end_time,
          post_end_time
         }).

-define(SUITE_HEADER_LINES, 2).
-define(SUITE_FOOTER_LINES, 1).
-define(GROUP_HEADER_LINES, 1).
-define(GROUP_FOOTER_LINES, 1).
-define(TEST_LINES, 1).

id(_) ->
    ?MODULE.

init(_, _) ->
    case can_intercept_messages() of
        true ->
            application:set_env(lager, handlers, [{lager_console_backend, []}]),
            stop_initial_ct_group_leader(),
            case start_server() of
                {ok, Pid} ->
                    become_group_leader(Pid, whereis(test_server_io)),
                    {ok, Pid};
                {error, {already_started, Pid}} ->
                    {ok, Pid};
                _ ->
                    {ok, undefined}
            end;
        false ->
            {ok, undefined}
    end.

pre_init_per_suite(_SuiteName, InitData, undefined) ->
    {InitData, undefined};
pre_init_per_suite(SuiteName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_init_per_suite, SuiteName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_init_per_suite(_SuiteName, _Config, Return, undefined) ->
    {Return, undefined};
post_init_per_suite(SuiteName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_init_per_suite, SuiteName, Config, Return,
                     timestamp()}),
    {Return, Server}.

pre_end_per_suite(_SuiteName, InitData, undefined) ->
    {InitData, undefined};
pre_end_per_suite(SuiteName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_end_per_suite, SuiteName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_end_per_suite(_SuiteName, _Config, Return, undefined) ->
    {Return, undefined};
post_end_per_suite(SuiteName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_end_per_suite, SuiteName, Config, Return,
                     timestamp()}),
    {Return, Server}.

pre_init_per_group(_GroupName, InitData, undefined) ->
    {InitData, undefined};
pre_init_per_group(GroupName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_init_per_group, GroupName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_init_per_group(_GroupName, _Config, Return, undefined) ->
    {Return, undefined};
post_init_per_group(GroupName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_init_per_group, GroupName, Config, Return,
                     timestamp()}),
    {Return, Server}.

pre_end_per_group(_GroupName, InitData, undefined) ->
    {InitData, undefined};
pre_end_per_group(GroupName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_end_per_group, GroupName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_end_per_group(_GroupName, _Config, Return, undefined) ->
    {Return, undefined};
post_end_per_group(GroupName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_end_per_group, GroupName, Config, Return,
                     timestamp()}),
    {Return, Server}.

pre_init_per_testcase(_TestcaseName, InitData, undefined) ->
    {InitData, undefined};
pre_init_per_testcase(TestcaseName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_init_per_testcase, TestcaseName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_init_per_testcase(_TestcaseName, _Config, Return, undefined) ->
    {Return, undefined};
post_init_per_testcase(TestcaseName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_init_per_testcase, TestcaseName, Config, Return,
                     timestamp()}),
    {Return, Server}.

pre_end_per_testcase(_TestcaseName, InitData, undefined) ->
    {InitData, undefined};
pre_end_per_testcase(TestcaseName, InitData, Server) ->
    gen_server:cast(Server,
                    {pre_end_per_testcase, TestcaseName, InitData,
                     timestamp()}),
    {InitData, Server}.

post_end_per_testcase(_TestcaseName, _Config, Return, undefined) ->
    {Return, undefined};
post_end_per_testcase(TestcaseName, Config, Return, Server) ->
    gen_server:cast(Server,
                    {post_end_per_testcase, TestcaseName, Config, Return,
                     timestamp()}),
    {Return, Server}.

terminate(undefined) ->
    ok;
terminate(Server) ->
    stop_server(Server),
    ok.

become_group_leader(Server, Pid) ->
    gen_server:call(Server, {become_group_leader, Pid}).

timestamp() ->
    erlang:monotonic_time().

%% -------------------------------------------------------------------
%% Group leader, impersonating ct_default_gl.
%% -------------------------------------------------------------------

start_server() ->
    gen_server:start({local, ?def_gl}, ?MODULE, [], []).

stop_server(Server) ->
    gen_server:cast(Server, stop).

init([]) ->
    start_watchdog(),
    _ = turn_off_error_logger_tty_h(),
    State = #state{},
    {ok, State}.

handle_call({become_group_leader, Pid}, _,
            #state{group_leader_for = Pids} = State) ->
    erlang:group_leader(self(), Pid),
    State1 = State#state{
               group_leader_for = [Pid | Pids]
              },
    {reply, ok, State1};

handle_call(_, _, State) ->
    {reply, ok, State}.

handle_cast({pre_init_per_suite, SuiteName, Config, Timestamp}, State)
  when is_list(Config) ->
    Suite = #suite{
               name = SuiteName,
               pre_init_time = Timestamp
              },
    State1 = insert_node(Suite, State),
    {noreply, State1};

handle_cast({post_init_per_suite, SuiteName, _Config, Return, Timestamp},
            State) ->
    Suite = get_node(SuiteName, State),
    Suite1 = Suite#suite{
               init_end_return = case return_to_result(Return) of
                                     success -> undefined;
                                     _       -> Return
                                 end,
               post_init_time = Timestamp
              },
    State1 = replace_node(Suite1, State),
    {noreply, State1};

handle_cast({pre_end_per_suite, SuiteName, _Config, Timestamp}, State) ->
    Suite = get_node(SuiteName, State),
    Suite1 = Suite#suite{
               pre_end_time = Timestamp
              },
    State1 = replace_node(Suite1, State),
    {noreply, State1};

handle_cast({post_end_per_suite, SuiteName, _Config, Return, Timestamp},
            State) ->
    Suite = get_node(SuiteName, State),
    Suite1 = Suite#suite{
               init_end_return = case return_to_result(Return) of
                                     success -> undefined;
                                     _       -> Return
                                 end,
               post_end_time = Timestamp
              },
    State1 = replace_node(Suite1, State),
    show_suite_summary(Suite1, State1),
    {noreply, State1};

handle_cast({pre_init_per_group, GroupName, Config, _}, State)
  when is_list(Config) ->
    {TotalRuns, GroupPath} = compute_group_path(GroupName, Config, State),
    State1 = case does_node_exist(#group{path = GroupPath}, State) of
                 false ->
                     Group = #group{
                                path = GroupPath,
                                name = GroupName,
                                total_runs = TotalRuns
                               },
                     insert_node(Group, State);
                 true ->
                     State
             end,
    {noreply, State1};

handle_cast({post_init_per_group, GroupName, _Config, Return, Timestamp},
            State) ->
    Group = get_node(GroupName, State),
    Group1 = Group#group{
               init_end_return = case return_to_result(Return) of
                                     success -> undefined;
                                     _       -> Return
                                 end,
               post_init_time = Timestamp
              },
    State1 = replace_node(Group1, State),
    {noreply, State1};

handle_cast({pre_end_per_group, GroupName, _Config, Timestamp}, State) ->
    Group = get_node(GroupName, State),
    Group1 = Group#group{
               pre_end_time = Timestamp
              },
    State1 = replace_node(Group1, State),
    {noreply, State1};

handle_cast({post_end_per_group, GroupName, _Config, Return, Timestamp},
            State) ->
    Group = get_node(GroupName, State),
    Group1 = Group#group{
               init_end_return = case return_to_result(Return) of
                                     success -> undefined;
                                     _       -> Return
                                 end,
               post_end_time = Timestamp
              },
    State1 = replace_node(Group1, State),
    {noreply, State1};

handle_cast({pre_init_per_testcase, TestcaseName, Config, Timestamp}, State)
  when is_list(Config) ->
    {RunIdx, TotalRuns, TestPath} = compute_test_run_path(
                                      TestcaseName, Config, State),
    Run = #run{
             index = RunIdx,
             pre_init_time = Timestamp
            },
    State1 = case get_node(TestPath, State) of
                 false ->
                     Test = #test{
                               path = TestPath,
                               name = TestcaseName,
                               total_runs = TotalRuns,
                               runs = [Run]
                              },
                     insert_node(Test, State);
                 Test ->
                     Test1 = Test#test{runs = [Run | Test#test.runs]},
                     replace_node(Test1, State)
             end,
    {noreply, State1};

handle_cast({post_init_per_testcase, TestcaseName, Config, Return, Timestamp},
            State) ->
    {RunIdx, _, TestPath} = compute_test_run_path(
                              TestcaseName, Config, State),
    Test = get_node(TestPath, State),
    Run = lists:keyfind(RunIdx, #run.index, Test#test.runs),
    Result = return_to_result(Return),
    Run1 = Run#run{
             result = Result,
             return = case Result of
                          success -> undefined;
                          _       -> Return
                      end,
             post_init_time = Timestamp
            },
    Test1 = Test#test{
              result = update_test_result(Test#test.result, Run1#run.result,
                                         all_runs_in_progress(Test)),
              runs = lists:keyreplace(RunIdx, #run.index, Test#test.runs,
                                      Run1)
             },
    State1 = replace_node(Test1, State),
    {noreply, State1};

handle_cast({pre_end_per_testcase, TestcaseName, Config, Timestamp}, State) ->
    {RunIdx, _, TestPath} = compute_test_run_path(
                              TestcaseName, Config, State),
    Test = get_node(TestPath, State),
    Run = lists:keyfind(RunIdx, #run.index, Test#test.runs),
    Run1 = Run#run{
             pre_end_time = Timestamp
            },
    Test1 = Test#test{
              runs = lists:keyreplace(RunIdx, #run.index, Test#test.runs,
                                      Run1)
             },
    State1 = replace_node(Test1, State),
    {noreply, State1};

handle_cast({post_end_per_testcase, TestcaseName, Config, Return, Timestamp},
            State) ->
    {RunIdx, _, TestPath} = compute_test_run_path(
                              TestcaseName, Config, State),
    Test = get_node(TestPath, State),
    Run = lists:keyfind(RunIdx, #run.index, Test#test.runs),
    Result = return_to_result(Return),
    Run1 = Run#run{
             result = Result,
             return = case Result of
                          success -> undefined;
                          _       -> Return
                      end,
             post_end_time = Timestamp
            },
    Test1 = Test#test{
              result = update_test_result(Test#test.result, Run1#run.result,
                                         all_runs_in_progress(Test)),
              runs = lists:keyreplace(RunIdx, #run.index, Test#test.runs,
                                      Run1)
             },
    State1 = replace_node(Test1, State),
    {noreply, State1};

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(_, State) ->
    {noreply, State}.

handle_info({io_request, _, _, _} = IoRequest, State) ->
    reply_to_io_request(IoRequest),
    {noreply, State};

handle_info(Info, State) ->
    io:format("Info: ~p~n", [Info]),
    {noreply, State}.

terminate(_, #state{group_leader_for = Pids} = State) ->
    show_final_report(State),
    ParentGroupLeader = group_leader(),
    [try
         group_leader(ParentGroupLeader, Pid)
     catch
         _:_ -> ok
     end
     || Pid <- Pids],
    flush_io_requests(),
    ok.

code_change(_, State, _) ->
    {ok, State}.

%% -------------------------------------------------------------------
%% Internal functions.
%% -------------------------------------------------------------------

can_intercept_messages() ->
    whereis(?def_gl) =/= undefined.

stop_initial_ct_group_leader() ->
    case whereis(?def_gl) of
        undefined ->
            ok;
        _ ->
            ct_default_gl:stop(),
            timer:sleep(200),
            stop_initial_ct_group_leader()
    end.

turn_off_error_logger_tty_h() ->
    error_logger:delete_report_handler(error_logger_tty_h).

start_watchdog() ->
    Server = self(),
    spawn_link(fun() -> watchdog(Server) end).

watchdog(Server) ->
    process_flag(trap_exit, true),
    receive
        {'EXIT', Server, normal} ->
            ok;
        {'EXIT', Server, Reason} ->
            io:format(standard_error,
                      "\e[1;31m/!\\ ~s crashed:\e[0m~n~p~n~n",
                      [?MODULE, Reason])
    end.

%% -------------------------------------------------------------------

get_path(#test{path = Path})  -> Path;
get_path(#group{path = Path}) -> Path;
get_path(#suite{name = Name}) -> Name.

is_node_under_path(Node, ParentPath) ->
    Path0 = get_path(Node),
    Path = case is_list(Path0) of
               true  -> Path0;
               false -> [Path0]
           end,
    Start = length(Path) - length(ParentPath) + 1,
    if
        Start >= 1 ->
            case lists:sublist(Path, Start, length(ParentPath)) of
                ParentPath -> true;
                _          -> false
            end;
        true ->
            false
    end.

compute_group_path(GroupName, Config, State) ->
    ConfigPath = ?config(tc_group_path, Config),
    ConfigProps = ?config(tc_group_properties, Config),
    ParentPath0 = [format_test_component(Component)
                   || Component <- ConfigPath],
    ParentPath = fix_path(ParentPath0, State),
    Path = [GroupName | ParentPath],
    TotalRuns = get_repeat(ConfigProps),
    {TotalRuns, Path}.

compute_test_run_path(TestcaseName, Config, State) ->
    ConfigPath = ?config(tc_group_path, Config),
    ConfigProps = ?config(tc_group_properties, Config),
    ParentPath0 = [format_test_component(Component)
                   || Component <- [ConfigProps | ConfigPath]],
    ParentPath = fix_path(ParentPath0, State),
    Path = [TestcaseName | ParentPath],
    TotalRuns = get_repeat(ConfigProps),
    RunIdx = compute_run_index([ConfigProps | ConfigPath],
                               get_node(ParentPath, State)),
    {RunIdx, TotalRuns, Path}.

format_test_component(Component) ->
    case proplists:get_value(suite, Component) of
        undefined -> proplists:get_value(name, Component);
        Name      -> Name
    end.

get_repeat(ConfigProps) ->
    case proplists:get_value(repeat, ConfigProps) of
        undefined -> 1;
        N         -> N
    end.

compute_run_index(_, false) ->
    1;
compute_run_index([Component | ConfigPath], ParentNode) ->
    Repeat = get_repeat(Component),
    LocalTotalRuns = get_total_runs(ParentNode),
    LocalRunIdx = LocalTotalRuns - Repeat,
    compute_run_index2(ConfigPath, LocalRunIdx, LocalTotalRuns).

compute_run_index2([], LocalRunIdx, ParentsRunIdx) ->
    ParentsRunIdx - LocalRunIdx;
compute_run_index2([Component | Rest], LocalRunIdx, ParentsRunIdx) ->
    Repeat = get_repeat(Component),
    compute_run_index2(Rest, LocalRunIdx, ParentsRunIdx * Repeat).

get_total_runs(#test{total_runs = TotalRuns})  -> TotalRuns;
get_total_runs(#group{total_runs = TotalRuns}) -> TotalRuns;
get_total_runs(#suite{})                       -> 1.

fix_path(Path, State) ->
    #suite{name = SuiteName} = get_current_suite(State),
    case Path of
        [] ->
            Path ++ [SuiteName];
        _ ->
            case lists:last(Path) of
                SuiteName -> Path;
                _         -> Path ++ [SuiteName]
            end
    end.

get_current_suite(#state{nodes = Nodes}) ->
    lists:keyfind(suite, 1, lists:reverse(Nodes)).

%% -------------------------------------------------------------------

get_node(Path, State) when is_list(Path) ->
    case get_node(#test{path = Path}, State) of
        false -> get_node(#group{path = Path}, State);
        Node  -> Node
    end;
get_node(Path, State) when is_atom(Path) ->
    get_node(#suite{name = Path}, State);
get_node(#test{path = Path}, #state{nodes = Nodes}) ->
    lists:keyfind(Path, #test.path, Nodes);
get_node(#group{path = Path}, #state{nodes = Nodes}) ->
    lists:keyfind(Path, #group.path, Nodes);
get_node(#suite{name = Name}, #state{nodes = Nodes}) ->
    lists:keyfind(Name, #suite.name, Nodes).

does_node_exist(Node, State) ->
    case get_node(Node, State) of
        OldNode when OldNode =/= false -> true;
        false                          -> false
    end.

insert_node(#test{path = Path} = Test, State) ->
    insert_as_last_child_of_parent(Test, Path, State);
insert_node(#group{path = Path} = Group, State) ->
    insert_as_last_child_of_parent(Group, Path, State);
insert_node(#suite{} = Suite, #state{nodes = Nodes} = State) ->
    Suite1 = case Nodes of
                 [] -> Suite#suite{line = 0};
                 _  -> set_line_based_on_previous(Suite, lists:last(Nodes))
             end,
    Nodes1 = Nodes ++ [Suite1],
    State1 = State#state{nodes = Nodes1},
    update_node_status_lines_starting_at(State1, Suite1#suite.name),
    State1.

insert_as_last_child_of_parent(Node, _, #state{nodes = []} = State) ->
    Node1 = set_line(Node, 0),
    State#state{
      nodes = [Node1]
     };
insert_as_last_child_of_parent(Node, NodePath, #state{nodes = Nodes} = State) ->
    ParentPath = tl(NodePath),
    {AccState, Nodes1} =
    lists:foldl(
      fun
          (#group{path = Path} = Group, {searching, AccNodes})
            when Path =:= ParentPath ->
              {parent_seen, [Group | AccNodes]};
          (#suite{name = Name} = Suite, {searching, AccNodes})
            when [Name] =:= ParentPath ->
              {parent_seen, [Suite | AccNodes]};

          (NextNode, {parent_seen = AccState, AccNodes}) ->
              case is_node_under_path(NextNode, ParentPath) of
                  true ->
                      {AccState, [NextNode | AccNodes]};
                  false ->
                      PreviousNode = hd(AccNodes),
                      Node1 = set_line_based_on_previous(Node, PreviousNode),
                      NextNode1 = set_line_based_on_previous(NextNode, Node1),
                      {inserted, [NextNode1, Node1 | AccNodes]}
              end;

          (OtherNode, {inserted = AccState, AccNodes}) ->
              PreviousNode = hd(AccNodes),
              OtherNode1 = set_line_based_on_previous(OtherNode, PreviousNode),
              {AccState, [OtherNode1 | AccNodes]};

          (OtherNode, {AccState, AccNodes}) ->
              {AccState, [OtherNode | AccNodes]}
      end,
      {searching, []}, Nodes),
    Nodes2 = case AccState of
                 inserted ->
                     Nodes1;
                 parent_seen ->
                     PreviousNode = hd(Nodes1),
                     Node1 = set_line_based_on_previous(
                               Node, PreviousNode),
                     [Node1 | Nodes1]
             end,
    Nodes3 = lists:reverse(Nodes2),
    State1 = State#state{nodes = Nodes3},
    update_node_status_lines_starting_at(State1, get_path(Node)),
    State1.

replace_node(#test{path = Path} = Node, #state{nodes = Nodes} = State) ->
    Nodes1 = lists:keyreplace(Path, #test.path, Nodes, Node),
    State1 = State#state{nodes = Nodes1},
    update_node_status_line(Node, State1),
    State1;
%replace_node(#group{path = Path} = Node, #state{nodes = Nodes} = State) ->
%    Nodes1 = lists:keyreplace(Path, #group.path, Nodes, Node),
%    State1 = State#state{nodes = Nodes1},
%    update_node_status_line(Node, State1),
%    State1;
replace_node(#suite{name = Name} = Node, #state{nodes = Nodes} = State) ->
    Nodes1 = lists:keyreplace(Name, #suite.name, Nodes, Node),
    State1 = State#state{nodes = Nodes1},
    update_node_status_line(Node, State1),
    State1.

get_line(#test{line = Line})  -> Line;
get_line(#group{line = Line}) -> Line;
get_line(#suite{line = Line}) -> Line.

set_line(#test{} = Test, Line)   -> Test#test{line = Line};
set_line(#group{} = Group, Line) -> Group#group{line = Line};
set_line(#suite{} = Suite, Line) -> Suite#suite{line = Line}.

get_node_height(#test{})  -> ?TEST_LINES;
get_node_height(#group{}) -> ?GROUP_HEADER_LINES;
get_node_height(#suite{}) -> ?SUITE_HEADER_LINES.

set_line_based_on_previous(Node, PreviousNode) ->
    PreviousNodeHeight = get_node_height_when_followed(PreviousNode, Node),
    set_line(Node, get_line(PreviousNode) + PreviousNodeHeight).

get_node_height_when_followed(#test{path = [_ | ParentPath1]},
                              #test{path = [_ | ParentPath2]})
  when ParentPath1 =/= ParentPath2 ->
    ?TEST_LINES + ?GROUP_FOOTER_LINES;
get_node_height_when_followed(#test{},
                              #test{}) ->
    ?TEST_LINES;
get_node_height_when_followed(#test{},
                              #group{}) ->
    ?TEST_LINES + ?GROUP_FOOTER_LINES;

get_node_height_when_followed(#group{path = ParentPath},
                              #test{path = [_ | ParentPath]}) ->
    ?GROUP_HEADER_LINES;
get_node_height_when_followed(#group{path = ParentPath1},
                              #test{path = [_ | ParentPath2]})
  when ParentPath1 =/= ParentPath2 ->
    ?GROUP_HEADER_LINES + ?GROUP_FOOTER_LINES;
get_node_height_when_followed(#group{},
                              #group{}) ->
    ?GROUP_HEADER_LINES + ?GROUP_FOOTER_LINES;

get_node_height_when_followed(#suite{},
                              #test{}) ->
    ?SUITE_HEADER_LINES;
get_node_height_when_followed(#suite{},
                              #group{}) ->
    ?SUITE_HEADER_LINES;

get_node_height_when_followed(_, #suite{}) ->
    ?SUITE_FOOTER_LINES.

%% -------------------------------------------------------------------

update_node_status_lines_starting_at(
  #state{nodes = Nodes} = State, Path) ->
    {UptodateNodes, NodesToUpdate} = lists:splitwith(
                                       fun(Node) ->
                                               get_path(Node) =/= Path
                                       end, Nodes),
    NewNode = hd(NodesToUpdate),
    NewNodeLine = get_line(NewNode),
    LastLineAfterUpdate = compute_last_line(State),
    {CurrentLastLine, BlankLinesBefore, BlankLinesAfter} =
    case {UptodateNodes, NodesToUpdate} of
        {[], _} ->
            {0, 0, 0};
        {_, [_, NextNode | _]} ->
            PreviousNode = lists:last(UptodateNodes),
            BlankLinesBefore0 =
            get_node_height_when_followed(PreviousNode, NewNode) -
            get_node_height_when_followed(PreviousNode, NextNode),
            NodeHeight = get_node_height(NewNode),
            BlankLinesAfter0 =
            get_node_height_when_followed(NewNode, NextNode) -
            NodeHeight,
            AddedLines = BlankLinesBefore0 + NodeHeight + BlankLinesAfter0,
            {LastLineAfterUpdate - AddedLines,
             BlankLinesBefore0,
             BlankLinesAfter0};
        {_, _} ->
            PreviousNode = lists:last(UptodateNodes),
            BlankLinesBefore0 =
            get_node_height_when_followed(PreviousNode, NewNode) -
            get_node_height(PreviousNode),
            AddedLines =
            BlankLinesBefore0 +
            get_node_height(NewNode),
            {LastLineAfterUpdate - AddedLines,
             BlankLinesBefore0,
             0}
    end,
    blank_lines(NewNodeLine - BlankLinesBefore,
                BlankLinesBefore,
                CurrentLastLine),
    blank_lines(NewNodeLine + get_node_height(NewNode),
                BlankLinesAfter,
                CurrentLastLine),
    update_node_status_lines(NodesToUpdate, CurrentLastLine).
    %blank_lines(LastLineAfterUpdate,
    %            ?SUITE_FOOTER_LINES,
    %            LastLineAfterUpdate).

update_node_status_lines([], _) ->
    ok;
update_node_status_lines([Node | Rest], LastLine) ->
    update_node_status_line2(Node, LastLine),
    update_node_status_lines(Rest, LastLine).

update_node_status_line(Node, State) ->
    LastLine = compute_last_line(State),
    update_node_status_line2(Node, LastLine).

update_node_status_line2(#test{} = Node, LastLine) ->
    update_test_status_line(Node, LastLine);
update_node_status_line2(#group{} = Node, LastLine) ->
    update_group_status_line(Node, LastLine);
update_node_status_line2(#suite{} = Node, LastLine) ->
    update_suite_status_line(Node, LastLine).

compute_last_line(#state{nodes = []}) ->
    0;
compute_last_line(#state{nodes = Nodes}) ->
    LastNode = lists:last(Nodes),
    get_line(LastNode) + get_node_height(LastNode).

%% -------------------------------------------------------------------

node_indent(#test{path = Path})  -> path_to_indent(Path);
node_indent(#group{path = Path}) -> path_to_indent(Path);
node_indent(#suite{})            -> "".

path_to_indent(Path) ->
    string:chars($\s, (length(Path) - 1) * 2).

all_runs_in_progress(#test{runs = Runs}) ->
    LastRun = lists:last(Runs),
    length(Runs) =:= LastRun#run.index.

update_test_result(failure, _, _)           -> failure;
update_test_result(_, failure, _)           -> failure;
update_test_result(undefined, _, false)     -> undefined;
update_test_result(skipped, success, true)  -> success;
update_test_result(undefined, Result, true) -> Result;
update_test_result(Result, _, _)            -> Result.

format_duration(Duration) ->
    Minutes = Duration div 60000,
    Seconds = (Duration - Minutes * 60000) div 1000,
    Millisecs = Duration - Minutes * 60000 - Seconds * 1000,
    {Minutes, Seconds, Millisecs}.

test_runs_duration_avg(Runs) ->
    FinishedRuns = [Run || #run{post_end_time = End} = Run <- Runs,
                           End =/= undefined],
    case FinishedRuns of
        [] ->
            undefined;
        _ ->
            Total = lists:sum(
                      [End - Start
                       || #run{pre_init_time = Start,
                               post_end_time = End} <- FinishedRuns]),
            Avg = erlang:round(Total / length(FinishedRuns)),
            Duration = erlang:convert_time_unit(Avg, native, millisecond),
            format_duration(Duration)
    end.

return_to_result({'EXIT', _}) -> failure;
return_to_result({error, _})  -> failure;
return_to_result({failed, _}) -> failure;
return_to_result({skip, _})   -> skipped;
return_to_result(_)           -> success.

result_to_color(success)   -> "\e[32m";
result_to_color(skipped)   -> "\e[1;33m";
result_to_color(failure)   -> "\e[1;31m";
result_to_color(undefined) -> "\e[0m".

update_suite_status_line(#suite{name = Name, line = Line} = Suite,
                         LastLine) ->
    {CursorUp, CursorDown} =
    if
        Line >= LastLine ->
            {"", ""};
        true ->
            {
             io_lib:format("\e[~bF", [LastLine - Line]),
             io_lib:format("\e[~bE", [LastLine - Line - ?SUITE_HEADER_LINES])
            }
    end,
    Indent = node_indent(Suite),
    Color = "\e[1m",
    io:format("~s~s~s== ~s ==\e[0m\e[K~n\e[K~n~s",
              [CursorUp, Indent, Color, Name, CursorDown]).

update_group_status_line(#group{name = Name, line = Line} = Group,
                         LastLine) ->
    {CursorUp, CursorDown} =
    if
        Line >= LastLine ->
            {"", ""};
        true ->
            {
             io_lib:format("\e[~bF", [LastLine - Line]),
             io_lib:format("\e[~bE", [LastLine - Line - ?GROUP_HEADER_LINES])
            }
    end,
    Indent = node_indent(Group),
    Color = "",
    io:format("~s~s* ~s[~s]\e[0m\e[K~n\e[K~s",
              [CursorUp, Indent, Color, Name, CursorDown]).

update_test_status_line(
  #test{name = Name,
        line = Line,
        result = Result,
        runs = Runs} = Test,
  LastLine) ->
    {CursorUp, CursorDown} =
    if
        Line >= LastLine ->
            {"", ""};
        true ->
            {
             io_lib:format("\e[~bF", [LastLine - Line]),
             io_lib:format("\e[~bE", [LastLine - Line - ?TEST_LINES])
            }
    end,
    Indent = node_indent(Test),
    Color = result_to_color(Result),
    case {length(Runs), test_runs_duration_avg(Runs)} of
        {1, undefined} ->
            io:format(
              "~s~s~s~s\e[0m\e[K~n~s",
              [CursorUp,
               Indent, Color, Name,
               CursorDown]);
        {N, undefined} ->
            io:format(
              "~s~s~s~s x ~b\e[0m\e[K~n~s",
              [CursorUp,
               Indent, Color, Name, N,
               CursorDown]);
        {1, {Minutes, Seconds, Millisecs}} ->
            io:format(
              "~s~s~s~s\e[0m (~2..0b:~2..0b.~3..0b)\e[K~n~s",
              [CursorUp,
               Indent, Color, Name, Minutes, Seconds, Millisecs,
               CursorDown]);
        {N, {Minutes, Seconds, Millisecs}} ->
            io:format(
              "~s~s~s~s\e[0m x ~b (avg. ~2..0b:~2..0b.~3..0b)\e[K~n~s",
              [CursorUp,
               Indent, Color, Name, N, Minutes, Seconds, Millisecs,
               CursorDown])
    end.

blank_lines(_, LineCount, _) when LineCount =< 0 ->
    ok;
blank_lines(StartLine, LineCount, LastLine)
  when StartLine == LastLine ->
    Lines = lists:flatten(["~n" || _ <- lists:seq(1, LineCount)]),
    io:format(Lines, []);
blank_lines(StartLine, LineCount, LastLine) ->
    CursorUp = io_lib:format("\e[~bF", [LastLine - StartLine]),
    CursorDown = io_lib:format("\e[~bE", [LastLine - StartLine - LineCount]),
    Lines = lists:flatten(["\e[K~n" || _ <- lists:seq(1, LineCount)]),
    io:format("~s" ++ Lines ++ "~s", [CursorUp, CursorDown]).

show_suite_summary(_Suite, _State) ->
    io:format("~n", []).

show_final_report(#state{nodes = Nodes}) ->
    show_errors(Nodes),
    io:format("~n", []).

show_errors([#suite{init_end_return = Return}  = Suite | Rest])
  when Return =/= undefined ->
    Label = path_to_error_label(Suite),
    Color = result_to_color(return_to_result(Return)),
    io:format("~n~s~s\e[0m~n    ~p~n", [Color, Label, Return]),
    show_errors(Rest);
show_errors([#group{init_end_return = Return} = Group | Rest])
  when Return =/= undefined ->
    Label = path_to_error_label(Group),
    Color = result_to_color(return_to_result(Return)),
    io:format("~n~s~s\e[0m~n    ~p~n", [Color, Label, Return]),
    show_errors(Rest);
show_errors([#test{result = Result} = Test | Rest]) when Result =/= success ->
    show_run_errors(Test),
    show_errors(Rest);
show_errors([_ | Rest]) ->
    show_errors(Rest);
show_errors([]) ->
    ok.

show_run_errors(#test{runs = Runs, result = Result} = Test) ->
    Label = path_to_error_label(Test),
    Color = result_to_color(Result),
    io:format("~n~s~s\e[0m~n", [Color, Label]),
    show_run_errors1(Runs, []).

show_run_errors1(
  [#run{result = Result, return = Return} | Rest], Displayed)
  when Result =/= success ->
    case lists:member(Return, Displayed) of
        false ->
            io:format("    #~b. ~p~n", [length(Displayed) + 1, Return]),
            show_run_errors1(Rest, [Return | Displayed]);
        true ->
            show_run_errors1(Rest, Displayed)
    end;
show_run_errors1([_ | Rest], Displayed) ->
    show_run_errors1(Rest, Displayed);
show_run_errors1([], _) ->
    ok.

path_to_error_label(Node) ->
    Path = get_path(Node),
    path_to_error_label1(Path).

path_to_error_label1(Path) when is_list(Path) ->
    string:join([atom_to_list(A) || A <- lists:reverse(Path)], " > ");
path_to_error_label1(Name) when is_atom(Name) ->
    atom_to_list(Name).

flush_io_requests() ->
    receive
        {io_request, _, _, _} = IoRequest ->
            reply_to_io_request(IoRequest),
            flush_io_requests()
    after 0 ->
              ok
    end.

reply_to_io_request({io_request, From, ReplyAs, _}) ->
    From ! {io_reply, ReplyAs, ok},
    ok.
