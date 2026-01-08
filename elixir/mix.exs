defmodule AppIdentity.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_identity,
      version: "1.4.0",
      description: "Fast, lightweight, cryptographically secure app authentication",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "AppIdentity for Elixir",
      source_url: "https://github.com/KineticCafe/app_identity",
      docs: [
        main: "readme",
        formatters: ["html"],
        extras: [
          "README.md",
          "Contributing.md",
          "Changelog.md": [filename: "Changelog.md", title: "Changelog"],
          "spec.md": [filename: "spec", title: "App Identity Specification"],
          "Licence.md": [filename: "Licence.md", title: "Licence"],
          "licences/APACHE-2.0.txt": [
            filename: "APACHE-2.0.txt",
            title: "Apache License, version 2.0"
          ],
          "licences/dco.txt": [filename: "dco.txt", title: "Developer Certificate of Origin"]
        ]
      ],
      package: [
        files: ~w(lib .formatter.exs mix.exs *.md),
        licenses: ["Apache-2.0"],
        links: %{
          "Project" => "https://github.com/KineticCafe/app_identity",
          "Source" => "https://github.com/KineticCafe/app_identity/tree/main/elixir",
          "Issues" => "https://github.com/KineticCafe/app-identity/issues"
        }
      ],
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:jason, :mix, :plug, :poison, :telemetry, :tesla]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  def cli do
    [
      preferred_cli_envs: [
        coveralls: :test,
        "coveralls.github": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:plug, "~> 1.0", optional: true},
      {:poison, "~> 6.0", optional: true},
      {:plug_crypto, "~> 1.0", optional: true},
      {:telemetry, "~> 1.0", optional: true},
      {:tesla, "~> 1.0", optional: true},
      {:castore, "~> 1.0", only: [:test]},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:quokka, "~> 2.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test) do
    ~w(lib support test/support)
  end

  defp elixirc_paths(:dev) do
    ~w(lib support)
  end

  defp elixirc_paths(_) do
    ~w(lib)
  end
end
