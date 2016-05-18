require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.Rollback do

  @moduledoc """
    Simply move the _current_ link to the previous release and restart to
    apply. It's quite faster than to deploy a previous release, that is
    also possible.

    Be careful because the _previous release_ may be different on each server.
    It's up to you to keep all your servers rollback-able (yeah).

    Use like `mix bottler.rollback`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.rollback` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers
    {:ok, _} = B.rollback c
    :ok
  end

end
