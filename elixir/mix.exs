defmodule AppIdentity.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_identity,
      version: "1.3.0",
      description: "Fast, lightweight, cryptographically secure app authentication",
      elixir: "~> 1.10",
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
            title: "Apache Licence, version 2.0"
          ],
          "licences/dco.txt": [filename: "dco.txt", title: "Developer Certificate of Origin"]
        ]
      ],
      package: [
        licenses: ["Apache-2.0"],
        links: %{
          "Project" => "https://github.com/KineticCafe/app_identity",
          "Source" => "https://github.com/KineticCafe/app_identity/tree/main/elixir",
          "Issues" => "https://github.com/KineticCafe/app-identity/issues"
        }
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_apps: [:jason, :mix, :plug, :poison, :telemetry, :tesla]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  if Version.compare(System.version(), "1.11.0") == :lt do
    @versions %{
      poison: ">= 3.0.0 and < 6.0.0",
      ex_doc: "~> 0.27.0"
    }

    @extra [{:earmark_parser, "1.4.19"}]
  else
    @versions %{
      poison: ">= 3.0.0",
      ex_doc: "~> 0.29"
    }

    @extra []
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:plug, "~> 1.0", optional: true},
      {:poison, @versions.poison, optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true},
      {:tesla, "~> 1.0", optional: true},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, @versions.ex_doc, only: [:dev], runtime: false},
      {:secure_random, "~> 0.5", only: [:dev, :test]}
    ] ++ @extra
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
