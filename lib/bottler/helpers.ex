require Logger, as: L

defmodule Bottler.Helpers do

  @doc """
    Run given function in different Tasks. One `Task` for each entry on given
    list. Each entry on list will be given as args for the function.

    Explodes if `timeout` is reached waiting for any particular task to end.

    Once run, each return value from each task is compared with `expected`.
    It returns `{:ok, results}` if _every_ task returned as expected.

    If any task did not return as expected, then it returns `{:error, results}`.

    If `inspect_results` is `true` then results are inspected before return.
    This is useful when returned value is a char list and is to be printed to
    stdout.
  """
  def in_tasks(list, fun, opts) do
    expected = opts |> Keyword.get(:expected, :ok)
    timeout = opts |> Keyword.get(:timeout, 60_000)
    inspect_results = opts |> Keyword.get(:inspect_results, false)

    # run and get results
    tasks = for args <- list, into: [], do: Task.async(fn -> fun.(args) end)
    results = for t <- tasks, into: [], do: Task.await(t, timeout)

    # figure out return value
    sign = if Enum.all?(results, &(&1 == expected)), do: :ok, else: :error
    if inspect_results, do: {sign, results}, else: {sign, inspect(results)}
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

    # destroy other environments' traces
    for p <- File.ls!("_build"), p != to_string(Mix.env),
      do: {:ok, _} = File.rm_rf("_build/#{p}")

    :ok
  end

  @doc """
    Writes an Elixir/Erlang term to the provided path
  """
  def write_term(path, term),
    do: :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [term]))

  @doc """
    Reads a file as Erlang terms
  """
  def read_terms(path), do: :file.consult('#{path}')

end
