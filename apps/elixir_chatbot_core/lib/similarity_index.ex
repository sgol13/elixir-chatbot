defmodule ElixirChatbotCore.SimilarityIndex do
  require Logger
  alias ElixirChatbotCore.SimilarityIndex
  alias ElixirChatbotCore.EmbeddingModel
  defstruct [:index, :embedding_model]

  @type t :: %__MODULE__{
          index: %HNSWLib.Index{},
          embedding_model: EmbeddingModel.EmbeddingModel.t()
        }

  @max_elements 20_000

  @spec save_index(
          __MODULE__.t(),
          binary
        ) :: {:error, binary} | {:ok, integer}
  def save_index(%SimilarityIndex{index: index}, path) do
    HNSWLib.Index.save_index(index, path)
  end

  @spec load_index(String.t(), EmbeddingModel.EmbeddingModel.t(), :cosine | :ip | :l2) ::
          __MODULE__.t()
  def load_index(path, embedding_model, similarity_metrics) do
    {:ok, index} =
      HNSWLib.Index.load_index(
        similarity_metrics,
        EmbeddingModel.EmbeddingModel.get_dimension(embedding_model),
        path,
        max_elements: @max_elements
      )

    %SimilarityIndex{index: index, embedding_model: embedding_model}
  end

  @spec create_model(EmbeddingModel.EmbeddingModel.t(), :cosine | :ip | :l2) ::
          __MODULE__.t()
  def create_model(embedding_model, similarity_metrics) do
    {:ok, index} =
      HNSWLib.Index.new(
        similarity_metrics,
        EmbeddingModel.EmbeddingModel.get_dimension(embedding_model),
        @max_elements
      )

    %SimilarityIndex{index: index, embedding_model: embedding_model}
  end

  @spec add(
          __MODULE__.t(),
          non_neg_integer(),
          binary
        ) :: :ok | {:error, String.t()}
  def add(index, id, text) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index

    {:ok, embedding} = EmbeddingModel.EmbeddingModel.compute(embedding_model, text)

    HNSWLib.Index.add_items(index, Nx.stack([embedding]), ids: Nx.tensor([id]))
  end

  @spec add_many(
          __MODULE__.t(),
          Enumerable.t({non_neg_integer(), String.t()})
        ) :: :ok | {:error, String.t()}
  def add_many(index, entries) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index

    {ids, texts} = Enum.unzip(entries)

    {:ok, embeddings} = EmbeddingModel.EmbeddingModel.compute_many(embedding_model, texts)

    ids = Nx.tensor(ids)
    res = HNSWLib.Index.add_items(index, embeddings, ids: ids)

    Nx.backend_deallocate({ids, embeddings})

    res
  end

  @spec lookup(
          __MODULE__.t(),
          String.t() | [String.t()],
          non_neg_integer()
        ) :: {:ok, Nx.Tensor.t()} | {:error, String.t()}
  def lookup(index, text, k) do
    %SimilarityIndex{index: index, embedding_model: embedding_model} = index

    {:ok, embedding} = if is_list(text) do
      EmbeddingModel.EmbeddingModel.compute_many(embedding_model, text)
    else
      EmbeddingModel.EmbeddingModel.compute(embedding_model, text)
    end

    {:ok, labels, _dists} = HNSWLib.Index.knn_query(index, embedding, k: k)
    {:ok, labels}
  end
end
