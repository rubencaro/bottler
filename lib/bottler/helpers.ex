require Logger, as: L

defmodule Bottler.Helpers do

  @doc """
    Run given function in different Tasks.
    One `Task` for each entry on given list.
    Each entry on list will be given as args for the function.
    Explodes if `timeout` is reached waiting for any particular task to end.

    Returns a list with the results got from each `Task`.
  """
  def in_tasks(list, fun, timeout \\ 60_000) do
    tasks = for args <- list, into: [], do: Task.async(fn -> fun.(args) end)
    for t <- tasks, into: [], do: Task.await(t, timeout)
  end

  @doc """
    Set up `prod` environment variables. Be careful, it only applies to newly
    loaded modules.

    If `MIX_ENV` was already set, then it's not overwritten.
  """
  def set_prod_environment do
    if System.get_env("MIX_ENV") do
      L.info "MIX_ENV was already set, not forcing..."
    else
      L.info "Setting up 'prod' environment..."
      System.put_env "MIX_ENV","prod"
      Mix.env :prod
    end
    :ok
  end

end
