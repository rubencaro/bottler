
defmodule Bottler do

  @moduledoc """
    Main Bottler module. Exposes entry points for each individual task.
  """

  defdelegate release(config), to: Bottler.Release
  defdelegate ship(config), to: Bottler.Ship
  defdelegate install(config), to: Bottler.Install
  defdelegate restart(config), to: Bottler.Restart
  defdelegate rollback(config), to: Bottler.Rollback
  defdelegate helper_scripts(config), to: Bottler.HelperScripts
  defdelegate exec(config, cmd, switches), to: Bottler.Exec

end
