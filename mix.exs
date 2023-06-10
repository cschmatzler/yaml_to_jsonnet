defmodule YamlToJsonnet.MixProject do
  use Mix.Project

  def project do
    [
      app: :yaml_to_jsonnet,
      author: "Christoph Schmatzler <christoph@medium.place>",
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"}
    ]
  end
end
