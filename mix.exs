defmodule Heimdall.Mixfile do
  use Mix.Project

  def project do
    [
      app: :heimdall,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package()
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      applications: [:logger, :rackla, :cowboy, :httpoison],
      mod: {Heimdall.Application, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:rackla, "~> 1.2"},
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.0"},
      {:httpoison, "~> 0.9.0"},
      {:mock, "~> 0.1.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      description: "API gateway for Marathon/Mesos",
      maintainers: ["Cameron Alexander"],
      licenses: ["MIT"],
      links: %{"GitHub" => "http://github.com/emptyflash/heimdall"}
    ]
  end
end
