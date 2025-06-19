-module(parrot_ffi).

-export([get_cpu/0, get_os/0, download_file/1, download_zip/1, extract_sqlc_binary/1, extract_sqlc_from_targz/1]).

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
