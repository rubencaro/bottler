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
    c = H.read_and_validate_config
    :ok = B.release c
    {:ok, _} = B.ship c
    {:ok, _} = B.install c
    {:ok, _} = B.restart c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Release do

  @moduledoc """
    Build a release file. Use like `mix bottler.release`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.release` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    :ok = B.release c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Ship do

  @moduledoc """
    Ship a release file to configured remote servers.
    Use like `mix bottler.ship`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.ship` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.ship c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Install do

  @moduledoc """
    Install a shipped file on configured remote servers.
    Use like `mix bottler.install`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.install` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.install c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Restart do

  @moduledoc """
    Touch `tmp/restart` on configured remote servers.
    That expects to have `Harakiri` or similar software reacting to that.
    Use like `mix bottler.restart`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.restart` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.restart c
    :ok
  end

end
