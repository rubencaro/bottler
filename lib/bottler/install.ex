require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Install do
  alias Bottler.SSH

  @moduledoc """
    Functions to install an already shipped release on remote servers.
  """

  @doc """
    Install previously shipped release on remote servers, making it _current_
    release. Actually running release is not touched. Next restart will run
    the new release.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def install(config) do
    :ssh.start
    config[:servers] |> Keyword.values # each ip
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user] ] end) # add user
    |> H.in_tasks( fn(args) -> on_server(args) end )
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list

    L.info "Installing #{Mix.Project.get!.project[:version]} on #{ip}..."

    {:ok, conn} = :ssh.connect(ip, 22,
                        [{:user,user},{:silently_accept_hosts,true}], 5000)

    place_files conn, user, ip
    make_current conn, user, ip
    cleanup_old_releases conn, user, ip
    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files(conn, user, ip) do
    L.info "Settling files on #{ip}..."
    vsn = Mix.Project.get!.project[:version]
    app = Mix.Project.get!.project[:app]
    path = '/home/#{user}/#{app}/'
    SSH.cmd! conn, 'mkdir -p #{path}releases/#{vsn}'
    SSH.cmd! conn, 'mkdir -p #{path}log'
    SSH.cmd! conn, 'mkdir -p #{path}tmp'
    {:ok, _, 0} = SSH.run conn,
        'tar --directory #{path}releases/#{vsn}/ ' ++
        '-xf /tmp/#{app}.tar.gz'
    SSH.cmd! conn, 'ln -sfn #{path}tmp ' ++
                   '#{path}releases/#{vsn}/tmp'
    SSH.cmd! conn, 'ln -sfn #{path}log ' ++
                   '#{path}releases/#{vsn}/log'
    SSH.cmd! conn,
        'ln -sfn #{path}releases/#{vsn}/releases/#{vsn} ' ++
        '#{path}releases/#{vsn}/boot'
    SSH.cmd! conn,
        'ln -sfn #{path}releases/#{vsn}/lib/#{app}-#{vsn}/scripts ' ++
        '#{path}releases/#{vsn}/scripts'
  end

  defp make_current(conn, user, ip) do
    L.info "Marking release as current on #{ip}..."
    app = Mix.Project.get!.project[:app]
    vsn = Mix.Project.get!.project[:version]
    {:ok, _, 0} = SSH.run conn,
                            'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' ++
                            ' /home/#{user}/#{app}/current'
  end

  defp cleanup_old_releases(conn, user, ip) do
    L.info "Cleaning up old releases on #{ip}..."
    app = Mix.Project.get!.project[:app]
    {:ok, res, 0} = SSH.run conn, 'ls -t /home/#{user}/#{app}/releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r}..."
      {:ok, _, 0} = SSH.run conn, 'rm -fr /home/#{user}/#{app}/releases/#{r}'
    end
  end

end
