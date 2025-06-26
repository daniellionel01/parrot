-module(parrot_ffi).

-export([get_cpu/0, get_os/0, download_file/1, download_zip/1, extract_sqlc_binary/1, extract_sqlc_from_targz/1, os_command/5, os_exit/1, os_which/1, start_arguments/0]).

get_os() ->
    case os:type() of
        {win32, _} ->
            <<"win32">>;
        {unix, darwin} ->
            <<"darwin">>;
        {unix, linux} ->
            <<"linux">>;
        {_, Unknown} ->
            atom_to_binary(Unknown, utf8)
    end.

get_cpu() ->
    case erlang:system_info(os_type) of
        {unix, _} ->
            [Arch, _] =
                string:split(
                    erlang:system_info(system_architecture), "-"),
            list_to_binary(Arch);
        {win32, _} ->
            case erlang:system_info(wordsize) of
                4 ->
                    <<"ia32">>;
                8 ->
                    <<"x64">>
            end
    end.

%% Generic file download function
download_file(Url) ->
    case httpc:request(get, {Url, []}, [{timeout, 30000}], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _Headers, Body}} ->
            {ok, Body};
        {ok, {{_, StatusCode, _}, _Headers, _Body}} ->
            {error, {http_error, StatusCode}};
        {error, Reason} ->
            {error, Reason}
    end.

%% Backward compatibility - alias for download_file
download_zip(Url) ->
    download_file(Url).

%% Extract sqlc binary from either zip or tar.gz archive
extract_sqlc_binary(ArchiveData) ->
    case detect_archive_type(ArchiveData) of
        zip ->
            extract_from_zip(ArchiveData);
        targz ->
            extract_from_targz(ArchiveData);
        {error, Reason} ->
            {error, Reason}
    end.

%% Extract sqlc binary from tar.gz archive
extract_sqlc_from_targz(TarGzData) ->
    extract_from_targz(TarGzData).

