require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Release do

  @moduledoc """
    Code to build a release file. Many small tools working in harmony.
  """
  @doc """
    Build a release tar.gz. Returns `:ok` when done. Crash otherwise.
  """
  def release(config) do
    L.info "Compiling deps for release..."
    env = System.get_env "MIX_ENV"
    :ok = H.cmd "MIX_ENV=#{env} mix deps.get"
    :ok = H.cmd "MIX_ENV=#{env} mix compile"

    if env == "prod", do: H.check_erts_versions(config)

    L.info "Generating release tar.gz ..."
    File.rm_rf! "rel"
    File.mkdir_p! "rel"
    generate_rel_file()
    generate_config_file()
    generate_tar_file config
    :ok
  end

  defp generate_rel_file,
    do: H.write_term("rel/#{Mix.Project.get!.project[:app]}.rel", get_rel_term())

  defp generate_tar_file(config) do
    app = Mix.Project.get!.project[:app] |> to_charlist

    # add scripts folder
    process_scripts_folder config
    process_additional_folders config

    # list of atoms representing the dirs to include in the tar
    additional_folders = config[:additional_folders] |> Enum.map(&(String.to_atom(&1)))
    dirs = [:scripts] ++ additional_folders

    ebin_path = '#{Mix.Project.build_path}/lib/*/ebin'
    File.cd! "rel", fn() ->
      :systools.make_script(app,[path: [ebin_path]])
      :systools.make_tar(app,[dirs: dirs, path: [ebin_path]])
    end
  end

  # process templates found on scripts folder
  #
  defp process_scripts_folder(config) do
    vars = [app: Mix.Project.get!.project[:app],
            user: config[:remote_user],
            cookie: config[:cookie],
            max_processes: config[:max_processes] || 262_144]

    dest_path = "#{Mix.Project.app_path}/scripts"
    File.mkdir_p! dest_path

    scripts = get_all_scripts()
    renders = render_scripts(scripts, vars)
    copy_scripts(scripts, dest_path)
    save_renders(renders, dest_path)
  end

  defp render_scripts(scripts, vars) do
    scripts
    |> Enum.filter(fn({_,v}) -> String.match?(v,~r/\.eex$/) end)
    |> Enum.map(fn({k,v}) -> {k, EEx.eval_file(v,vars)} end)
  end

  defp copy_scripts(scripts, path) do
    for {f,v} <- scripts, do: :ok = File.cp v, "#{path}/#{f}"
  end

  defp save_renders(renders, path) do
    for {f,body} <- renders,
      do: :ok = File.write "#{path}/#{f}", body, [:write]
  end

  # copy additional folders to the destination folder to be included in the tar file
  #
  defp process_additional_folders(config) do
    config[:additional_folders] |> Enum.each(&(process_additional_folder(&1)))
  end

  defp process_additional_folder(additional_folder) do
    dest_path = "#{Mix.Project.app_path}/#{additional_folder}"
    File.mkdir_p! dest_path

    files = H.full_ls "lib/#{additional_folder}"

    for f <- files do
      :ok = File.cp f, "#{dest_path}/#{Path.basename(f)}"
    end
  end

  # Return all script files' names and full paths. Merging bottler's scripts
  # folder with project's scripts folder if it exists.
  #
  # Project's scripts overwrite bottler's with the same name,
  # ignoring the extra `.eex` part (i.e. `shell.sh` from bottler would be
  # replaced with `shell.sh.eex` from the project ).
  #
  defp get_all_scripts do
    pfiles = H.full_ls "lib/scripts"
    bfiles = H.full_ls "#{__DIR__}/../scripts"
    for f <- (bfiles ++ pfiles), into: %{}, do: {Path.basename(f,".eex"), f}
  end

  H.todo "ensure paths"
  defp generate_config_file do
    H.write_term "rel/sys.config", Mix.Config.read!("config/config.exs")
  end

  defp get_deps_term do
    {apps, iapps} = get_all_apps()

    iapps
    |> Enum.map(fn({n,v}) -> {n,v,:load} end)
    |> Enum.concat(apps)
  end

  defp get_rel_term do
    mixf = Mix.Project.get!
    app = mixf.project[:app] |> to_charlist
    vsn = mixf.project[:version] |> to_charlist

    {
      :release,
      {app, vsn},
      {:erts, :erlang.system_info(:version)},
      get_deps_term()
    }
  end

  # Get info for every compiled app's from its app file
  #
  defp read_all_app_files do
    infos = "find -L _build/#{Mix.env} -name *.app"
      |> to_charlist |> :os.cmd |> to_string |> String.split

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
    all = get_all_apps_plain_list()
    versions = get_versions(all)

    # get own included applications
    own_iapps = Mix.Project.get!.application
                |> Keyword.get(:included_applications, [])

    only_included = all[:iapps]
      |> Enum.reject(&(&1 in all[:apps]))
      |> :erlang.++(own_iapps) # own included are only included
      |> add_version_info(versions)

    apps = all[:apps] |> Enum.uniq
      |> :erlang.--(own_iapps) # do not start own included
      |> add_version_info(versions)

    {apps, only_included}
  end

  defp get_versions(apps) do
    load_apps(apps)
    for {n, _, v} <- :application.info[:loaded], do: {n, v}
  end

  # load all of them, see what version they are on
  #
  defp load_apps(apps) do
    for a <- (apps[:apps] ++ apps[:iapps]), do: :ok = load(a)
  end

  # a list of all apps ever needed or included
  #
  defp get_all_apps_plain_list do
    needed = [:kernel, :stdlib, :elixir, :sasl, :compiler, :syntax_tools]

    read_all_app_files()
    |> Enum.reduce([apps: needed, iapps: []],
    fn({n, _, a, ia}, [apps: apps, iapps: iapps]) ->
      ia = if ia == nil, do: [], else: ia
      apps = Enum.concat([apps, [n], a, ia])
      iapps = Enum.concat(iapps, ia)
      [apps: apps, iapps: iapps]
    end)
  end

  defp add_version_info(apps,versions) do
    apps
    |> Enum.map(fn(a) -> {a,versions[a]} end)
    |> Enum.reject(fn({_,v}) -> v == nil end) # ignore those with no vsn info
  end

  defp load(app) do
    # if it's a custom compiled app, ensure that's the one that gets loaded
    :code.add_patha('#{Mix.Project.build_path}/lib/#{app}/ebin')
    case :application.load app do
      {:error, {:already_loaded, ^app}} -> :ok
      x -> x
    end
  end

end
