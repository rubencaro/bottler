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
      s ++ [user: config[:remote_user],
            additional_folders: config[:additional_folders]]
    end) # add user, additional folders
    |> H.in_tasks(&on_server(&1))
  end

  defp on_server(args) do
    ip = args[:ip] |> to_charlist
    user = args[:user] |> to_charlist

    L.info "Installing #{Mix.Project.get!.project[:version]} on #{args[:id]}..."

    {:ok, conn} = S.connect ip: ip, user: user

    conn
    |> build_data(user, args)
    |> place_files
    |> make_current
    |> cleanup_old_releases

    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files(%{opts: opts} = all) do
    L.info "Settling files on #{opts[:id]}..."

    all
    |> make_paths
    |> extract_release
    |> wire_release
    |> wire_additional_folders

    all
  end

  defp build_data(conn, user, opts) do
    vsn = Mix.Project.get!.project[:version]
    app = Mix.Project.get!.project[:app]
    path = '/home/#{user}/#{app}/'
    rpath = '#{path}releases/#{vsn}'

    %{conn: conn, path: path, rpath: rpath, vsn: vsn,
      app: app, user: user, opts: opts}
  end

  defp make_paths(%{conn: c, path: p, rpath: r} = all) do
    S.cmd! c, 'mkdir -p #{r}'
    S.cmd! c, 'mkdir -p #{p}log'
    S.cmd! c, 'mkdir -p #{p}tmp'
    all
  end

  defp extract_release(%{conn: c, rpath: r, app: a} = all) do
    {:ok, _, 0} = S.run c, 'tar --directory #{r} -xf /tmp/#{a}.tar.gz'
    all
  end

  defp wire_release(all) do
    all
    |> wire_global_into_release
    |> wire_release_into_global
  end

  defp wire_global_into_release(%{conn: c, path: p, rpath: r} = all) do
    S.cmd! c, 'ln -sfn #{p}tmp #{r}/tmp'
    S.cmd! c, 'ln -sfn #{p}log #{r}/log'
    all
  end

  defp wire_release_into_global(%{conn: c, rpath: r, vsn: v, app: a} = all) do
    S.cmd! c, 'ln -sfn #{r}/releases/#{v} #{r}/boot'
    S.cmd! c, 'ln -sfn #{r}/lib/#{a}-#{v}/scripts #{r}/scripts'
    all
  end

  defp wire_additional_folders(%{conn: c, rpath: r, vsn: v, app: a, opts: o}) do
    o[:additional_folders]
    |> Enum.each(fn(folder) ->
      S.cmd! c, 'ln -sfn #{r}/lib/#{a}-#{v}/#{folder} #{r}/#{folder}'
    end)
  end

  defp make_current(%{conn: c, vsn: v, path: p, rpath: r, opts: o} = all) do
    L.info "Marking '#{v}' as current on #{o[:id]}..."
    {:ok, _, 0} = S.run c,'ln -sfn #{r} #{p}current'
    all
  end

  defp cleanup_old_releases(%{conn: c, path: p, opts: o}) do
    {:ok, res, 0} = S.run c, 'ls -t #{p}releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r} on #{o[:id]}..."
      {:ok, _, 0} = S.run c, 'rm -fr #{p}releases/#{r}'
    end
  end

end
