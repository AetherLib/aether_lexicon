defmodule AetherLexicon.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/AetherLib/aether_lexicon"

  def project do
    [
      app: :aether_lexicon,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Aether Lexicon",
      description: "ATProto Lexicons in Elixir",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "AetherLexicon",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      "README.md",
      "docs/OFFICIAL_LEXICON_COMPARISON.md",
      "LICENSE.md": [title: "License"]
    ]
  end

  defp groups_for_extras do
    [
      Documentation: ~r/docs\//
    ]
  end

  defp groups_for_modules do
    [
      Validation: [
        AetherLexicon.Validation,
        AetherLexicon.Validation.Formats,
        AetherLexicon.Validation.Validators
      ]
    ]
  end

  defp package do
    [
      maintainers: [
        "Josh Chernoff <hello@fullstack.ing>"
      ],
      name: "aether_lexicon",
      homepage_url: "https://aetherlib.org",
      licenses: ["Apache-2.0"],
      links: %{
        "Hex Package" => "https://hex.pm/packages/aether_lexicon",
        "GitHub" => "https://github.com/AetherLib/aether_lexicon",
        "Gitea" => "https://gitea.fullstack.ing/Aether/aether_lexicon",
        "ATProto Specification" => "https://atproto.com/specs/lexicon"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md)
    ]
  end
end
