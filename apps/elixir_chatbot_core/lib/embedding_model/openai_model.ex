defmodule ElixirChatbotCore.EmbeddingModel.OpenAiModel do
  alias ElixirChatbotCore.EmbeddingModel.OpenAiModel
  require Logger

  defstruct [:embedding_size]

  @openai_embedding_url "https://api.openai.com/v1/embeddings"
  @openai_model_id "text-embedding-ada-002"
  @embedding_dimension 1536

  def new do
    %__MODULE__{embedding_size: @embedding_dimension}
  end

  def compute(text) do
    compute_many([text])
  end

  def compute_many(texts) do
    headers = build_headers()
    body = build_body(texts)
    response = HTTPoison.post(@openai_embedding_url, body, headers)

    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, parse_response(response_body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenAI API embedding request error: #{reason}")
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
    def get_dimension(%OpenAiModel{embedding_size: embedding_size}) do
      embedding_size
    end
  end

  defp build_headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{Application.fetch_env!(:chatbot, :openai_api_key)}"}
    ]
  end

  defp build_body(texts) do
    %{
      "model" => @openai_model_id,
      "input" => texts
    }
    |> Jason.encode!()
  end

  defp parse_response(response_body) do
    Jason.decode!(response_body)["data"]
    |> Stream.map(&(&1["embedding"]))
    |> Enum.to_list
    |> Nx.tensor
  end
end
