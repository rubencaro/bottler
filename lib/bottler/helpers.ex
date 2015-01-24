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
    use Mix.Config

    if System.get_env("MIX_ENV") do
      L.info "MIX_ENV was already set, not forcing..."
    else
      L.info "Setting up 'prod' environment..."
      System.put_env "MIX_ENV","prod"
      Mix.env :prod
    end

    :ok = "config/config.exs" |> Path.absname
          |>  Mix.Config.import_config |> Mix.Config.persist

    # destroy other environments' traces
    {:ok, _} = File.rm_rf("_build")

    :ok
  end

  @doc """
    Returns `:bottler` config keywords. It also validates they are all set.
    Raises an error if anything looks wrong.
  """
  def read_and_validate_config do
    c = Application.get_env(:bottler, :params)

    L.debug inspect(c)

    if not Keyword.keyword?(c[:servers]),
      do: raise ":bottler :servers should be a keyword list, it was #{inspect c[:servers]}"
    if not Enum.all?(c[:servers], fn({_,v})-> :ip in Keyword.keys(v) end),
      do: raise ":bottler :servers should look like \n" <>
                "    [srvname: [ip: '' | rest ] | rest ]\n" <>
                "but was\n    #{inspect c[:servers]}"

    if not is_binary(c[:remote_user]), do: raise ":bottler :remote_user should be a binary"

    c
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

  @doc """
    Spit to logger any passed variable, with location information if `caller`
    (such as `__ENV__`) is given.
  """
  def spit(obj, caller \\ nil, inspect_opts \\ []) do
    loc = case caller do
      %{file: file, line: line} -> "\n\n#{file}:#{line}"
      _ -> ""
    end
    [ :bright, :red, "#{loc}", :normal, "\n\n#{inspect(obj,inspect_opts)}\n\n", :reset]
    |> IO.ANSI.format(true) |> Logger.info
  end
end
