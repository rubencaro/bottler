require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Restart do

  @moduledoc """
    Restart the VM to apply the installed release.
  """

  @doc """
    Restart app on remote servers.
    It merely touches `app/tmp/restart`, so something like
    [Harakiri](http://github.com/elpulgardelpanda/harakiri) should be running
    on server.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def restart(config) do
    L.info "Restarting #{config[:servers] |> Keyword.keys |> Enum.join(",")}..."

    app = Mix.Project.get!.project[:app]
    config[:servers] |> Keyword.values |> H.in_tasks( fn(args) ->
        args = args ++ [remote_user: config[:remote_user]]
        "ssh <%= remote_user %>@<%= ip %> 'touch #{app}/tmp/restart'"
          |> EEx.eval_string(args) |> to_char_list |> :os.cmd
      end, expected: [], to_s: true)
  end

end