%% Helper function to detect archive type by magic bytes
detect_archive_type(<<16#1F, 16#8B, _/binary>>) ->
    % Gzip magic bytes (tar.gz files start with gzip header)
    targz;
detect_archive_type(<<16#50, 16#4B, 16#03, 16#04, _/binary>>) ->
    % ZIP magic bytes (local file header signature)
    zip;
detect_archive_type(<<16#50, 16#4B, 16#05, 16#06, _/binary>>) ->
    % ZIP magic bytes (end of central directory signature)
    zip;
detect_archive_type(<<16#50, 16#4B, 16#07, 16#08, _/binary>>) ->
    % ZIP magic bytes (data descriptor signature)
    zip;
detect_archive_type(_) ->
    {error, unknown_archive_type}.

%% Extract from ZIP archive
extract_from_zip(ZipData) ->
    case zip:unzip(ZipData, [memory]) of
        {ok, FileList} ->
            find_sqlc_binary(FileList);
        {error, Reason} ->
            {error, {zip_error, Reason}}
    end.

%% Extract from tar.gz archive
extract_from_targz(TarGzData) ->
    case extract_tar_gz(TarGzData) of
        {ok, TarData} ->
            case erl_tar:extract({binary, TarData}, [memory]) of
                {ok, FileList} ->
                    find_sqlc_binary(FileList);
                {error, Reason} ->
                    {error, {tar_extract_error, Reason}}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% Helper function to decompress gzip data
extract_tar_gz(TarGzData) ->
    try
        TarData = zlib:gunzip(TarGzData),
        {ok, TarData}
    catch
        error:Reason ->
            {error, {gzip_error, Reason}}
    end.

%% Helper function to find sqlc binary in file list
find_sqlc_binary(FileList) ->
    case find_sqlc_in_files(FileList) of
        {ok, Data} ->
            {ok, Data};
        not_found ->
            {error, file_not_found}
    end.

%% Recursively search for sqlc binary in file list
find_sqlc_in_files([]) ->
    not_found;
find_sqlc_in_files([{Filename, Data} | Rest]) ->
    case is_sqlc_binary(Filename) of
        true ->
            {ok, Data};
        false ->
            find_sqlc_in_files(Rest)
    end.

%% Check if filename indicates it's the sqlc binary
is_sqlc_binary(Filename) ->
    % Convert to string for easier manipulation
    FilenameStr = binary_to_list(iolist_to_binary(Filename)),
    % Check for exact match or sqlc with extension
    case filename:basename(FilenameStr) of
        "sqlc" -> true;
        "sqlc.exe" -> true;
        _ -> false
    end.

%% === === === === === === === === === %%

os_command(Command, Args, Dir, Opts, EnvBin) ->
    HasPathSep = is_absolute_or_has_path_separator(Command),

    Which =
        case HasPathSep of
            true ->
                % Command has path separators (like "./sqlc" or "/usr/bin/cmd")
                % Resolve it relative to Dir if it's relative
                ResolvedCommand = resolve_command_path(Command, Dir),
                Result = os_which_absolute(ResolvedCommand),
                Result;
            false ->
                % Command is just a name (like "sqlc"), try PATH first, then Dir
                case os_which(Command) of
                    {error, _}  ->
                        JoinedPath = filename:join(Dir, Command),
                        Result = os_which_absolute(JoinedPath),
                        Result;
                    WhichResult ->
                        WhichResult
                end
        end,
    {ExitCode, Output} =
        case Which of
            {error, WhichError} ->
                {1, WhichError};
            {ok, Executable} ->
                ExecutableChars = binary_to_list(Executable),

                LetBeStdout = maps:get(let_be_stdout, Opts, false),
                FromBin = fun({Name, Val}) ->
                    {
                        binary_to_list(Name),
                        unicode:characters_to_list(Val, file:native_name_encoding())
                    }
                end,
                Env = lists:map(FromBin, EnvBin),

                PortSettings = lists:merge([
                    [
                        {args, Args},
                        {cd, Dir},
                        {env, Env},
                        eof,
                        exit_status,
                        hide,
                        in
                    ],
                    case maps:get(overlapped_stdio, Opts, false) of
                        true -> [overlapped_io];
                        _ -> []
                    end,
                    case LetBeStdout or maps:get(let_be_stderr, Opts, false) of
                        true -> [];
                        _ -> [stderr_to_stdout]
                    end,
                    case LetBeStdout of
                        true -> [{line, 99999999}];
                        _ -> [stream]
                    end
                ]),

                try
                    Port = open_port({spawn_executable, ExecutableChars}, PortSettings),
                    {Status, OutputChars} = get_data(Port, []),
                    case LetBeStdout of
                        true -> {Status, <<>>};
                        _ -> {Status, list_to_binary(OutputChars)}
                    end
                catch
                    Error:Reason ->
                        {1, list_to_binary(io_lib:format("Port execution failed: ~p:~p", [Error, Reason]))}
                end
        end,

    case ExitCode of
        0 ->
            {ok, Output};
        2 when Output == <<>> ->
            DirError = list_to_binary(
                "The directory \"" ++
                    binary_to_list(Dir) ++
                    "\" does not exist\n"
            ),
            {error, {ExitCode, DirError}};
        _ ->
            {error, {ExitCode, Output}}
    end.

% Helper to check if command contains path separators
is_absolute_or_has_path_separator(Command) ->
    CommandStr = binary_to_list(Command),
    PathType = filename:pathtype(CommandStr),
    HasSlash = lists:member($/, CommandStr),
    HasBackslash = lists:member($\\, CommandStr),
    Result = PathType =/= relative orelse HasSlash orelse HasBackslash,
    Result.

% Resolve command path relative to Dir if it's a relative path
resolve_command_path(Command, Dir) ->
    CommandStr = binary_to_list(Command),
    DirStr = binary_to_list(Dir),
    PathType = filename:pathtype(CommandStr),

    Result = case PathType of
        absolute ->
            % Already absolute, use as-is
            list_to_binary(CommandStr);
        relative ->
            % For relative paths, we need to resolve the command relative to Dir
            % But we need to preserve the original command's relative nature

            % First, make Dir absolute if it isn't already
            AbsDir = case filename:pathtype(DirStr) of
                absolute -> DirStr;
                relative -> filename:absname(DirStr)
            end,

            % Now resolve the command relative to the absolute Dir
            % Use filename:absname/2 to resolve CommandStr relative to AbsDir
            NormalizedPath = filename:absname(CommandStr, AbsDir),
            list_to_binary(NormalizedPath)
    end,
    Result.

% Version of os_which that works with absolute paths and doesn't use os:find_executable
os_which_absolute(Command) ->
    CommandChars = binary_to_list(Command),

    FileExists = filelib:is_file(CommandChars),

    case FileExists of
        false ->
            ExecutableError = "command `" ++ CommandChars ++ "` not found\n",
            {error, list_to_binary(ExecutableError)};
        true ->
            IsRegular = filelib:is_regular(CommandChars),
            case IsRegular of
                false ->
                    ExecutableError = "command `" ++ CommandChars ++ "` is not a regular file\n",
                    {error, list_to_binary(ExecutableError)};
                true ->
                    % Check if file is executable (Unix-like systems)
                    {ok, Command}
            end
    end.

get_data(Port, SoFar) ->
    receive
        {Port, {data, {_Flag, Bytes}}} ->
            get_data(Port, [SoFar | Bytes]);
        {Port, {data, Bytes}} ->
            get_data(Port, [SoFar | Bytes]);
        {Port, eof} ->
            Port ! {self(), close},
            receive
                {Port, closed} ->
                    true
            end,
            receive
                {'EXIT', Port, _} ->
                    ok
                % force context switch
            after 1 ->
                ok
            end,
            ExitCode =
                receive
                    {Port, {exit_status, Code}} ->
                        Code
                end,
            {ExitCode, lists:flatten(SoFar)}
    end.

os_exit(Status) ->
    halt(Status).

os_which(Command) ->
    CommandChars = binary_to_list(Command),
    {Result, OutputChars} =
        case os:find_executable(CommandChars) of
            false ->
                case filelib:is_file(CommandChars) of
                    false ->
                        ExecutableError =
                            "command `" ++ CommandChars ++ "` not found\n",
                        {error, ExecutableError};
                    true ->
                        {ok, CommandChars}
                end;
            Executable ->
                {ok, Executable}
        end,
    {Result, list_to_binary(OutputChars)}.

start_arguments() ->
    lists:map(fun unicode:characters_to_binary/1, init:get_plain_arguments()).
