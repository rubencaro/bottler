require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Rollback do
  @moduledoc """
    Simply move the _current_ link to the previous release and restart to
    apply. It's also possible to deploy a previous release, but this is
    quite faster.

    Be careful because the _previous release_ may be different on each server.
    It's up to you to keep all your servers rollback-able (yeah).
  """

  @doc """
    Move the _current_ link to the previous r8elease and restart to apply.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def rollback(config) do
    :ssh.start
    {:ok, _} = config[:servers] |> Keyword.values # each ip
    |> Enum.map(fn(s) -> s ++ [ user: config[:remote_user] ] end) # add user
    |> H.in_tasks( fn(args) -> on_server(args) end )

    Bottler.Restart.restart config
  end

  defp on_server(args) do
    ip = args[:ip] |> to_char_list
    user = args[:user] |> to_char_list

    {:ok, conn} = SSHEx.connect ip: ip, user: user

    previous = get_previous_release conn, user

    L.info "Rollback to #{previous} on #{ip}..."

    shift_current conn, user, previous
    :ok
  end

  defp get_previous_release(conn, user) do
    app = Mix.Project.get!.project[:app]
    {:ok, res, 0} = SSHEx.run conn, 'ls -t /home/#{user}/#{app}/releases'
    res |> String.split |> Enum.at(1)
  end

  defp shift_current(conn, user, vsn) do
    app = Mix.Project.get!.project[:app]
    {:ok, _, 0} = SSHEx.run conn,
                            'ln -sfn /home/#{user}/#{app}/releases/#{vsn} ' ++
                            ' /home/#{user}/#{app}/current'
  end

end
