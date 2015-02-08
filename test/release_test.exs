require Bottler.Helpers, as: H

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
    assert :ok = Mix.Tasks.Release.run []

    # check rel term
    assert {:ok,[{:release, app, erts, deps}]} = H.read_terms "rel/bottler.rel"
    assert {'bottler', to_char_list(vsn)} == app
    assert {:erts, :erlang.system_info(:version)} == erts
    for dep <- deps do
      case dep do
        {d,_,:load} -> assert d in iapps
        {d,_} -> assert d in apps
      end
    end

    # check script term
    assert {:ok,_} = H.read_terms "rel/bottler.script"

    # check config term
    assert {:ok,[config_term]} = H.read_terms "rel/sys.config"
    assert [logger: _, bottler: [params: [servers: _, remote_user: _]]] = config_term

    # check tar.gz exists and extracts
    assert File.regular?("rel/bottler.tar.gz")
    :os.cmd 'mkdir -p rel/extracted'
    assert :ok = :erl_tar.extract('rel/bottler.tar.gz',
                            [:compressed,{:cwd,'rel/extracted'}])
    # check its contents
    assert ["lib","releases"] == File.ls!("rel/extracted") |> Enum.sort
    assert ([vsn,"bottler.rel"] |> Enum.sort) == File.ls!("rel/extracted/releases") |> Enum.sort
    assert ["bottler.rel","start.boot","sys.config"] == File.ls!("rel/extracted/releases/#{vsn}") |> Enum.sort
    libs = for lib <- File.ls!("rel/extracted/lib"), into: [] do
      lib |> String.split("-") |> List.first
    end |> Enum.sort
    assert libs == (apps ++ iapps) |> Enum.map(&(to_string(&1))) |> Enum.sort
    assert ["connect.sh","watchdog.sh"] = File.ls!("rel/extracted/lib/bottler-#{vsn}/scripts") |> Enum.sort
  end
end
