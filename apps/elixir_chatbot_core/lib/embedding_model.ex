defmodule ElixirChatbotCore.EmbeddingModel do
  defprotocol EmbeddingModel do
    @spec generate_embedding(t, String.t()) :: {:ok, Nx.Tensor.t()} | {:error, String.t()}
    def generate_embedding(model, text)

    @spec get_embedding_dimension(t) :: non_neg_integer()
    def get_embedding_dimension(model)
  end
end
