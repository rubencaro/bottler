require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Helpers.Hook do

  @moduledoc """
    Hooks Helper - based on config
  """

  def exec(name, config) do

    case config[:hooks][name] do
      nil -> :ok
      %{command: command, continue_on_fail: continue_on_fail} -> launch(command, continue_on_fail)
    end

  end

  defp launch(command, continue_on_fail) do
    L.info "Launching hook: " <> command <> " ..."
    command
    |> H.cmd
    |> prepare_return(continue_on_fail)
  end

  defp prepare_return(_command_result, true), do: :ok
  defp prepare_return(command_result, false), do: command_result

end
