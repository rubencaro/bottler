require Bottler.Helpers, as: H

defmodule Mix.Tasks.Goto do

  @moduledoc """
    Use like `mix goto servername`

    It opens an SSH session on a new terminal window on the server with given name.
    The actual `terminal` command can be configured as a template.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.install` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    name = args |> List.first |> String.to_atom

    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers

    if not name in Keyword.keys(c[:servers]),
      do: raise "Server not found by that name"

    ip = c[:servers][name][:ip]

    spawn_link(fn->
      c[:goto][:terminal]
      |> EEx.eval_string(title: "#{name}", command: "ssh #{c[:remote_user]}@#{ip}")
      |> to_charlist |> :os.cmd
    end)

    Process.sleep(2_000)

    :ok
  end

end
