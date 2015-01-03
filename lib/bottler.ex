require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler do

  @moduledoc """

  To run:
  ```
  run_erl -daemon /tmp/myapp/pipes/ /tmp/myapp/log "erl -boot /tmp/myapp/releases/1.0.0+20141130_3930bc3/start -config /tmp/myapp/releases/1.0.0+20141130_3930bc3/sys -env ERL_LIBS /tmp/myapp/lib -sname myapp"
  ```
  To attach:
  ```
  to_erl /tmp/myapp/pipes/erlang.pipe.1
  ```

  """

  @servers Application.get_env(:bottler, :servers)

  @doc """
    Entry point for `mix release` task. Returns `:ok` when done.
  """
  def release, do: Bottler.Release.release

  @doc """
    Copy local release file to remote servers
    Returns `:ok`, or `{:error, results}`.
  """
  def ship do
    L.info "Shipping to #{@servers |> Keyword.keys |> Enum.join(",")}..."

    results = @servers |> Keyword.values |> H.in_tasks( fn(args) ->
            cmd_str = "scp rel/myapp.tar.gz myuser@<%= public_ip %>:/tmp/"
                      |> EEx.eval_string(args) |> to_char_list
            :os.cmd(cmd_str)
          end )

    all_ok = Enum.all?(results, &(&1 == []))
    if all_ok, do: :ok, else: {:error, to_string(results)}
  end

  @doc """
    Install previously shipped release on remote servers.
    Returns `:ok` when done.
  """
  def install, do: Bottler.Install.install(@servers)

  @doc """
    Restart apps on remote servers. Wait until _current_ release is seen on
    running apps. Returns `:ok` when done.
  """
  def restart do
    L.info "Restarting #{@servers |> Keyword.keys |> Enum.join(",")}..."

    results = @servers |> Keyword.values |> H.in_tasks( fn(args) ->
            cmd_str = "ssh myuser@<%= public_ip %> 'touch myapp/tmp/restart'"
                      |> EEx.eval_string(args) |> to_char_list
            :os.cmd(cmd_str)
          end )

    all_ok = Enum.all?(results, &(&1 == []))
    if all_ok, do: :ok, else: {:error, to_string(results)}
  end

end
