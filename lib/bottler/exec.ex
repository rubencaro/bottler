require Logger, as: L
require Bottler.Helpers, as: H
alias SSHEx, as: S

defmodule Bottler.Exec do

  @moduledoc """
    Functions to execute shell commands on remote servers, in parallel.
  """

  @doc """
    Executes given shell `command`.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def exec(config, cmd, switches) do
    :ssh.start # sometimes it's not already started at this point...

    config[:servers]
    |> H.prepare_servers
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user] ] end) # add user
    |> Enum.map(fn(s) -> s ++ [ cmd: cmd, switches: switches ] end) # add cmd and switches
    |> H.in_tasks( fn(args) -> on_server(args) end )
  end

  defp on_server(args) do
    ip = args[:ip] |> to_charlist
    user = args[:user] |> to_charlist
    cmd = args[:cmd] |> to_charlist
    id = args[:id]

    L.info "Executing '#{args[:cmd]}' on #{id}..."

    {:ok, conn} = S.connect ip: ip, user: user

    conn
    |> S.stream(cmd, exec_timeout: args[:switches][:timeout])
    |> Enum.each(fn(x)->
      case x do
        {:stdout,row}    -> process_stdout(id, row)
        {:stderr,row}    -> process_stderr(id, row)
        {:status,status} -> process_exit_status(id, status)
        {:error,reason}  -> process_error(id, reason)
      end
    end)

    :ok
  end

  defp process_stdout(id, row), do: "#{id}: #{inspect row}" |> L.info
  defp process_stderr(id, row), do: "#{id}: #{inspect row}" |> L.warn
  defp process_error(id, reason), do: "#{id}: Failed, reason: #{inspect reason}" |> L.error
  defp process_exit_status(id, status),
    do: "#{id}: Ended with status #{inspect status}" |> L.info

end
