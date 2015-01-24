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
  def install(servers) do
    :ssh.start
    servers |> Keyword.values |> H.in_tasks( fn(args) -> on_server(args) end )
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list

    L.info "Installing #{Mix.Project.get!.project[:version]} on #{ip}..."

    {:ok, conn} = :ssh.connect(ip, 22,
                        [{:user,user},{:silently_accept_hosts,true}], 5000)

    place_files conn, user
    make_current conn, user
    cleanup_old_releases conn, user
    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files(conn, user) do
    L.info "Settling files..."
    vsn = Mix.Project.get!.project[:version]
    app = Mix.Project.get!.project[:app]
    SSH.cmd! conn, 'mkdir -p /home/#{user}/#{app}/releases/#{vsn}'
    SSH.cmd! conn, 'mkdir -p /home/#{user}/#{app}/pipes'
    SSH.cmd! conn, 'mkdir -p /home/#{user}/#{app}/log'
    SSH.cmd! conn, 'mkdir -p /home/#{user}/#{app}/tmp'
    {:ok, _, 0} = SSH.run conn,
          'tar --directory /home/#{user}/#{app}/releases/#{vsn}/ ' <>
          '-xf /tmp/#{app}.tar.gz'
    SSH.cmd! conn, 'ln -sfn /home/#{user}/#{app}/tmp ' <>
                   '/home/#{user}/#{app}/releases/#{vsn}/tmp'
    SSH.cmd! conn,
          'ln -sfn /home/#{user}/#{app}/releases/#{vsn}/releases/#{vsn} ' <>
          '/home/#{user}/#{app}/releases/#{vsn}/boot'
  end

  defp make_current(conn, user) do
    L.info "Marking release as current..."
    app = Mix.Project.get!.project[:app]
    vsn = Mix.Project.get!.project[:version]
    {:ok, _, 0} = SSH.run conn,
                            'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' <>
                            ' /home/#{user}/#{app}/current'
  end

  defp cleanup_old_releases(conn, user) do
    L.info "Cleaning up old releases..."
    app = Mix.Project.get!.project[:app]
    {:ok, res, 0} = SSH.run conn, 'ls -t /home/#{user}/#{app}/releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r}..."
      {:ok, _, 0} = SSH.run conn, 'rm -fr /home/#{user}/#{app}/releases/#{r}'
    end
  end

end
