require Bottler.Helpers, as: H

defmodule Mix.Tasks.Deploy do

  @moduledoc """
    Build a release file, ship it to remote servers, install it, and restart
    the app. No hot code swap for now.

    Use like `mix deploy`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix deploy` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    :ok = Bottler.release
    :ok = Bottler.ship
    :ok = Bottler.install
    :ok = Bottler.restart
    :ok
  end

end
