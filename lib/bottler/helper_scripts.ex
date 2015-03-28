require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.HelperScripts do

  @moduledoc """
    Generate helper scripts and put them into PATH.

    See `Mix.Tasks.Bottler.HelperScripts`.
  """

  @doc """
    The main entry point.
    It reads project configuration and generates helper scripts based on them.
    Then puts links to them on PATH to make them usable.

    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def helper_scripts(config) do
    L.info "Generating helper scripts..."

    generate_ssh_server_scripts
    link_scripts_to_path
  end

  defp generate_ssh_server_scripts do
    app = Mix.Project.get!.project[:app]
  end

  defp link_scripts_to_path do
  end

end
