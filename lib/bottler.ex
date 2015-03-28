
defmodule Bottler do

  @moduledoc """
    Main Bottler module. Exposes entry points for each individual task.
  """

  @doc """
    Build a release tar.gz. Returns `:ok` when done. Crash otherwise.
  """
  def release(config), do: Bottler.Release.release config

  @doc """
    Copy local release file to remote servers
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def ship(config), do: Bottler.Ship.ship config

  @doc """
    Install previously shipped release on remote servers.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def install(config), do: Bottler.Install.install(config)

  @doc """
    Restart app on remote servers.
    It merely touches `app/tmp/restart`, so something like
    [Harakiri](http://github.com/elpulgardelpanda/harakiri) should be running
    on server.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def restart(config), do: Bottler.Restart.restart(config)

  @doc """
    Restart to the previous version on remote servers.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def rollback(config), do: Bottler.Rollback.rollback(config)

  @doc """
    Generate helper scripts and put them on PATH.
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def helper_scripts(config), do: Bottler.HelperScripts.helper_scripts(config)

end
