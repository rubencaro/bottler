require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Release do

  @moduledoc """
    Code to build a release file. Many small tools working in harmony.
  """
  @doc """
    Build a release tar.gz
  """
  def release(config) do
    L.info "Compiling deps for release..."
    env = System.get_env "MIX_ENV"
    :ok = cmd "MIX_ENV=#{env} mix deps.get"
    :ok = cmd "MIX_ENV=#{env} mix compile --force"

    L.info "Generating release tar.gz ..."
    File.rm_rf! "rel"
    File.mkdir_p! "rel"
    generate_rel_file
    generate_config_file
    generate_tar_file config
    :ok
  end

  defp generate_rel_file,
    do: H.write_term("rel/#{Mix.Project.get!.project[:app]}.rel", get_rel_term)

  defp generate_tar_file(config) do
    app = Mix.Project.get!.project[:app] |> to_char_list

    # add scripts folder
    process_scripts_folder config

    ebin_path = '#{Mix.Project.build_path}/lib/*/ebin'
    File.cd! "rel", fn() ->
      :systools.make_script(app,[path: [ebin_path]])
      :systools.make_tar(app,[dirs: [:scripts], path: [ebin_path]])
    end
  end

  # process templates found on scripts folder
  #
  def process_scripts_folder(config) do
    vars = [app: Mix.Project.get!.project[:app],
            user: config[:remote_user]]
    dest_path = "#{Mix.Project.app_path}/scripts"
    File.mkdir_p! dest_path

    # render script templates
    scripts = get_all_scripts
    renders = scripts
              |> Enum.filter(fn({_,v})-> String.match?(v,~r/\.eex$/) end)
              |> Enum.map(fn({k,v})-> { k, EEx.eval_file(v,vars) } end)

    # copy scripts
    for {f,v} <- scripts, do: :ok = File.cp v, "#{dest_path}/#{f}"
    # save renders over them
    for {f,body} <- renders,
      do: :ok = File.write "#{dest_path}/#{f}", body, [:write]
  end

  # Return all script files' names and full paths. Merging bottler's scripts
  # folder with project's scripts folder if it exists.
  #
  # Project's scripts overwrite bottler's with the same name,
  # ignoring the extra `.eex` part (i.e. `shell.sh` from bottler would be
  # replaced with `shell.sh.eex` from the project ).
  #
  def get_all_scripts do
    pfiles = full_ls "lib/scripts"
    bfiles = full_ls "#{__DIR__}/../scripts"
    for f <- (bfiles ++ pfiles), into: %{}, do: {Path.basename(f,".eex"), f}
  end

  # ls with full paths
  defp full_ls(path), do:
    path |> File.ls! |> Enum.map(&( "#{Path.expand(path)}/#{&1}" ))

  # TODO: ensure paths
  #
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
    mixf = Mix.Project.get!
    app = mixf.project[:app] |> to_char_list
    vsn = mixf.project[:version] |> to_char_list

    {:release,
      {app, vsn},
      {:erts, :erlang.system_info(:version)},
      get_deps_term }
  end

  # Get info for every compiled app's from its app file
  #
  defp read_all_app_files do
    infos = :os.cmd('find -L _build/#{Mix.env} -name *.app')
            |> to_string |> String.split

    for path <- infos do
      {:ok,[{_,name,data}]} = path |> H.read_terms
      {name, data[:vsn], data[:applications], data[:included_applications]}
    end
  end

  # Get compiled, and included apps with versions.
  #
  # If an included application is not loaded or compiled itself, version
  # number cannot be determined, and it will be ignored. If this is
  # your case, you should explicitly put it into your deps, so it gets
  # compiled, and then detected here.
  #
  defp get_all_apps do
    app_files_info = read_all_app_files

    # get compiled versions
    compiled = for {n,v,_,_} <- app_files_info, do: {n,v}

    # get included applications and load them
    own_iapps = Mix.Project.get!.application
                |> Keyword.get(:included_applications, [])
    for a <- own_iapps, do: :application.load(a)

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
          |> :erlang.--(own_iapps)
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
