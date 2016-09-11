require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Restart do

  @moduledoc """
    Restart the VM to apply the installed release.
  """

  @doc """
    Restart app on remote servers.
    It merely touches `app/tmp/restart`, so something like
    [Harakiri](http://github.com/rubencaro/harakiri) should be running
    on server.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def restart(config) do
    servers = config[:servers] |> H.prepare_servers

    L.info "Restarting #{servers |> Enum.map(&(&1[:id])) |> Enum.join(",")}..."

    app = Mix.Project.get!.project[:app]
    servers |> H.in_tasks( fn(args) ->
        args = args ++ [remote_user: config[:remote_user]]
        "ssh <%= remote_user %>@<%= ip %> 'touch #{app}/tmp/restart'"
          |> EEx.eval_string(args) |> to_charlist |> :os.cmd
      end, expected: [], to_s: true)
  end

end
