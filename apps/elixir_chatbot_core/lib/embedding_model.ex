defmodule ElixirChatbotCore.EmbeddingModel do
  defprotocol EmbeddingModel do
    @spec compute(t, String.t()) :: {:ok, Nx.Tensor.t()} | :error
    def compute(model, text)

    @spec compute_many(t, [String.t()]) :: {:ok, Nx.Tensor.t()} | :error
    def compute_many(model, texts)

    @spec get_dimension(t) :: non_neg_integer()
    def get_dimension(model)
  end

  defmodule EmbeddingParameters do
    defstruct [
      :embedding_model,
      :similarity_metrics
    ]
  end
end
