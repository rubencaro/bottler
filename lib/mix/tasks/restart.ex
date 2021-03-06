require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.Restart do

  @moduledoc """
    Touch `tmp/restart` on configured remote servers.
    That expects to have `Harakiri` or similar software reacting to that.
    Use like `mix bottler.restart`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.restart` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    {switches, _} = H.parse_args!(args)

    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers(switches)
    {:ok, _} = B.restart c
    :ok
  end

end
