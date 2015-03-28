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

    generate_ssh_server_scripts config
    link_scripts_to_path config
  end

  # Generate individual `<project>_<server>` scripts in configured
  # `scripts_folder`. They should open an SSH shell to each server.
  #
  defp generate_ssh_server_scripts(config) do
    template = Path.expand("lib/helper_scripts") <> "/ssh_server_script.sh.eex"
    vars = [port: config[:remote_port],
            user: config[:remote_user]]
  end

  defp link_scripts_to_path(config) do
  end

end
