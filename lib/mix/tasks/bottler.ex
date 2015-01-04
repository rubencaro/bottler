require Bottler.Helpers, as: H
alias Bottler, as: B

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
    {:ok, _} = B.release
    {:ok, _} = B.ship
    {:ok, _} = B.install
    {:ok, _} = B.restart
    :ok
  end

end

defmodule Mix.Tasks.Release do

  @moduledoc """
    Build a release file. Use like `mix release`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix release` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    {:ok, _} = B.release
  end

end
