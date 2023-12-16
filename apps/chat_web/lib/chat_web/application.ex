defmodule ChatWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @default_docs_db_name "test-elixir-plus-new"

  @default_embedding_model {:openai, "text-embedding-ada-002"}
  @default_similarity_metrics :cosine

  # @default_generation_model {:hf, "stabilityai/stablelm-tuned-alpha-3b"}

  @impl true
  def start(_type, _args) do
    # {generation_model, child_spec} =
    #   ElixirChatbotCore.GenerationModel.HuggingfaceModel.new(@default_generation_model)
    #   |> ElixirChatbotCore.GenerationModel.HuggingfaceModel.serve(GenerationModel)
    generation_model = ElixirChatbotCore.GenerationModel.OpenAiModel.new()

    embedding_params = %ElixirChatbotCore.EmbeddingModel.EmbeddingParameters{
      embedding_model: @default_embedding_model,
      similarity_metrics: @default_similarity_metrics
    }

    children = [
      # Start the Telemetry supervisor
      ChatWeb.Telemetry,
      ElixirChatbotCore.DocumentationDatabase.child_spec(@default_docs_db_name),
      ElixirChatbotCore.IndexServer.child_spec(embedding_params, @default_docs_db_name),
      # child_spec,
      {ElixirChatbotCore.Chatbot, generation_model},
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
end
