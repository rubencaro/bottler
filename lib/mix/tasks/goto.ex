require Bottler.Helpers, as: H

defmodule Mix.Tasks.Goto do

  @moduledoc """
    Use like `mix goto servername`

    It opens an SSH session on a new terminal window on the server with given name.
    If `all` is given as a server name, then one terminal is open for each configured server.
    The actual `terminal` command can be configured as a template.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.install` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    H.set_prod_environment
    c = H.read_and_validate_config
      |> H.inline_resolve_servers

    args
    |> get_names(c)
    |> Enum.each(&open_terminal(&1, c))

    Process.sleep(2_000)

    :ok
  end

  defp get_names(args, config) do
    name = args |> List.first |> String.to_atom
    case name do
      :all -> config[:servers] |> Keyword.keys
      x -> [x]
    end
  end

  defp open_terminal(name, config) do
    if not name in Keyword.keys(config[:servers]),
      do: raise "Server not found by that name"

    ip = config[:servers][name][:ip]

    spawn_link(fn ->
      config[:goto][:terminal]
      |> EEx.eval_string(title: "#{name}", command: "ssh #{config[:remote_user]}@#{ip}")
      |> to_charlist |> :os.cmd
    end)
  end

end
