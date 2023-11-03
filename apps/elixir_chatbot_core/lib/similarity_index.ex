defmodule ElixirChatbotCore.SimilarityIndex do
  require Logger
  alias ElixirChatbotCore.SimilarityIndex
  alias ElixirChatbotCore.EmbeddingModel
  defstruct [:index, :embedding_model]

  @max_elements 10_000

  @spec save_index(
          %ElixirChatbotCore.SimilarityIndex{
            :index => %HNSWLib.Index{dim: any, reference: any, space: any}
          },
          binary
        ) :: {:error, binary} | {:ok, integer}
  def save_index(%SimilarityIndex{index: index}, path) do
    HNSWLib.Index.save_index(index, path)
  end

  @spec load_index(String.t(), EmbeddingModel.EmbeddingModel.t()) ::
          %ElixirChatbotCore.SimilarityIndex{
            embedding_model: EmbeddingModel.EmbeddingModel.t(),
            index: %HNSWLib.Index{
              dim: non_neg_integer,
              reference: any,
              space: :cosine | :ip | :l2
            }
          }
  def load_index(path, embedding_model) do
    {:ok, index} =
      HNSWLib.Index.load_index(
        :l2,
        EmbeddingModel.EmbeddingModel.get_embedding_dimension(embedding_model),
        path,
        max_elements: @max_elements
      )

    %SimilarityIndex{index: index, embedding_model: embedding_model}
  end

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
        ) :: :ok | {:error, String.t()}
  def add(index, id, text) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index

    embedding = EmbeddingModel.EmbeddingModel.generate_embedding(embedding_model, text)
    HNSWLib.Index.add_items(index, Nx.stack([embedding]), ids: Nx.tensor([id]))
  end

  @spec add_many(
          %ElixirChatbotCore.SimilarityIndex{
            :embedding_model => any,
            :index => %HNSWLib.Index{dim: any, reference: any, space: any}
          },
          Enumerable.t({non_neg_integer(), String.t()})
        ) :: :ok | {:error, String.t()}
  def add_many(index, entries) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index

    {ids, texts} = Enum.unzip(entries)

    embeddings = EmbeddingModel.EmbeddingModel.generate_many(embedding_model, texts)

    ids = Nx.tensor(ids)

    res = HNSWLib.Index.add_items(index, embeddings, ids: ids)

    Nx.backend_deallocate({ids, embeddings})

    res
  end

  @spec lookup(
          %ElixirChatbotCore.SimilarityIndex{
            :embedding_model => EmbeddingModel.EmbeddingModel.t(),
            :index => %HNSWLib.Index{dim: any, reference: any, space: any}
          },
          String.t(),
          keyword()
        ) :: {:ok, Nx.Tensor.t()} | {:error, String.t()}
  def lookup(index, text, opts \\ []) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index
    k = Keyword.get(opts, :k, 3)

    embedding = EmbeddingModel.EmbeddingModel.generate_embedding(embedding_model, text)

    {:ok, labels, _dists} = HNSWLib.Index.knn_query(index, embedding, k: k)
    {:ok, labels}
  end
end
