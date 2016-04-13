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
    config[:servers] |> Keyword.values # each ip
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user], additional_folders: config[:additional_folders] ] end) # add user, additional folders
    |> H.in_tasks( fn(args) -> on_server(args) end )
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list

    L.info "Installing #{Mix.Project.get!.project[:version]} on #{ip}..."

    {:ok, conn} = SSHEx.connect ip: ip, user: user

    place_files conn, user, ip, args[:additional_folders]
    make_current conn, user, ip
    cleanup_old_releases conn, user, ip
    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files(conn, user, ip, additional_folders \\ []) do
    L.info "Settling files on #{ip}..."
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
    additional_folders
      |> Enum.each(fn(folder) ->
        S.cmd! conn,
            'ln -sfn #{path}releases/#{vsn}/lib/#{app}-#{vsn}/#{folder} ' ++
            '#{path}releases/#{vsn}/#{folder}'
      end)
  end

  defp make_current(conn, user, ip) do
    L.info "Marking release as current on #{ip}..."
    app = Mix.Project.get!.project[:app]
    vsn = Mix.Project.get!.project[:version]
    {:ok, _, 0} = S.run conn,
                            'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' ++
                            ' /home/#{user}/#{app}/current'
  end

  defp cleanup_old_releases(conn, user, ip) do
    L.info "Cleaning up old releases on #{ip}..."
    app = Mix.Project.get!.project[:app]
    {:ok, res, 0} = S.run conn, 'ls -t /home/#{user}/#{app}/releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r}..."
      {:ok, _, 0} = S.run conn, 'rm -fr /home/#{user}/#{app}/releases/#{r}'
    end
  end

end
