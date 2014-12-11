defmodule Bottler.Mixfile do
  use Mix.Project

  def project do
    [app: :bottler,
     version: "0.1.0",
     elixir: "~> 1.0.0"]
  end

  def application do
    [ applications: [:logger] ]
  end
end
