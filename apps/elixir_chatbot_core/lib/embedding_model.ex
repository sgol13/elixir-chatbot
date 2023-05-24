defmodule ElixirChatbotCore.EmbeddingModel do
  defprotocol EmbeddingModel do
    @spec generate_embedding(t, String.t()) :: Nx.Tensor.t()
    def generate_embedding(model, text)
  end
end
