defmodule AppIdentity.MixProject do
  use Mix.Project

  def project do
    [
      app: :app_identity,
      version: "1.3.2",
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

  defp deps do
    poison =
      if Version.compare(System.version(), "1.11.0") == :lt,
        do: ">= 3.0.0 and < 5.0.0",
        else: ">= 3.0.0"

    plug_crypto =
      if Version.compare(System.version(), "1.11.0") == :lt,
        do: "~> 1.2.5",
        else: ">= 1.2.0"

    tesla =
      if Version.compare(System.version(), "1.11.0") == :lt,
        do: ">= 1.0.0 and < 1.8.1",
        else: "~> 1.0"

    [
      {:jason, "~> 1.0", optional: true},
      {:plug, "~> 1.0", optional: true},
      {:poison, poison, optional: true},
      {:plug_crypto, plug_crypto, optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true},
      {:tesla, tesla, optional: true}
    ] ++ dev_deps()
  end

  defp dev_deps do
    if Version.compare(System.version(), "1.15.0") == :lt do
      []
    else
      [
        {:credo, "~> 1.0", only: [:dev], runtime: false},
        {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
        {:ex_doc, "~> 0.29", only: [:dev], runtime: false},
        {:quokka, "~> 2.0", only: [:dev], runtime: false}
      ]
    end
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
