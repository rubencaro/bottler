defmodule Mix.Tasks.Deploy do

  @moduledoc """
    Build a release file, ship it to remote servers, install it, and restart
    the app. No hot code swap for now.

    Use like: `MIX_ENV=prod mix deploy`
  """

  use Mix.Task

  def run(_args) do
    :ok = Bottler.release
    :ok = Bottler.ship
    :ok = Bottler.install
    :ok = Bottler.restart
    :ok
  end

end
