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
    Returns `:bottler` config keywords. It also validates they are all set.
  """
  def read_and_validate_config do
    servers = Application.get_env(:bottler, :servers) |> validate :servers
    mixfile = Application.get_env(:bottler, :mixfile) |> validate :mixfile
    [servers: servers, mixfile: mixfile]
  end

  # raise if anything looks not ok
  defp validate(nil, key), do: raise ":bottler '#{key}' is not set on config!"

  defp validate(val, :servers) when is_list(val) do
    if not is_servers_spec?(val),
      do: raise ":bottler :servers should look like \n" <>
                "    [srvname: [user: '', ip: ''], ... ]\n" <>
                "but was\n    #{inspect val}"
    val
  end

  defp validate(val, :mixfile) when is_atom(val), do: val

  defp validate(val, key),
    do: raise ":bottler '#{key}' is set to unexpected value: #{val}"

  # validate servers kw format
  defp is_servers_spec?([{_name,[{:user,_},{:ip,_}]} | rest]),
    do: is_servers_spec?(rest)
  defp is_servers_spec?([]), do: true
  defp is_servers_spec?(_),  do: false

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
