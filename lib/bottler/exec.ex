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

    config |> H.guess_server_list |> Keyword.values # each ip
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user] ] end) # add user
    |> Enum.map(fn(s) -> s ++ [ cmd: cmd, switches: switches ] end) # add cmd and switches
    |> H.in_tasks( fn(args) -> on_server(args) end )
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list
    cmd = args[:cmd] |> to_char_list

    L.info "Executing '#{args[:cmd]}' on #{ip}..."

    {:ok, conn} = S.connect ip: ip, user: user

    conn
    |> S.stream(cmd, exec_timeout: args[:switches][:timeout])
    |> Enum.each(fn(x)->
      case x do
        {:stdout,row}    -> process_stdout(ip, row)
        {:stderr,row}    -> process_stderr(ip, row)
        {:status,status} -> process_exit_status(ip, status)
        {:error,reason}  -> process_error(ip, reason)
      end
    end)

    :ok
  end

  defp process_stdout(ip, row), do: "#{ip}: #{inspect row}" |> L.info
  defp process_stderr(ip, row), do: "#{ip}: #{inspect row}" |> L.warn
  defp process_error(ip, reason), do: "#{ip}: Failed, reason: #{inspect reason}" |> L.error
  defp process_exit_status(ip, status),
    do: "#{ip}: Ended with status #{inspect status}" |> L.info

end
