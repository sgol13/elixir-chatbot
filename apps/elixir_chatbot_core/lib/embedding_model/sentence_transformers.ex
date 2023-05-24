defmodule ElixirChatbotCore.EmbeddingModel.SentenceTransformers do
  alias ElixirChatbotCore.EmbeddingModel.SentenceTransformers
  defstruct [:model_name]

  @spec start_semantics_server :: :ignore | {:error, any} | {:ok, pid}
  def start_semantics_server() do
    Semantics.start_link()
  end

  @spec start_semantics_server(String.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_semantics_server(model_name) do
    Semantics.start_link(model_name)
  end

  @spec load_model(String.t()) :: any
  def load_model(model_name) do
    Semantics.load(model_name)
  end

  @spec new(String.t()) :: %ElixirChatbotCore.EmbeddingModel.SentenceTransformers{model_name: String.t()}
  def new(model_name) do
    %SentenceTransformers{model_name: model_name}
  end

  @spec generate_embedding(
          %ElixirChatbotCore.EmbeddingModel.SentenceTransformers{
            :model_name => String.t()
          },
          String.t()
        ) :: Nx.Tensor.t()
  def generate_embedding(model, text) do
    %SentenceTransformers{model_name: model_name} = model
    embedding = Semantics.embedding(text, model_name)
    Nx.tensor(embedding)
  end

  defimpl ElixirChatbotCore.EmbeddingModel.EmbeddingModel, for: SentenceTransformers do
    @impl true
    @spec generate_embedding(%ElixirChatbotCore.EmbeddingModel.SentenceTransformers{}, binary) ::
            Nx.Tensor.t()
    def generate_embedding(model, text) do
      SentenceTransformers.generate_embedding(model, text)
    end
  end
end
