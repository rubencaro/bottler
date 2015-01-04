require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Release do

  @moduledoc """
    Code to build a release file. Many small tools working in harmony.
  """
  @mixfile Application.get_env(:bottler, :mixfile)
  @app @mixfile.project[:app] |> to_char_list

  @doc """
    Build a release tar.gz
  """
  def release do
    L.info "Compiling deps for release..."
    env = System.get_env "MIX_ENV"
    :ok = cmd "MIX_ENV=#{env} mix deps.get"
    :ok = cmd "MIX_ENV=#{env} mix compile"

    L.info "Generating release tar.gz ..."
    File.mkdir_p! "rel"
    generate_rel_file
    generate_config_file
    generate_tar_file
    :ok
  end

  defp generate_rel_file do
    H.write_term "rel/#{@app}.rel", get_rel_term
  end

  defp generate_tar_file do
    File.cd! "rel", fn() ->
      :systools.make_script(@app)
      :systools.make_tar(@app)
    end
  end

  defp generate_config_file do
    H.write_term "rel/sys.config", Mix.Config.read!("config/config.exs")
  end

  defp get_deps_term do
    {apps, iapps} = get_all_apps

    iapps
    |> Enum.map(fn({n,v}) -> {n,v,:load} end)
    |> Enum.concat(apps)
  end

  defp get_rel_term do
    {:release,
      {@app, to_char_list(@mixfile.project[:version])},
      {:erts, :erlang.system_info(:version)},
      get_deps_term }
  end

  # Get info for every compiled app's from its app file
  #
  defp read_all_app_files do
    infos = :os.cmd('find -L _build/prod -name *.app')
            |> to_string |> String.split

    for path <- infos do
      {:ok,[{_,name,data}]} = path |> H.read_terms
      {name, data[:vsn], data[:applications], data[:included_applications]}
    end
  end

  # Get compiled, and included apps with versions.
  #
  # If a included application is not loaded or compiled itself, version
  # number cannot be determined, and it will be ignored. If this is
  # your case, you should explicitly put it into your deps, so it gets
  # compiled, and then detected here.
  #
  defp get_all_apps do
    app_files_info = read_all_app_files

    # get compiled versions
    compiled = for {n,v,_,_} <- app_files_info, do: {n,v}

    # get included applications and load them
    own_iapps = @mixfile.application
                |> Keyword.get(:included_applications, [])
                |> Enum.map(&({&1,&1}))
    for {a,_} <- own_iapps, do: :application.load(a)

    # get loaded app's versions
    :application.load :sasl # SASL,that may be not loaded
    loaded = for {n,_,v} <- :application.info[:loaded], do: {n,v}
    versions = [compiled, loaded] |> Enum.concat |> Enum.uniq

    # a list of all apps with versions
    all = app_files_info |> Enum.reduce([apps: [], iapps: []],
              fn({n,_,a,ia},[apps: apps, iapps: iapps]) ->
                if ia == nil, do: ia = []
                apps = Enum.concat([apps,[n],a,ia])
                iapps = Enum.concat(iapps,ia)
                [apps: apps, iapps: iapps]
              end )

    only_included = all[:iapps]
        |> Enum.reject(&( all[:apps][&1] ))
        |> Enum.map(fn(a) -> {a,versions[a]} end)

    apps = Enum.concat(all[:apps],[:kernel, :stdlib, :elixir,
                                   :sasl, :compiler, :syntax_tools])
          |> Enum.uniq
          |> Enum.reject(&( own_iapps[&1] ))
          |> Enum.map(fn(a) -> {a,versions[a]} end)
          |> Enum.reject(fn({_,v}) -> v == nil end) # ignore those with no vsn info

    {apps, only_included}
  end

  defp cmd(command) do
    case Mix.Shell.cmd(command, &(IO.write(&1)) ) do
      0 -> :ok
      _ -> {:error, "Release step failed. Please fix any errors and try again."}
    end
  end

end
