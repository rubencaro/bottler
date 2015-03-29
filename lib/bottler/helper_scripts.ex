require Logger, as: L
require Bottler.Helpers, as: H
alias Keyword, as: K

defmodule Bottler.HelperScripts do

  @moduledoc """
    Generate helper scripts and put them into PATH.

    See `Mix.Tasks.Bottler.HelperScripts`.
  """

  @doc """
    The main entry point.
    It reads project configuration and generates helper scripts based on them.
    Then puts links to them on PATH to make them usable.

    Returns `:ok` when done. Raises exception if anything fails.
  """
  def helper_scripts(c) do
    L.info "Generating helper scripts..."
    args = %{
      template: Path.expand("lib/helper_scripts") <> "/ssh_server_script.sh.eex",
      dest_path: c[:scripts_folder] |> Path.expand,
      links_path: c[:into_path_folder] |> Path.expand,
      app: Mix.Project.get!.project[:app],
      common: [ port: c[:remote_port],
                user: c[:remote_user] ]
    }

    for {server,_} <- c[:servers],
      do: args |> Map.put(:server, server) |> create_server_script

    # make them executable
    [] = :os.cmd 'chmod -R #{args.dest_path}'

    L.info "Done"
    :ok
  end

  defp create_server_script(p) do
    L.info "  -> #{p.app}_#{p.server}"
    file = "#{p.dest_path}/#{p.app}_#{p.server}"
    vars = p.common |> K.merge [host: p.server]

    # render, write & link
    body = EEx.eval_file p.template, vars
    :ok = File.write file, body, [:write]
    [] = :os.cmd 'ln -s #{file} #{p.links_path}/'
  end

end
