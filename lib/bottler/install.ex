require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Install do
  alias Bottler.SSH

  @moduledoc """
    Functions to install an already shipped release on remote servers.
  """

  @mixfile Application.get_env(:bottler, :mixfile)
  @vsn @mixfile.project[:version]
  @app @mixfile.project[:app] |> to_char_list

  @doc """
    Install previously shipped release on remote servers, making it _current_
    release. Actually running release is not touched. Next restart will run
    the new release.
  """
  def install(servers) do
    :ssh.start

    results = servers |> Keyword.values
              |> H.in_tasks( fn(args) -> on_server(args) end )

    all_ok = Enum.all?(results, &(&1 == :ok))
    if all_ok, do: :ok, else: {:error, results}
  end

  defp on_server(args) do
    ip = args[:public_ip] |> to_char_list

    {:ok, conn} = :ssh.connect(ip, 22,
                        [{:user,'myuser'},{:silently_accept_hosts,true}], 5000)

    L.info "Installing #{@vsn}..."

    place_files conn
    make_current conn
    cleanup_old_releases conn
    :ok
  end

  # Decompress release file, put it in place, and make needed movements
  #
  defp place_files(conn) do
    L.info "Settling files..."
    SSH.cmd! conn, 'mkdir -p /home/myuser/#{@app}/releases/#{@vsn}'
    SSH.cmd! conn, 'mkdir -p /home/myuser/#{@app}/pipes'
    SSH.cmd! conn, 'mkdir -p /home/myuser/#{@app}/log'
    SSH.cmd! conn, 'mkdir -p /home/myuser/#{@app}/tmp'
    {:ok, _, 0} = SSH.run conn,
          'tar --directory /home/myuser/#{@app}/releases/#{@vsn}/ ' <>
          '-xf /tmp/#{@app}.tar.gz'
    SSH.cmd! conn, 'ln -sfn /home/myuser/#{@app}/tmp ' <>
                   '/home/myuser/#{@app}/releases/#{@vsn}/tmp'
    SSH.cmd! conn,
          'ln -sfn /home/myuser/#{@app}/releases/#{@vsn}/releases/#{@vsn} ' <>
          '/home/myuser/#{@app}/releases/#{@vsn}/boot'
  end

  defp make_current(conn) do
    L.info "Marking release as current..."
    {:ok, _, 0} = SSH.run conn,
                            'ln -sfn /home/myuser/#{@app}/releases/#{@vsn} ' <>
                            ' /home/myuser/#{@app}/current'
  end

  defp cleanup_old_releases(conn) do
    L.info "Cleaning up old releases..."
    {:ok, res, 0} = SSH.run conn, 'ls -t /home/myuser/#{@app}/releases'
    excess_releases = res |> String.split("\n") |> Enum.slice(5..-2)

    for r <- excess_releases do
      L.info "Cleaning up old #{r}..."
      {:ok, _, 0} = SSH.run conn, 'rm -fr /home/myuser/#{@app}/releases/#{r}'
    end
  end

end
