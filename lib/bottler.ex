
defmodule Bottler do

  @moduledoc """
    Main Bottler module. Exposes entry points for each individual task.
  """

  defdelegate release(config), to: Bottler.Release
  defdelegate publish(config), to: Bottler.Publish
  defdelegate ship(config), to: Bottler.Ship
  defdelegate install(config), to: Bottler.Install
  defdelegate restart(config), to: Bottler.Restart
  defdelegate green_flag(config), to: Bottler.GreenFlag
  defdelegate rollback(config), to: Bottler.Rollback
  defdelegate exec(config, cmd, switches), to: Bottler.Exec

end
