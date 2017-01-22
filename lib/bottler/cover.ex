defmodule Bottler.Cover do
  @moduledoc """
  Base taken from https://github.com/elixir-lang/elixir/blob/f2e9ac29389b4c4c1220318f24de58a580257dbd/lib/mix/lib/mix/tasks/test.ex#L2

  Just configure in mix.exs as an option of the project:

  ```elixir
  def project do
    [app: :bottler,
     ...,
     test_coverage: [tool: Bottler.Cover, ignored: [Bottler.Helpers]],
     aliases: aliases()]
  end
  ```

  `:tool` should be this module, `:ignored` are modules not to be analysed

  Then run tests by `mix test --cover`.

  To make this the default you can define an alias on mix.exs too. This would
  run both `mix test --cover` and `mix credo` when you run `mix test`:

  ```elixir
  defp aliases do
    [test: ["test --cover", "credo"]]
  end
  ```

  Run `mix test --verbose-cover` to see detailed info about not covered lines.
  """

  defstruct [:rate, :not_covered, :errors, :opts]

  def start(compile_path, opts) do
    {parsed, _, _} = System.argv |> OptionParser.parse(strict: [verbose_cover: :boolean])
    opts = opts |> Keyword.merge(parsed)

    _ = :cover.start

    case :cover.compile_beam_directory(compile_path |> to_charlist) do
      results when is_list(results) ->
        :ok
      {:error, _} ->
        Mix.raise "Failed to cover compile directory: " <> compile_path
    end

    fn() ->
      msg = opts |> get_results |> format_results
      Mix.shell.info "\nCover results ... #{msg}"
    end
  end

  defp get_results(opts) do
    {:result, ok, fail} = opts
      |> get_modules
      |> :cover.analyse(:coverage, :line)

    int = ok
      |> Enum.reject(&match?({{_, 0},_},&1))  # ignore line 0 results
      |> Enum.uniq_by(fn({ml,_}) -> ml end)   # unique for each line
    nc = int
      |> Enum.filter(fn({_, {_, n}}) -> n > 0 end)  # only those with any non covered results

    total = int |> Enum.count
    nc_count = nc |> Enum.count
    rate = (total - nc_count) / total

    %Bottler.Cover{rate: rate, not_covered: nc, errors: fail, opts: opts}
  end

  defp get_modules(opts) do
    ignored = opts[:ignored] || []

    :cover.modules
    |> Kernel.--(ignored)
    |> List.delete(__MODULE__)  # ignore this module too
  end

  defp format_results(%Bottler.Cover{} = data) do
    rate = Float.round(data.rate * 100.0, 2)
    msg = [:bright, rate_color(rate), "#{rate}% coverage\n", :normal]

    if data.opts[:verbose] || data.opts[:verbose_cover] do
      msg
      |> add_not_covered(data.not_covered)
      |> add_errors(data.errors)
      |> IO.ANSI.format
    else
      msg |> IO.ANSI.format
    end
  end

  # red until 50%
  # from red to greenish from 50 to 99%
  # green only for 100%
  defp rate_color(100.0), do: :green
  defp rate_color(r) when r < 50.0, do: :red
  defp rate_color(rate) do
    r = round((150.0 - rate) / 20.0)
    g = round((rate - 50) / 20.0)
    IO.ANSI.color(r, g, 0)
  end

  defp add_not_covered(output, not_covered) do
    Enum.reduce(not_covered, output, fn({{m, l},_}, acc) ->
      acc ++ [:yellow, "\n -> #{m} at line #{l} not covered", :normal]
    end)
  end

  defp add_errors(output, []), do: output
  defp add_errors(output, errors) do
    output ++ ["\nErrors:\n", :red] ++ Enum.intersperse(errors, "\n") ++ [:normal]
  end
end
