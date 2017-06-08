require Logger, as: L
require Bottler.Helpers, as: H
alias SSHEx, as: S
alias Keyword, as: K

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
    |> Enum.map(fn(s) -> s ++ [user: config[:remote_user]] end) # add user
    |> Enum.map(fn(s) -> s ++ [rsa_pass_phrase: config[:rsa_pass_phrase]] end) # add rsa_pass_phrase
    |> Enum.map(fn(s) -> s ++ [cmd: cmd, switches: switches] end) # add cmd and switches
    |> H.in_tasks(fn(args) -> on_server(args) end)
  end

  defp on_server(args) do
    args = clean_args(args)
    id = args[:id]

    L.info "Executing '#{args[:cmd]}' on #{id}..."

    {:ok, conn} = [
        ip: args[:ip],
        user: args[:user]
      ]
      |> H.run_if(args[:rsa_pass_phrase], &(&1 ++ [rsa_pass_phrase: args[:rsa_pass_phrase]]))
      |> Enum.map(fn {k,v} -> {k, v |> to_charlist} end)
      |> S.connect

    conn
    |> S.stream(args[:cmd], exec_timeout: args[:switches][:timeout])
    |> Enum.each(&process_exec_stream(&1, id))

    :ok
  end

  defp process_exec_stream(x, id) do
    case x do
      {:stdout, row}    -> process_stdout(id, row)
      {:stderr, row}    -> process_stderr(id, row)
      {:status, status} -> process_exit_status(id, status)
      {:error, reason}  -> process_error(id, reason)
    end
  end

  defp clean_args(args) do
    args
    |> K.put(:ip, args[:ip] |> to_charlist)
    |> K.put(:user, args[:user] |> to_charlist)
    |> K.put(:cmd, args[:cmd] |> to_charlist)
  end

  defp process_stdout(id, row), do: "#{id}: #{inspect row}" |> L.info
  defp process_stderr(id, row), do: "#{id}: #{inspect row}" |> L.warn
  defp process_error(id, reason), do: "#{id}: Failed, reason: #{inspect reason}" |> L.error
  defp process_exit_status(id, status),
    do: "#{id}: Ended with status #{inspect status}" |> L.info

end
