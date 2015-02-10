require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Ship do

  @moduledoc """
    Code to place a release file on remote servers. No more, no less.
  """

  @doc """
    Copy local release file to remote servers
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def ship(config) do
    L.info "Shipping to #{config[:servers] |> Keyword.keys |> Enum.join(",")}..."

    app = Mix.Project.get!.project[:app]
    config[:servers] |> Keyword.values |> H.in_tasks( fn(args) ->
        args = args ++ [remote_user: config[:remote_user]]
        "scp rel/#{app}.tar.gz <%= remote_user %>@<%= ip %>:/tmp/"
            |> EEx.eval_string(args) |> to_char_list |> :os.cmd
      end, expected: [], to_s: true)
  end

end
