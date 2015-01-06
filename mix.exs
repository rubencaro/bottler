defmodule Bottler.Mixfile do
  use Mix.Project

  def project do
    [app: :bottler,
     version: "0.2.0",
     elixir: "~> 1.0.0"]
  end

  def application do
    [ applications: [:logger, :crypto],
      included_applications: [:ssh, :public_key, :asn1] ]
  end
end
