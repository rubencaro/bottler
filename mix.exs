defmodule Bottler.Mixfile do
  use Mix.Project

  def project do
    [app: :bottler,
     version: "0.5.0",
     elixir: ">= 1.0.0",
     package: package,
     description: """
        Help you bottle, ship and serve your Elixir apps.
        Bottler is a collection of tools that aims to help you
        generate releases, ship them to your servers, install them there, and
        get them live on production.
      """,
     deps: deps]
  end

  def application do
    [ applications: [:logger, :crypto],
      included_applications: [:public_key, :asn1] ]
  end

  defp package do
    [maintainers: ["Rubén Caro"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/rubencaro/bottler"}]
  end

  defp deps do
    [{:sshex, "1.3.1"}]
  end
end
