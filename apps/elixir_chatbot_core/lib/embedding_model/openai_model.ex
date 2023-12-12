defmodule ElixirChatbotCore.EmbeddingModel.OpenAiModel do
  alias ElixirChatbotCore.EmbeddingModel.OpenAiModel
  alias ElixirChatbotCore.OpenAiClient
  require Logger

  defstruct [:embedding_size]

  @openai_model_id "text-embedding-ada-002"
  @embedding_dimension 1536

  def new do
    %__MODULE__{embedding_size: @embedding_dimension}
  end

  def compute(text), do: compute_many([text])

  @spec compute_many(any()) :: :error | {:ok, any()}
  def compute_many(texts) do
    body = build_body(texts)

    case OpenAiClient.post_embeddings(body, recv_timeout: 8000, retries: 3) do
      {:ok, response_body} ->
        {:ok, parse_response(response_body)}

      :error ->
        :error
    end
  end

  defimpl ElixirChatbotCore.EmbeddingModel.EmbeddingModel, for: OpenAiModel do
    @impl true
    @spec compute(%OpenAiModel{}, String.t()) :: {:ok, Nx.Tensor.t()} | :error
    def compute(_model, text) do
      OpenAiModel.compute(text)
    end

    @impl true
    @spec compute_many(%OpenAiModel{}, [String.t()]) :: {:ok, Nx.Tensor.t()} | :error
    def compute_many(_model, texts) do
      OpenAiModel.compute_many(texts)
    end

    @impl true
    @spec get_dimension(%OpenAiModel{}) :: non_neg_integer()
    def get_dimension(%OpenAiModel{embedding_size: embedding_size}), do: embedding_size
  end

  defp build_body(texts) do
    %{
      "model" => @openai_model_id,
      "input" => texts
    }
  end

  defp parse_response(response_body) do
    response_body["data"]
    |> Stream.map(& &1["embedding"])
    |> Enum.to_list()
    |> Nx.tensor()
  end
end
