# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :chat_web,
  ecto_repos: [ChatWeb.Repo],
  generators: [context_app: false]

# Configures the endpoint
config :chat_web, ChatWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ChatWeb.ErrorHTML, json: ChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ChatWeb.PubSub,
  live_view: [signing_salt: "voVcoDLX"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/chat_web/assets", __DIR__)
  ]

config :chat_web,
  generators: [context_app: false]

# Configures the endpoint
config :chat_web, ChatWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ChatWeb.ErrorHTML, json: ChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ChatWeb.PubSub,
  live_view: [signing_salt: "tg4S49sR"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/chat_web/assets", __DIR__)
  ]

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :nx, :default_backend, {EXLA.Backend, [client: :host]}
config :nx, :default_defn_options, compiler: EXLA, client: :host
config :exla, :clients,
  host: [platform: :host],
  cuda: [platform: :cuda],
  rocm: [platform: :rocm],
  tpu: [platform: :tpu]

config :chatbot,
  database_path: Path.expand("../../tmp/db"),
  hnsw_index_path: Path.expand("../../tmp/index"),
  hnsw_data_import_batch_size: 4,
  hnsw_data_import_padding_chunk_size: 64
