defmodule Mlx90640.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_mlx90640,
      version: "0.1.9",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers,
      aliases: aliases(),
      package: package(),
      source_url: "https://github.com/lucaong/elixir_mlx90640",
      deps: deps(),
      docs: [
        main: "Mlx90640",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [clean: ["clean", "clean.make"]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "An Elixir library to interface with the MLX90640 Far Infrared Thermal Sensor Array",
      files: ["lib", "LICENSE", "mix.exs", "README.md", "src/*.cpp", "src/*.h", "src/linux/i2c-dev.h", "Makefile"],
      maintainers: ["Luca Ongaro"],
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end
end
