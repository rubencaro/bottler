require Bottler.Helpers, as: H
require Logger, as: L

defmodule ReleaseTest do
  use ExUnit.Case, async: false

  test "release gets generated" do
    vsn = Bottler.Mixfile.project[:version]
    apps = [:bottler,:kernel,:stdlib,:elixir,:logger,:crypto,:sasl,:compiler,
            :syntax_tools]
    iapps = [:ssh,:public_key,:asn1]

    # clean any previous work
    :os.cmd 'rm -fr rel'

    # generate release
    :ok = Bottler.Release.release

    # check rel term
    {:ok,[{:release, app, erts, deps}]} = H.read_terms "rel/bottler.rel"
    assert {'bottler', to_char_list(vsn)} == app
    assert {:erts, :erlang.system_info(:version)} == erts
    for dep <- deps do
      case dep do
        {d,_,:load} -> assert d in iapps
        {d,_} -> assert d in apps
      end
    end

    # check script term
    {:ok,_} = H.read_terms "rel/bottler.script"

    # check config term
    {:ok,[config_term]} = H.read_terms "rel/sys.config"
    [logger: _, bottler: [servers: _, mixfile: _]] = config_term

    # check tar.gz exists and extracts
    assert File.regular?("rel/bottler.tar.gz")
    :os.cmd 'mkdir -p rel/extracted'
    :ok = :erl_tar.extract('rel/bottler.tar.gz',
                            [:compressed,{:cwd,'rel/extracted'}])
    # check its contents
    ["lib","releases"] = H.ls "rel/extracted"
    [vsn,"bottler.rel"] = H.ls "rel/extracted/releases"
    ["bottler.rel","start.boot","sys.config"] = H.ls "rel/extracted/releases/#{vsn}"
    libs = for lib <- H.ls("rel/extracted/lib"), into: [] do
      lib |> String.split("-") |> List.first
    end
    assert libs == (apps ++ iapps) |> Enum.map(&(to_string(&1))) |> Enum.sort
  end
end
