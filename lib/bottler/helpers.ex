require Logger, as: L

defmodule Bottler.Helpers do

  @doc """
    Run given function in different Tasks. One `Task` for each entry on given
    list. Each entry on list will be given as args for the function.

    Explodes if `timeout` is reached waiting for any particular task to end.

    Once run, each return value from each task is compared with `expected`.
    It returns `:ok` if _every_ task returned as expected. If `include_results`
    is `true`, then returns `{:ok, results}`.

    If any task did not return as expected, then it returns `{:error, results}`.
  """
  def in_tasks(list, fun, opts) do
    expected = opts |> Keyword.get(:expected, :ok)
    timeout = opts |> Keyword.get(:timeout, 60_000)
    include_results = opts |> Keyword.get(:include_results, false)

    tasks = for args <- list, into: [], do: Task.async(fn -> fun.(args) end)
    results = for t <- tasks, into: [], do: Task.await(t, timeout)
    sign = if Enum.all?(results, &(&1 == expected)), do: :ok, else: :error
    if not include_results and sign == :ok, do: :ok, else: {sign, results}
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
