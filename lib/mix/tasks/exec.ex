require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.Exec do

  @moduledoc """
    Execute given commmand on configured remote servers.
    Use like `mix bottler.exec 'ls -alt some/path'`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.install` to force it to `other_env`.
  """

  use Mix.Task

  def run(args) do
    {switches, remaining_args} = H.parse_args!(args, switches: [timeout: :integer])

    # clean args
    cmd = remaining_args |> List.first  # the first non-switch argument
    switches = switches |> H.defaults(timeout: 30_000)

    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers(switches)
    {:ok, _} = B.exec c, cmd, switches
    :ok
  end

end
