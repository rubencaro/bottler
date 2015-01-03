require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler do

  @servers Application.get_env(:bottler, :servers)
  @app Application.get_env(:bottler, :mixfile).project[:app]

  @moduledoc """

  To run:
  ```
      run_erl -daemon /tmp/#{@app}/pipes/ /tmp/#{@app}/log "erl -boot /tmp/#{@app}/current/start -config /tmp/#{@app}/current/sys -env ERL_LIBS /tmp/#{@app}/lib -sname #{@app}"
  ```
  To attach:
  ```
      to_erl /tmp/#{@app}/pipes/erlang.pipe.1
  ```

  """

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

    response = @servers |> Keyword.values |> H.in_tasks( fn(args) ->
            cmd_str = "scp rel/#{@app}.tar.gz <%= user %><%= ip %>:/tmp/"
                      |> EEx.eval_string(args) |> to_char_list
            :os.cmd(cmd_str)
          end, expected: [])

    case response do
      {:error, results} -> {:error, to_string(results)}
      x -> x
    end
  end

  @doc """
    Install previously shipped release on remote servers.
    Returns `:ok` when done.
  """
  def install, do: Bottler.Install.install(@servers)

  @doc """
    Restart app on remote servers.
    It merely touches `#{@app}/tmp/restart`, so something like
    [Harakiri](http://github.com/elpulgardelpanda/harakiri) should be running
    on server.

    TODO: Wait until _current_ release is seen running.

    Returns `:ok` when done, `{:error, details}` if anything fails.
  """
  def restart do
    L.info "Restarting #{@servers |> Keyword.keys |> Enum.join(",")}..."

    response = @servers |> Keyword.values |> H.in_tasks( fn(args) ->
            cmd_str = "ssh <%= user %>@<%= ip %> 'touch #{@app}/tmp/restart'"
                      |> EEx.eval_string(args) |> to_char_list
            :os.cmd(cmd_str)
          end, expected: [] )

    case response do
      {:error, results} -> {:error, to_string(results)}
      x -> x
    end
  end

end
