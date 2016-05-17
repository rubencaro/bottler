require Bottler.Helpers, as: H
alias Bottler, as: B

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
    name = args |> List.first |> String.to_existing_atom

    H.set_prod_environment
    c = H.read_and_validate_config

    ip = c[:servers][name][:ip]

    c[:goto][:terminal]
    |> EEx.eval_string(title: "#{name}", command: "ssh #{c[:remote_user]}@#{ip}")
    |> to_char_list |> :os.cmd

    :ok
  end

end
