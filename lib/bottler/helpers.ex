require Logger, as: L
alias Keyword, as: K

defmodule Bottler.Helpers do

  @doc """
    Parses given args using OptionParser with given opts.
    Raises ArgumentError if any unknown argument found.
  """
  def parse_args!(args, opts \\ []) do
    {switches, remaining_args, unknown} = OptionParser.parse(args, opts)

    case unknown do
      [] -> {switches, remaining_args}
      x -> raise ArgumentError, message: "Unknown arguments: #{inspect x}"
    end
  end

  @doc """
    Convenience to get environment bits. Avoid all that repetitive
    `Application.get_env( :myapp, :blah, :blah)` noise.
  """
  def env(key, default \\ nil), do: env(:bottler, key, default)
  def env(app, key, default), do: Application.get_env(app, key, default)

  @doc """
    Get current app's name
  """
  def app, do: Mix.Project.get!.project[:app]

  @doc """
    Chop final end of line chars to given string
  """
  def chop(s), do: String.replace(s, ~r/[\n\r\\"]/, "")

  @doc """
  Spit to output any passed variable, with location information.

  If `sample` option is given, it should be a float between 0.0 and 1.0.
  Output will be produced randomly with that probability.

  Given `opts` will be fed straight into `inspect`. Any option accepted by it should work.
  """
  defmacro spit(obj \\ "", opts \\ []) do
    quote do
      opts = unquote(opts)
      obj = unquote(obj)
      opts = Keyword.put(opts, :env, __ENV__)

      Bottler.Helpers.maybe_spit(obj, opts, opts[:sample])
      obj  # chainable
    end
  end

  @doc false
  def maybe_spit(obj, opts, nil), do: do_spit(obj, opts)
  def maybe_spit(obj, opts, prob) when is_float(prob) do
    if :rand.uniform <= prob, do: do_spit(obj, opts)
  end

  defp do_spit(obj, opts) do
    %{file: file, line: line} = opts[:env]
    name = Process.info(self())[:registered_name]
    chain = [ :bright, :red, "\n\n#{file}:#{line}", :normal, "\n     #{inspect self()}", :green," #{name}"]

    msg = inspect(obj, opts)
    chain = chain ++ [:red, "\n\n#{msg}"]

    (chain ++ ["\n\n", :reset]) |> IO.ANSI.format(true) |> IO.puts
  end

  @doc """
  Print to stdout a _TODO_ message, with location information.
  """
  defmacro todo(msg \\ "") do
    quote do
      %{file: file, line: line} = __ENV__
      [ :yellow, "\nTODO: #{file}:#{line} #{unquote(msg)}\n", :reset]
      |> IO.ANSI.format(true)
      |> IO.puts
      :todo
    end
  end

  @doc """
    Pipable log. Calls Logger and then returns first argument.
    Second argument is a template, or a function returning a template.
    To render the template `EEx` will be used, and the first argument will be passed.
  """
  def pipe_log(obj, template, opts \\ [])
  def pipe_log(obj, fun, opts) when is_function(fun) do
    pipe_log(obj, fun.(obj), opts)
  end
  def pipe_log(obj, template, opts) do
    opts = opts |> defaults(level: :info)

    msg = template |> EEx.eval_string(data: obj)
    :ok = L.log opts[:level], msg
    obj
  end

  @doc """
    Run given function in different Tasks. One `Task` for each entry on given
    list. Each entry on list will be given as args for the function.

    Returns a tuple `{global_sign, results}`.

    Being `global_sign` either `:ok` or `:error`, depending on the results
    of all tasks as a whole. And being `results` a list with the result for
    each task in the form of `{:ok, result}` or `{:error, reason}`

    Once every task is run, `global_sign` is determined by comparing each
    return value from each task with given `expected` (`:ok` by default).
    It will be `:ok` if _every_ task returned as expected. `:error` otherwise.
  """
  def in_tasks(list, fun, opts \\ []) do
    opts = Keyword.merge([expected: :ok, timeout: 60_000], opts)

    # run in tasks
    tasks = for args <- list do
        Task.async(fn ->
          try do fun.(args) rescue e -> {:error, e} catch e -> {:error, e} end
        end)
      end

    # get results, format them, and clean up
    results = tasks |> Task.yield_many(opts[:timeout])  # get results within timeout
      |> Enum.map(fn {task, res} ->
        case res || Task.shutdown(task, :brutal_kill) do # kill remaining tasks
          nil -> {:error, "Timeout after #{opts[:timeout]}msecs"}  # label timeout errors
          {:ok, {:error, r}} -> {:error, r}  # label caught errors
          x -> x
        end
      end)

    # figure out global sign
    sign = if Enum.all?(results, &(elem(&1, 1) == opts[:expected])),
              do: :ok, else: :error

    {sign, results}
  end

  @doc """
  Useful to ease results processing as a big string.
  """
  def labelled_to_string({label, any}), do: {label, to_string(any)}

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
          ship: [],
          green_flag: [],
          goto: [terminal: "terminator -T '<%= title %>' -e '<%= command %>' &"] ]
        |> K.merge(Application.get_env(:bottler, :params))

    if not is_valid_servers_list?(c[:servers]),
      do: raise ":bottler :servers should look like \n" <>
                "    [srvname: [ip: '' | rest ] | rest ]\n" <>
                "or [gce_project: \"project-id\"]\n" <>
                "but it was\n    #{inspect c[:servers]}"

    c
  end

  def validate_branch(config) do
    case check_active_branch(config[:forced_branch]) do
      true -> config
      false -> L.error "You are not in branch '#{config[:forced_branch]}'."
        raise "WrongBranchError"
    end
  end

  defp check_active_branch(nil), do: true
  defp check_active_branch(branch) do
    "git branch 2> /dev/null | sed -e '/^[^*]/d' -e \"s/* \\(.*\\)/\\1/\""
    |> to_charlist
    |> :os.cmd
    |> to_string
    |> String.replace("\n","")
    |> Kernel.==(branch)
  end

  defp is_valid_servers_list?(s) do
    K.keyword?(s) and ( is_gce_servers?(s) or is_default_servers?(s) )
  end

  defp is_default_servers?(s),
    do: Enum.all?(s, fn({_,v})-> :ip in K.keys(v) end)

  defp is_gce_servers?(s),
    do: match?(%{gce_project: _} , Enum.into(s,%{}))

  defp get_servers_type(s) do
    case is_gce_servers?(s) do
      true -> :gce
      false -> case is_default_servers?(s) do
        true -> :default
        false -> :none
      end
    end
  end

  @doc """
    Return the server list, whatever its type is.
    Raises an error if it's not recognised.
  """
  def guess_server_list(config) do
    case get_servers_type(config[:servers]) do
      :default -> config[:servers]  # explicit, non GCE
      :gce -> get_gce_server_list(config)
      :none -> raise "Server list specification not recognised: '#{inspect config[:servers]}'"
    end
  end

  @doc """
    Returns a copy of given config with the servers list well formed,
    and filtered using given parsed switches.
  """
  def inline_resolve_servers(config), do: inline_resolve_servers(config, [])
  def inline_resolve_servers(config, switches) do
    servers_list = guess_server_list(config)
      |> inline_filter_servers(switches[:servers])

    config |> Keyword.put(:servers, servers_list)
  end

  defp inline_filter_servers(servers, nil), do: servers
  defp inline_filter_servers(servers, switch) when is_binary(switch) do
    names = switch |> String.split(",") |> Enum.map(&Regex.compile!(&1))
    servers
    |> Enum.filter(fn({k,_})->
      k = to_string(k)
      names |> Enum.any?(&Regex.match?(&1, k))
    end)
  end

  defp get_gce_server_list(config) do
    L.info "Getting server list from GCE..."

    config
    |> Bottler.Helpers.GCE.instances
    |> Enum.map(fn(i)->
      name = i["name"] |> String.to_atom
      ip = i |> get_nested(["networkInterfaces", 0, "accessConfigs", 0, "natIP"])
      {name, [ip: ip]}
    end)
    |> pipe_log("<%= inspect data %>")
  end

  @doc """
    Adds the `name` and a new `id` element to the given servers `Keyword`.
    It returns a plain list, with a `Keyword` for each server.
  """
  def prepare_servers(servers) do
    servers |> Enum.map(fn({name, values}) ->
      values ++ [ name: name, id: "#{name}(#{values[:ip]})" ]
    end)
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
    Apply given defaults to given Keyword. Returns merged Keyword.

    The inverse of `Keyword.merge`, best suited to apply some defaults in a
    chainable way.

    Ex:
      kw = gather_data
        |> transform_data
        |> H.defaults(k1: 1234, k2: 5768)
        |> here_i_need_defaults

    Instead of:
      kw1 = gather_data
        |> transform_data
      kw = [k1: 1234, k2: 5768]
        |> Keyword.merge(kw1)
        |> here_i_need_defaults

  """
  def defaults(args, defs) do
    defs |> Keyword.merge(args)
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

  @doc """
    Log local and remote versions of erts
  """
  def check_erts_versions(config) do
    :ssh.start # just in case

    local_release = :erlang.system_info(:version) |> to_string

    remote_releases = config[:servers] |> K.values
      |> in_tasks( fn(args)->
        user = config[:remote_user] |> to_charlist
        ip = args[:ip] |> to_charlist
        {:ok, conn} = SSHEx.connect(ip: ip, user: user)
        cmd = "source ~/.bash_profile && erl -eval 'erlang:display(erlang:system_info(version)), halt().'  -noshell" |> to_charlist
        SSHEx.cmd!(conn, cmd)
        |> String.replace(~r/[\n\r\\"]/, "")
        |> Kernel.<>(" on #{ip}")
      end)
      |> elem(1)
      |> Enum.map(&elem(&1, 1))

    level = if Enum.all?(remote_releases, &( local_release == &1 |> String.split(" ") |> List.first )), do: :info, else: :error

    L.log level, "Compiling against Erlang/OTP release #{local_release}. Remote releases are #{Enum.map_join(remote_releases, ", ", &(&1))}."

    if level == :error, do: raise "Aborted release"
  end

  @doc """
  Get the value at given coordinates inside the given nested structure.
  The structure must be composed of `Map`, `Keyword` and `List`.

  If coordinates do not exist `nil` is returned.
  """
  def get_nested(data, []), do: data
  def get_nested(data, [key | rest]) when is_map(data) do
    data |> Map.get(key) |> get_nested(rest)
  end
  def get_nested([{_key, _value} | _rest] = data, [key | rest]) when is_atom(key) do
    data |> Keyword.get(key) |> get_nested(rest)
  end
  def get_nested(data, [key | rest]) when is_list(data) and is_integer(key) do
    data |> Enum.at(key) |> get_nested(rest)
  end
  def get_nested(_, _), do: nil
  def get_nested(data, keys, default), do: get_nested(data, keys) || default

  @doc """
  Put given `value` on given coordinates inside the given structure.
  The structure must be composed of `Map`, `Keyword` and `List`.
  Returns updated structure.

  `value` can be a function that will be run only when the value is needed.

  If coordinates do not exist, needed structures are created.
  """
  def put_nested(nil, [key], value) when is_integer(key) or is_atom(key),
    do: put_nested([], [key], value)
  def put_nested(nil, [key | _] = keys, value) when is_integer(key) or is_atom(key),
    do: put_nested([], keys, value)
  def put_nested(nil, [key], value),
    do: put_nested(%{}, [key], value)
  def put_nested(nil, keys, value),
    do: put_nested(%{}, keys, value)

  def put_nested(data, [key], value) when is_function(value),
    do: put_nested(data, [key], value.())
  def put_nested(data, [key], value) when is_map(data) do
    {_, v} = Map.get_and_update(data, key, &({&1, value}))
    v
  end
  def put_nested([], [key], value) when is_atom(key),
    do: Keyword.put([], key, value)
  def put_nested([{_key, _value} | _rest] = data, [key], value) when is_atom(key) do
    {_, v} = Keyword.get_and_update(data, key, &({&1, value}))
    v
  end
  def put_nested(data, [key], value) when is_list(data) and is_integer(key) do
    case Enum.count(data) <= key do
      true -> data |> grow_list(key + 1) |> put_nested([key], value)
      false -> List.update_at(data, key, fn(_) -> value end)
    end
  end
  # `data` is not a `Map`, `Keyword` or `List`, so it's already a replaceable value.
  def put_nested(_data, [key], value), do: put_nested(nil, [key], value)

  def put_nested(data, [key | rest], value) when is_map(data) do
    {_, v} = Map.get_and_update(data, key, &({&1, put_nested(&1, rest, value)}))
    v
  end
  def put_nested([{_key, _value} | _rest] = data, [key | rest], value) when is_atom(key) do
    {_, v} = Keyword.get_and_update(data, key, &({&1, put_nested(&1, rest, value)}))
    v
  end
  def put_nested(data, [key | rest] = keys, value) when is_list(data) and is_integer(key) do
    case Enum.count(data) <= key do
      true -> data |> grow_list(key + 1) |> put_nested(keys, value)
      false -> List.update_at(data, key, &put_nested(&1, rest, value))
    end
  end

  @doc """
  Updates given coordinates inside the given structure with given `fun`.
  The structure must be composed of `Map`, `Keyword` and `List`.
  Returns updated structure.

  `fun` must be a function. It will be passed the previous value, or `nil`.

  If coordinates do not exist, needed structures are created.
  """
  def update_nested(data, keys, fun) when is_function(fun),
    do: put_nested(data, keys, fun.(get_nested(data, keys)))

  @doc """
  Drops whatever is on given coordinates inside given structure.
  The structure must be composed of `Map, `Keyword` and `List`.
  Returns the updated structure.

  If coordinates do not exist nothing bad happens.

      iex> %{a: [%{b: 123}, "hey"]} |> Alfred.Helpers.drop_nested([:a, 0, :c])
      %{a: [%{b: 123}, "hey"]}
      iex> %{a: [%{b: 123, c: [:thing]}, "hey"]} |> Alfred.Helpers.drop_nested([:a, 0, :c])
      %{a: [%{b: 123}, "hey"]}
      iex> %{a: [%{b: 123, c: [:thing]}, "hey"]} |> Alfred.Helpers.drop_nested([:a])
      %{}

      iex> %{a: [[b: 123], "hey"]} |> Alfred.Helpers.drop_nested([:a, 0, :c])
      %{a: [[b: 123], "hey"]}
      iex> %{a: [[b: 123, c: [:thing]], "hey"]} |> Alfred.Helpers.drop_nested([:a, 0, :c])
      %{a: [[b: 123], "hey"]}

  """
  def drop_nested(data, [key]) when is_map(data), do: Map.drop(data, [key])
  def drop_nested(data, [key]) when is_list(data) and is_atom(key),
    do: Keyword.drop(data, [key])
  def drop_nested(data, [key]) when is_list(data), do: List.delete_at(data, key)
  def drop_nested(data, keys), do: drop_nested(data, keys, data, keys)

  def drop_nested(data, [key, last], orig, keys) do
    next = data |> get_nested([key])
    case next |> has_key?(last) do
      false -> orig
      true -> put_nested(orig, Enum.drop(keys, -1), drop_nested(next, [last]))
    end
  end
  def drop_nested(data, [key | rest], orig, keys) when is_map(data) do
    data |> Map.get(key) |> drop_nested(rest, orig, keys)
  end
  def drop_nested(data, [key | rest], orig, keys) when is_list(data) and is_atom(key) do
    data |> Keyword.get(key) |> drop_nested(rest, orig, keys)
  end
  def drop_nested(data, [key | rest], orig, keys) when is_list(data) do
    data |> Enum.at(key) |> drop_nested(rest, orig, keys)
  end

  @doc """
  Version of `Map.has_key?/2` that can also be used for `List` and `Keyword`.
  Useful when you must work with a combination of `Map`, `Keyword` and `List`

      iex> %{a: 1, b: 2} |> Alfred.Helpers.has_key?(:a)
      true
      iex> %{a: 1, b: 2} |> Alfred.Helpers.has_key?(:c)
      false

      iex> [a: 1, b: 2] |> Alfred.Helpers.has_key?(:a)
      true
      iex> [a: 1, b: 2] |> Alfred.Helpers.has_key?(:c)
      false

      iex> [:a, :b] |> Alfred.Helpers.has_key?(1)
      true
      iex> [:a, :b] |> Alfred.Helpers.has_key?(2)
      false

  """
  def has_key?(data, key) when is_map(data), do: Map.has_key?(data, key)
  def has_key?([{_key, _value} | _rest] = data, key) when is_atom(key),
    do: Keyword.has_key?(data, key)
  def has_key?(data, key) when is_list(data) and is_integer(key),
    do: Enum.count(data) > key

  @doc """
  Pushes given `thing` into a List on given coordinates inside given structure.
  The structure must be composed of `Map`, `Keyword` and `List`.
  Returns the updated structure.

  If a List already exists on given coordinates, `thing` is pushed onto it.
  If there is nothing on given coordinates, a single element List is created.
  If coordinates do not exist, needed structures are created.
  `{:error, reason}` is returned if there is anything other than a List on given
  coordinates, or anything else fails.

      iex> %{a: [%{b: 123}, "hey"]} |> Alfred.Helpers.push_nested([:a, 0, :c], :thing)
      %{a: [%{b: 123, c: [:thing]}, "hey"]}
      iex> %{a: [%{b: 123}, "hey"]} |> Alfred.Helpers.push_nested([:a], :thing)
      %{a: [%{b: 123}, "hey", :thing]}
      iex> %{a: %{b: 123}} |> Alfred.Helpers.push_nested([:a], :thing)
      {:error, :not_a_list}

      iex> [a: [[b: 123], "hey"]] |> Alfred.Helpers.push_nested([:a, 0, :c], :thing)
      [a: [[c: [:thing], b: 123], "hey"]]

  """
  def push_nested(nil, keys, value), do: put_nested(nil, keys, [value])
  def push_nested(data, [key], value) do
    case get_nested(data, [key]) do
      nil -> put_nested(data, [key], [value])
      list when is_list(list) -> put_nested(data, [key], list ++ [value])
      _ -> {:error, :not_a_list}
    end
  end
  def push_nested(data, [key | rest], value) when is_map(data) do
    {_, v} = Map.get_and_update(data, key, &({&1, push_nested(&1, rest, value)}))
    v
  end
  def push_nested(data, [key | rest], value) when is_list(data) and is_atom(key) do
    {_, v} = Keyword.get_and_update(data, key, &({&1, push_nested(&1, rest, value)}))
    v
  end
  def push_nested(data, [key | rest] = keys, value) when is_list(data) and is_integer(key) do
    case Enum.at(data, key) do
      nil -> data |> grow_list(key + 1) |> push_nested(keys, value)
      _ -> List.update_at(data, key, &push_nested(&1, rest, value))
    end
  end

  @doc """
  Just like `put_nested/3` but only replaces the value on last coordinate level
  if there is no previous value. Intermediate levels are traversed or created as needed.
  The structure must be composed of `Map`, `Keyword` and `List`.
  """
  def merge_nested(nil, keys, value), do: put_nested(nil, keys, value)
  def merge_nested(data, [key], value) do
    case get_nested(data, [key]) do
      nil -> put_nested(data, [key], value)
      _ -> data
    end
  end
  def merge_nested(data, [key | rest], value) when is_map(data) do
    {_, v} = Map.get_and_update(data, key, &({&1, merge_nested(&1, rest, value)}))
    v
  end
  def merge_nested(data, [key | rest], value) when is_list(data) and is_atom(key) do
    {_, v} = Keyword.get_and_update(data, key, &({&1, merge_nested(&1, rest, value)}))
    v
  end
  def merge_nested(data, [key | rest] = keys, value) when is_list(data) and is_integer(key) do
    case Enum.at(data, key) do
      nil -> data |> grow_list(key + 1) |> merge_nested(keys, value)
      _ -> List.update_at(data, key, &merge_nested(&1, rest, value))
    end
  end

  @doc """
  Fills given list with nils until it is of the given length

    iex> require Alfred.Helpers, as: H
    iex> H.grow_list([], 3)
    [nil, nil, nil]
    iex> H.grow_list([1, 2], 3)
    [1, 2, nil]
    iex> H.grow_list([1, 2, 3], 3)
    [1, 2, 3]
    iex> H.grow_list([1, 2, 3, 4], 3)
    [1, 2, 3, 4]

  """
  def grow_list(list, length) do
    count = length - Enum.count(list)
    case count > 0 do
      true -> list ++ List.duplicate(nil, count)
      false -> list
    end
  end
end
