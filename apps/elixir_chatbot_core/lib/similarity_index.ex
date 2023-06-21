defmodule ElixirChatbotCore.SimilarityIndex do
  alias ElixirChatbotCore.SimilarityIndex
  alias ElixirChatbotCore.EmbeddingModel
  defstruct [:index, :embedding_model]

  @max_elements 100_000

  @spec create_model(EmbeddingModel.EmbeddingModel.t()) :: %ElixirChatbotCore.SimilarityIndex{
          embedding_model: EmbeddingModel.EmbeddingModel.t(),
          index: %HNSWLib.Index{dim: non_neg_integer, reference: any, space: :cosine | :ip | :l2}
        }
  def create_model(embedding_model) do
    {:ok, index} =
      HNSWLib.Index.new(
        :l2,
        EmbeddingModel.EmbeddingModel.get_embedding_dimension(embedding_model),
        @max_elements
      )

    %SimilarityIndex{index: index, embedding_model: embedding_model}
  end

  @spec add(
          %ElixirChatbotCore.SimilarityIndex{
            :embedding_model => EmbeddingModel.EmbeddingModel.t(),
            :index => %HNSWLib.Index{dim: any, reference: any, space: any}
          },
          non_neg_integer(),
          binary
        ) :: :ok
  def add(index, id, text) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index
    embedding = EmbeddingModel.EmbeddingModel.generate_embedding(embedding_model, text)
    :ok = HNSWLib.Index.add_items(index, Nx.stack([embedding]), ids: Nx.tensor([id]))
    :ok
  end

  @spec lookup(
          %ElixirChatbotCore.SimilarityIndex{
            :embedding_model => EmbeddingModel.EmbeddingModel.t(),
            :index => %HNSWLib.Index{dim: any, reference: any, space: any}
          },
          binary,
          keyword
        ) :: Nx.Tensor.t()
  def lookup(index, text, opts \\ []) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index
    k = Keyword.get(opts, :k, 3)
    embedding = EmbeddingModel.EmbeddingModel.generate_embedding(embedding_model, text)
    {:ok, labels, _dists} = HNSWLib.Index.knn_query(index, embedding, k: k)
    labels
  end
end
