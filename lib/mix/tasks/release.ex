require Bottler.Helpers, as: H

defmodule Mix.Tasks.Release do

  @moduledoc """
    Build a release file. Use like `mix release`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix release` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    Bottler.release
  end

end
