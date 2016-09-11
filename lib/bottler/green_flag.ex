require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.GreenFlag do

  @moduledoc """
    Wait for `tmp/alive` to contain the current version number.
  """

  @doc """
    Restart app on remote servers.
    It merely touches `app/tmp/restart`, so something like
    [Harakiri](http://github.com/rubencaro/harakiri) should be running
    on server.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def green_flag(config) do
    green_flag_config = config[:green_flag] |> H.defaults(timeout: 30_000)
    servers = config[:servers] |> H.prepare_servers

    :ssh.start # just in case

    L.info "Waiting for Green Flag on #{servers |> Enum.map(&(&1[:id])) |> Enum.join(",")}..."

    user = config[:remote_user] |> to_charlist
    timeout = green_flag_config[:timeout]

    {sign, _} = servers |> H.in_tasks( &(check_green_flag(&1, user, timeout)) )

    sign
  end

  defp check_green_flag(args, user, timeout) do
    conn = connect(args, user)
    current = get_current_version(conn)
    expiration = now + timeout

    L.info "Waiting for alive version to be #{current} on #{args[:id]}..."

    case wait_for_alive_to_be(conn, current, expiration) do
      :ok -> :ok
      {:timeout, alive} ->
        L.error "Timeout waiting for alive version to be #{current} on #{args[:id]}\n"
                <> "      Alive version was #{alive}"
        :error
    end
  end

  defp connect(args, user) do
    ip = args[:ip] |> to_charlist
    {:ok, conn} = SSHEx.connect(ip: ip, user: user)
    conn
  end

  defp wait_for_alive_to_be(conn, current, expiration) do
    :timer.sleep 1_000
    case {get_alive_version(conn), now} do
      {^current, _} -> :ok
      {v, ts} when ts > expiration -> {:timeout, v}
      _ -> wait_for_alive_to_be(conn, current, expiration)
    end
  end

  defp get_current_version(conn) do
    cmd = "readlink #{H.app}/current | cut -d'/' -f 6" |> to_charlist
    SSHEx.cmd!(conn, cmd) |> H.chop
  end

  defp get_alive_version(conn) do
    cmd = "cat #{H.app}/tmp/alive" |> to_charlist
    SSHEx.cmd!(conn, cmd) |> H.chop
  end

  defp now, do: System.system_time(:milliseconds)

end
