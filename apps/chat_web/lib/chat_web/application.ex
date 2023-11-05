defmodule ChatWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_embedding_model "paraphrase-MiniLM-L6-v2"
  @default_generation_model {:hf, "gpt2-xl"}

  @impl true
  def start(_type, _args) do
    {model, generation_model_spec} =
      ElixirChatbotCore.GenerationModel.HuggingfaceModel.new(@default_generation_model,
        generation_opts: [stream: true]
      )
      |> ElixirChatbotCore.GenerationModel.HuggingfaceModel.serve(MyGenerationModel)

    children = [
      # Start the Telemetry supervisor
      ChatWeb.Telemetry,
      ElixirChatbotCore.DocumentationDatabase.child_spec(nil),
      ChatWeb.IndexServer.child_spec(nil),
      generation_model_spec,
      {ChatWeb.BotFacade, model},
      # Start the PubSub system
      # This needs to be removed when we add PubSub to another Umbrella app
      {Phoenix.PubSub, name: ChatWeb.PubSub},

      # Start the Endpoint (http/https)
      ChatWeb.Endpoint
      # Start a worker by calling: ChatWeb.Worker.start_link(arg)
      # {ChatWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChatWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def default_embedding_model(), do: @default_embedding_model
end
