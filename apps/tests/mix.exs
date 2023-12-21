defmodule Tests.MixProject do
  use Mix.Project

  def project do
    [
      app: :tests,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Tests.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:nx, "~> 0.6.1"},
      {:jason, "~> 1.2"},
      {:timex, "~> 3.7"},
      {:elixir_chatbot_core, in_umbrella: true},
      {:progress_bar, "~> 3.0"}
      # {:flame, "> 0.0.0"},
      # {:gettext, "> 0.0.0"},
      # {:tzdata, "> 0.0.0"},
      # {:plug, "> 0.0.0"},
      # {:phoenix, "> 0.0.0"},
      # {:decimal, "> 0.0.0"},
      # {:mime, "> 0.0.0"},
      # {:db_connection, "> 0.0.0"},
      # {:plug_crypto, "> 0.0.0"},
      # {:plug_cowboy, "> 0.0.0"},
      # {:httpoison, "> 0.0.0"},
      # {:ecto, "> 0.0.0"},
      # {:postgrex, "> 0.0.0"},
      # {:poison, "> 0.0.0"},
      # {:phoenix_pubsub, "> 0.0.0"},
      # {:connection, "> 0.0.0"},
      # {:combine, "> 0.0.0"},
      # {:ecto_sql, "> 0.0.0"},
      # {:excoveralls, "> 0.0.0"},
      # {:nimble_parsec, "> 0.0.0"},
      # {:ex_doc, "> 0.0.0"},
      # {:recon, "> 0.0.0"},
      # {:makeup, "> 0.0.0"},
      # {:junit_formatter, "> 0.0.0"},
      # {:makeup_elixir, "> 0.0.0"},
      # {:poolboy, "> 0.0.0"},
      # {:elixir_xml_to_map, "> 0.0.0"},
      # {:optimal, "> 0.0.0"},
      # {:xml_builder, "> 0.0.0"},
      # {:msgpax, "> 0.0.0"},
      # {:statix, "> 0.0.0"},
      # {:dialyxir, "> 0.0.0", runtime: false},
      # {:ex_machina, "> 0.0.0"},
      # {:earmark, "> 0.0.0"},
      # {:prometheus_ex, "> 0.0.0"},
      # {:spandex, "> 0.0.0"},
      # {:ink, "> 0.0.0"},
      # {:table_rex, "> 0.0.0"},
      # {:faker, "> 0.0.0"},
      # {:sentry, "> 0.0.0"},
      # {:erlex, "> 0.0.0"},
      # {:elixir_make, "> 0.0.0"},
      # {:number, "> 0.0.0"},
      # {:ordinal, "> 0.0.0"},
      # {:credo, "> 0.0.0"},
      # {:phoenix_html, "> 0.0.0"},
      # {:prometheus_phoenix, "> 0.0.0"},
      # {:bunt, "> 0.0.0"},
      # {:phoenix_ecto, "> 0.0.0"},
      # {:ibrowse, "> 0.0.0"},
      # {:prometheus_plugs, "> 0.0.0"},
      # {:file_system, "> 0.0.0"},
      # {:sweet_xml, "> 0.0.0"},
      # {:prometheus_ecto, "> 0.0.0"},
      # {:tesla, "> 0.0.0"},
      # {:cowlib, "> 0.0.0"},
      # {:uuid, "> 0.0.0"},
      # {:comeonin, "> 0.0.0"},
      # {:temp, "> 0.0.0"},
      # {:csv, "> 0.0.0"},
      # {:gen_stage, "> 0.0.0"},
      # {:ex_aws_s3, "> 0.0.0"},
      # {:exconstructor, "> 0.0.0"},
      # {:exexec, "> 0.0.0"},
      # {:bcrypt_elixir, "> 0.0.0"},
      # {:gen_retry, "> 0.0.0"},
      # {:gen_state_machine, "> 0.0.0"},
      # {:crc32cer, "> 0.0.0"},
      # {:parallel_stream, "> 0.0.0"},
      # {:iptools, "> 0.0.0"},
      # {:castore, "> 0.0.0"},
      # {:html_entities, "> 0.0.0"},
      # {:joken, "> 0.0.0"},
      # {:remote_ip, "> 0.0.0"},
      # {:floki, "> 0.0.0"}
    ]
  end
end
