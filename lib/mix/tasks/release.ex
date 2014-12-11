defmodule Mix.Tasks.Release do

  @moduledoc """
    Build a release file. Use like: `MIX_ENV=prod mix release`
  """

  use Mix.Task

  def run(_args) do
    Bottler.release
  end

end
