-module(parrot_ffi).

-export([get_os/0, get_cpu/0, extract_sqlc_binary/1]).

get_os() ->
  case os:type() of
    {win32, _} -> <<"win32">>;
    {unix, darwin} -> <<"darwin">>;
    {unix, linux} -> <<"linux">>;
    {_, Unknown} -> atom_to_binary(Unknown, utf8)
  end.

get_cpu() ->
  case erlang:system_info(os_type) of
    {unix, _} ->
      [Arch, _] = string:split(erlang:system_info(system_architecture), "-"),
      list_to_binary(Arch);
    {win32, _} ->
      case erlang:system_info(wordsize) of
        4 -> <<"ia32">>;
        8 -> <<"x64">>
      end
  end.

%% sqlc is released as a .tar.gz for every platform
extract_sqlc_binary(TarGz) ->
  try erl_tar:extract({binary, zlib:gunzip(TarGz)}, [memory]) of
    {ok, Files} ->
      case [Data || {Name, Data} <- Files, lists:member(filename:basename(Name), ["sqlc", "sqlc.exe"])] of
        [Binary | _] -> {ok, Binary};
        [] -> {error, nil}
      end;
    {error, _} -> {error, nil}
  catch
    _:_ -> {error, nil}
  end.
