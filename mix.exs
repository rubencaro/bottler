defmodule Bottler.Mixfile do
  use Mix.Project

  def project do
    [app: :bottler,
     version: "0.8.0",
     elixir: ">= 1.0.0",
     package: package(),
     description: "Help you bottle, ship and serve your Elixir apps.",
     deps: deps(),
     test_coverage: [tool: Bottler.Cover, ignored: []],
     aliases: aliases()]
  end

  def application do
    [ applications: [:logger, :crypto],
      included_applications: [:public_key, :asn1, :iex] ]
  end

  defp package do
    [maintainers: ["Rubén Caro"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/rubencaro/bottler"}]
  end

  defp deps do
    [{:sshex, ">= 2.1.2"},
     {:credo, "~> 0.6", only: [:dev, :test]},
     {:ex_doc, ">= 0.0.0", only: :dev},
     {:poison, "~> 2.2"}]
  end

  defp aliases do
    [test: ["test --cover", "credo"]]
  end
end
