require Logger, as: L
require Bottler.Helpers, as: H
alias SSHEx, as: S

defmodule Bottler.Install do

  @moduledoc """
    Functions to install an already shipped release on remote servers.

    Actually running release is not touched. Next restart will run
    the new release.
  """

  @doc """
    Install previously shipped release on remote servers, making it _current_
    release.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def install(config) do
    :ssh.start # sometimes it's not already started at this point...

    config[:servers]
    |> H.prepare_servers
    |> Enum.map(fn(s) ->
      s
      |> Keyword.put(:user, config[:remote_user])
      |> Keyword.put(:additional_folders, config[:additional_folders])
      |> Keyword.merge(config[:install] || [])
    end)
    |> H.in_tasks(fn(args) ->
      on_server(args)
    end)
  end

  defp on_server(args) do
    case args[:server_script] do
      script when is_binary(script) ->
        script_install(args)

      nil ->
        manual_install(args)
    end
  end

  defp script_install(args) do
    L.info "Invoking install_script (#{args[:server_script]}) on #{args[:ip]}..."

    install_script_args = get_install_script_args(args)

    result = System.cmd "ssh", install_script_args

    case result do
      {_, 0} -> :ok
      {_error, _} -> :error
    end
  end

  defp get_install_script_args(args) do
    ssh_opts = ["-oStrictHostKeyChecking=no", "-oUserKnownHostsFile=/dev/null", "-oLogLevel=ERROR"]
    ["-A"] ++ ssh_opts ++ ["#{args[:user]}@#{args[:ip]}", args[:server_script]]
  end

  defp manual_install(args) do
    ip = args[:ip] |> to_charlist
    user = args[:user] |> to_charlist

    L.info "Installing #{Mix.Project.get!.project[:version]} on #{args[:id]}..."

    {:ok, conn} = S.connect ip: ip, user: user

    {conn, user, ip, args}
    |> place_files
    |> make_current
    |> cleanup_old_releases

    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files({conn, user, ip, opts}) do
    L.info "Settling files on #{opts[:id]}..."
    vsn = Mix.Project.get!.project[:version]
    app = Mix.Project.get!.project[:app]
    path = '/home/#{user}/#{app}/'
    S.cmd! conn, 'mkdir -p #{path}releases/#{vsn}'
    S.cmd! conn, 'mkdir -p #{path}log'
    S.cmd! conn, 'mkdir -p #{path}tmp'
    {:ok, _, 0} = S.run conn,
        'tar --directory #{path}releases/#{vsn}/ ' ++
        '-xf /tmp/#{app}.tar.gz'
    S.cmd! conn, 'ln -sfn #{path}tmp ' ++
                   '#{path}releases/#{vsn}/tmp'
    S.cmd! conn, 'ln -sfn #{path}log ' ++
                   '#{path}releases/#{vsn}/log'
    S.cmd! conn,
        'ln -sfn #{path}releases/#{vsn}/releases/#{vsn} ' ++
        '#{path}releases/#{vsn}/boot'
    S.cmd! conn,
        'ln -sfn #{path}releases/#{vsn}/lib/#{app}-#{vsn}/scripts ' ++
        '#{path}releases/#{vsn}/scripts'
    opts[:additional_folders]
      |> Enum.each(fn(folder) ->
        S.cmd! conn,
            'ln -sfn #{path}releases/#{vsn}/lib/#{app}-#{vsn}/#{folder} ' ++
            '#{path}releases/#{vsn}/#{folder}'
      end)
    {conn, user, ip, opts}
  end

  defp make_current({conn, user, ip, opts}) do
    app = Mix.Project.get!.project[:app]
    vsn = Mix.Project.get!.project[:version]
    L.info "Marking '#{vsn}' as current on #{opts[:id]}..."
    {:ok, _, 0} = S.run conn,'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' ++
                             '/home/#{user}/#{app}/current'
    {conn, user, ip, opts}
  end

  defp cleanup_old_releases({conn, user, ip, opts}) do
    app = Mix.Project.get!.project[:app]
    {:ok, res, 0} = S.run conn, 'ls -t /home/#{user}/#{app}/releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r} on #{opts[:id]}..."
      {:ok, _, 0} = S.run conn, 'rm -fr /home/#{user}/#{app}/releases/#{r}'
    end
    {conn, user, ip, opts}
  end

end
