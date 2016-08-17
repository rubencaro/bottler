require Bottler.Helpers, as: H

defmodule ReleaseTest do
  use ExUnit.Case, async: false

  setup do
    extra_dir = "#{Mix.Project.build_path}/../../lib/extras"
    File.mkdir(extra_dir)
    :ok = File.write "#{extra_dir}/dummy", ""

    on_exit fn ->
      File.rm_rf(extra_dir)
    end

    :ok
  end

  test "release gets generated" do
    vsn = Bottler.Mixfile.project[:version]
    apps = [:bottler,:kernel,:stdlib,:elixir,:logger,:crypto,:sasl,:compiler,
            :ssh,:syntax_tools,:sshex,:parallel_stream,:csv]
    iapps = [:public_key,:asn1,:iex]

    # clean any previous work
    :os.cmd 'rm -fr rel'

    # generate release
    assert :ok = Mix.Tasks.Bottler.Release.run []

    # check rel term
    assert {:ok,[{:release, app, erts, deps}]} = H.read_terms "rel/bottler.rel"
    assert {'bottler', to_charlist(vsn)} == app
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
    assert [logger: _, bottler: [params: [servers: _, remote_user: _, cookie: _, additional_folders: ["extras"]]]] = config_term

    # check tar.gz exists and extracts
    assert File.regular?("rel/bottler.tar.gz")
    :os.cmd 'mkdir -p rel/extracted'
    assert :ok = :erl_tar.extract('rel/bottler.tar.gz',
                            [:compressed,{:cwd,'rel/extracted'}])
    # check its contents
    assert ["lib","releases"] == File.ls!("rel/extracted") |> Enum.sort
    # releases
    assert ([vsn,"bottler.rel"] |> Enum.sort) == File.ls!("rel/extracted/releases") |> Enum.sort
    # release folder
    assert ["bottler.rel","start.boot","sys.config"] == File.ls!("rel/extracted/releases/#{vsn}") |> Enum.sort
    # libs included
    libs = for lib <- File.ls!("rel/extracted/lib"), into: [] do
      lib |> String.split("-") |> List.first
    end |> Enum.sort
    assert libs == (apps ++ iapps) |> Enum.map(&(to_string(&1))) |> Enum.sort
    # scripts too
    assert ["connect.sh","erl_connect.sh","watchdog.sh"] = File.ls!("rel/extracted/lib/bottler-#{vsn}/scripts") |> Enum.sort
    assert ["dummy"] = File.ls!("rel/extracted/lib/bottler-#{vsn}/extras") |> Enum.sort
  end
end
