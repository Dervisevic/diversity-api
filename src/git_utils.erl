-module(git_utils).

%% API
-export([tags/1, get_diversity_json/2, refresh_repo/1, get_file/3, clone_bare/1]).

%% @doc Returns a list with all tags in a git repository
-spec tags(binary()) -> [binary()].
tags(RepoName) ->
    Cmd = <<"git tag">>,
    case get_git_result(RepoName, Cmd) of
        error ->
            [];
        <<>>  ->
            [];
        ResultBin ->
            Res = re:split(ResultBin, <<"\n">>),
            lists:droplast(Res)
    end.

%% @doc Returns the diversity.json for a tag in a repo
-spec get_diversity_json(binary(), binary()) -> binary().
get_diversity_json(RepoName, Tag) ->
    get_git_file(RepoName, Tag, <<"diversity.json">>).

%% @doc Fetches the latest tags for a repo
-spec refresh_repo(binary()) -> any().
refresh_repo(RepoName) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    GitRepoName =  RepoDir ++ "/" ++ binary_to_list(RepoName) ++ ".git",
    Cmd = <<"git fetch origin master:master">>,
    git_cmd(Cmd, GitRepoName).

get_file(RepoName, Tag, FilePath) ->
    get_git_file(RepoName, Tag, FilePath).

%% ----------------------------------------------------------------------------
%% Internal stuff
%% ----------------------------------------------------------------------------

%% @doc Retrieves the file from the bare git repo and the specific tag.
-spec get_git_file(RepoName :: binary(), Tag :: binary(),
                   FilePath :: binary) -> binary() | undefined.
get_git_file(RepoName, Tag, FilePath) ->
    Cmd = <<"git --no-pager show ", Tag/binary, ":", FilePath/binary>>,
    case get_git_result(RepoName, Cmd) of
        FileBin when is_binary(FileBin) -> FileBin;
        error                           -> undefined;
        ok                              -> <<>> %% Command succesful but empty result!
    end.

get_git_result(RepoName, Cmd) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    GitRepoDir =  RepoDir ++ "/" ++ binary_to_list(RepoName) ++ ".git",
    %% Clone git repo if non-existing in configured dir
    case filelib:is_dir(GitRepoDir) of
        false -> error; %% Repo does not exist, noop.
        true -> ok %% Checkout not needed
    end,
    git_cmd(Cmd, GitRepoDir).

clone_bare(RepoUrl) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    %% Ensure it exists if not try to create it.
    ok = filelib:ensure_dir(RepoDir ++ "/"),
    Cmd = <<"git clone --bare ", RepoUrl/binary>>,
    git_cmd(Cmd, RepoDir).

git_cmd(Cmd, WorkingDir) ->
    Port = erlang:open_port({spawn, Cmd}, [exit_status, {cd, WorkingDir}, binary, stderr_to_stdout]),
    wait_for_file(Port, <<>>).

wait_for_file(Port, File) ->
    receive
        {Port, {data, Chunk}} ->
            wait_for_file(Port, <<File/binary, Chunk/binary>>);
        {_ , {exit_status, 0}} ->
            File;
        {_, {exit_status, _}} ->
            %% Either not a git repo or operation failed. No need to close port it' already done.
            error
    end.
