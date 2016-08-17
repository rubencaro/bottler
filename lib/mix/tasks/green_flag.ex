require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.GreenFlag do

  @moduledoc """
    Wait for `tmp/alive` to contain the current version on configured remote servers.
    Use like `mix bottler.green_flag`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.green_flag` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    {switches, _} = H.parse_args!(args)

    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers(switches)
    B.green_flag c
  end

end
