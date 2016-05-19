require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.Ship do

  @moduledoc """
    Ship a release file to configured remote servers.
    Use like `mix bottler.ship`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.ship` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    {switches, _} = H.parse_args!(args)

    H.set_prod_environment
    c = H.read_and_validate_config
      |> H.validate_branch
      |> H.inline_resolve_servers(switches)

    {:ok, _} = B.ship c
    :ok
  end

end
