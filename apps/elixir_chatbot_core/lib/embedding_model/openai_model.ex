defmodule ElixirChatbotCore.EmbeddingModel.OpenAiModel do
  require Logger

  @openai_embedding_url "https://api.openai.com/v1/embeddings"
  @openai_model_id "text-embedding-ada-002"

  def run do
    compute_batch([
      "What is the capital of Poland?",
      "The capital of Poland is Warsaw.",
      "Warsaw is the largest city in Poland",
      "How to create a map in Elixir?"
    ])
  end

  def compute(text) do
    compute_batch([text])
  end

  def compute_batch(texts) do
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
    |> Stream.map(&Nx.tensor(&1))
    |> Stream.map(&Nx.reshape(&1, {1, elem(Nx.shape(&1), 0)})) # do we need to have [1][1536] shape instead of [1536] ???
    |> Enum.to_list
  end
end
