require Logger, as: L
alias Keyword, as: K

defmodule Bottler.Helpers do

  @doc """
    Run given function in different Tasks. One `Task` for each entry on given
    list. Each entry on list will be given as args for the function.

    Explodes if `timeout` is reached waiting for any particular task to end.

    Once run, each return value from each task is compared with `expected`.
    It returns `{:ok, results}` if _every_ task returned as expected.

    If any task did not return as expected, then it returns `{:error, results}`.

    If `to_s` is `true` then results are fed to `to_string` before return.
    This is useful when returned value is a char list and is to be printed to
    stdout.
  """
  def in_tasks(list, fun, opts \\ []) do
    expected = opts |> K.get(:expected, :ok)
    timeout = opts |> K.get(:timeout, 60_000)
    to_s = opts |> K.get(:to_s, false)

    # run and get results
    tasks = for args <- list, into: [], do: Task.async(fn -> fun.(args) end)
    results = for t <- tasks, into: [], do: Task.await(t, timeout)

    # figure out return value
    sign = if Enum.all?(results, &(&1 == expected)), do: :ok, else: :error
    if to_s, do: {sign, to_string(results)},
        else: {sign, results}
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

    res = "config/config.exs" |> Path.absname
          |> Mix.Config.read! |> Mix.Config.persist

    # different responses for Elixir 1.0 and 1.1, we want both
    if not is_ok_response_for_10_and_11(res),
      do: raise "Could not persist the requested config: #{inspect(res)}"

    # destroy other environments' traces, helpful for environment debugging
    # {:ok, _} = File.rm_rf("_build")

    # support dynamic config, force project's compilation
    [] = :os.cmd 'touch config/config.exs'

    :ok
  end

  # hack to allow different responses for Elixir 1.0 and 1.1
  # 1.0 -> :ok
  # 1.1 -> is a list and includes at least bottler config keys
  #
  defp is_ok_response_for_10_and_11(res) do
    case res do
      :ok -> true
      x when is_list(x) -> Enum.all?([:logger,:bottler], fn(i)-> i in res end)
      _ -> false
    end
  end

  @doc """
    Returns `:bottler` config keywords. It also validates they are all set.
    Raises an error if anything looks wrong.
  """
  def read_and_validate_config do
    c = [ scripts_folder: ".bottler/scripts",
          into_path_folder: "~/.local/bin",
          remote_port: 22,
          additional_folders: [],
          ship: [] ]
        |> K.merge(Application.get_env(:bottler, :params))

    L.debug inspect(c)

    if not K.keyword?(c[:servers]),
      do: raise ":bottler :servers should be a keyword list, it was #{inspect c[:servers]}"
    if not Enum.all?(c[:servers], fn({_,v})-> :ip in K.keys(v) end),
      do: raise ":bottler :servers should look like \n" <>
                "    [srvname: [ip: '' | rest ] | rest ]\n" <>
                "but was\n    #{inspect c[:servers]}"

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
    Spit to output any passed variable, with location information.
  """
  defmacro spit(obj \\ "", inspect_opts \\ []) do
    quote do
      %{file: file, line: line} = __ENV__
      name = Process.info(self)[:registered_name]
      chain = [ :bright, :red, "\n\n#{file}:#{line}",
                :normal, "\n     #{inspect self}", :green," #{name}"]

      msg = inspect(unquote(obj),unquote(inspect_opts))
      if String.length(msg) > 2, do: chain = chain ++ [:red, "\n\n#{msg}"]

      # chain = chain ++ [:yellow, "\n\n#{inspect Process.info(self)}"]

      (chain ++ ["\n\n", :reset]) |> IO.ANSI.format(true) |> IO.puts

      unquote(obj)
    end
  end

  @doc """
    Run given command through `Mix.Shell`
  """
  def cmd(command) do
    case Mix.Shell.cmd(command, &(IO.write(&1)) ) do
      0 -> :ok
      _ -> {:error, "Release step failed. Please fix any errors and try again."}
    end
  end

  @doc """
    `ls` with full paths
    Returns the list of full paths. An empty list if anything fails
  """
  def full_ls(path) do
    expanded = Path.expand(path)
    case path |> File.ls do
      {:ok, list} -> Enum.map(list,&( "#{expanded}/#{&1}" ))
      _ -> []
    end
  end

  @doc """
    Delete, then recreate given folders
  """
  def empty_dirs(paths) when is_list(paths) do
    for p <- paths, do: empty_dir(p)
  end

  @doc """
    Delete, then recreate given folder
  """
  def empty_dir(path) do
    File.rm_rf! path
    File.mkdir_p! path
  end
end
