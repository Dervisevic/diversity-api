-module(git_utils).

%% API
-export([tags/1, get_diversity_json/2, get_diversity_json/3, git_refresh_repo/1]).



%% @doc Returns a list with all tags in a git repository
-spec tags(binary()) -> [binary()].
tags(RepoName) ->
    Cmd = "tag",
    ResultString = get_git_result(RepoName, Cmd),
    [list_to_binary(Tag) || Tag <- string:tokens(ResultString, "\n")].

%% @doc Returns the diversity.json for a tag in a repo
-spec get_diversity_json(binary(), binary()) -> binary().
get_diversity_json(RepoName, Tag) ->
    Cmd = "show " ++ binary_to_list(Tag) ++ ":diversity.json",
    list_to_binary(get_git_result(RepoName, Cmd)).
-spec get_diversity_json(binary(), binary(), binary()) -> binary().
get_diversity_json(RepoName, RepoUrl, Tag) ->
    Cmd = "show " ++ binary_to_list(Tag) ++ ":diversity.json",
    list_to_binary(get_git_result(RepoName, RepoUrl, Cmd)).

%% @doc Fetches the latest tags for a repo
-spec git_refresh_repo(binary()) -> any().
git_refresh_repo(RepoName) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    GitRepoName =  RepoDir ++ "/" ++ binary_to_list(RepoName) ++ ".git",
    file:set_cwd(GitRepoName),
    Cmd = "fetch origin master:master",
    git_cmd(Cmd).

%% ----------------------------------------------------------------------------
%% Internal stuff
%% ----------------------------------------------------------------------------
get_git_result(RepoName, Cmd) ->
    get_git_result(RepoName, undefined, Cmd).
get_git_result(RepoName, RepoUrl, Cmd) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    GitRepoName =  RepoDir ++ "/" ++ binary_to_list(RepoName) ++ ".git",
    %% Clone git repo if non-existing in configured dir
    case filelib:is_dir(GitRepoName) of
        false ->
            RepoUrl2 = get_repo_url(RepoName, RepoUrl),
            clone_bare(binary_to_list(RepoUrl2));
        true ->
            %% Checkout not needed
            ok
    end,
    file:set_cwd(GitRepoName),
    git_cmd(Cmd).

clone_bare(RepoUrl) ->
    {ok, RepoDir} = application:get_env(divapi, repo_dir),
    filelib:ensure_dir(RepoDir),
    file:set_cwd(RepoDir),
    Cmd = "clone --bare " ++ RepoUrl,
    git_cmd(Cmd).

get_repo_url(RepoName, undefined) -> gitlab_utils:get_public_project_url(RepoName);
get_repo_url(_, RepoUrl) -> RepoUrl.

git_cmd(Cmd) ->
    os:cmd("git " ++ Cmd).