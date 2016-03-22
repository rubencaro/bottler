defmodule Bottler.Mixfile do
  use Mix.Project

  def project do
    [app: :bottler,
     version: "0.5.0",
     elixir: ">= 1.0.0",
     package: package,
     description: "Help you bottle, ship and serve your Elixir apps.",
     deps: deps]
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
    [{:sshex, "~> 2.1"}]
  end
end
