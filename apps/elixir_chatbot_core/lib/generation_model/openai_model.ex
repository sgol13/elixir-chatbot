defmodule ElixirChatbotCore.GenerationModel.OpenAiModel do
  require Logger

  @openai_completions_url "https://api.openai.com/v1/chat/completions"
  @openai_model_id "gpt-3.5-turbo"

  def run do
    # generate("What is the capital of Poland?")
    str = "<|USER|>- Elixir.List.to_tuple(list) # Examples ## Examples     iex> List.to_tuple([:share, [:elixir, 163]])     {:share, [:elixir, 163]} \nIn the Elixir programming language, What is the difference between a list and a tuple in Elixir?<|ASSISTANT|>"
    generate(str)
  end

  def generate(prompt) do
    headers = build_headers()
    body = build_body(prompt)

    Logger.info("Open API completion...")
    IO.inspect(prompt)
    response = HTTPoison.post(@openai_completions_url, body, headers, recv_timeout: 300000)
    Logger.info("Open API completion finished")

    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, parse_response(response_body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("OpenAI API completion request error: #{reason}")
        :error
    end
  end

  defp build_headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{Application.fetch_env!(:chatbot, :openai_api_key)}"}
    ]
  end

  defp build_body(prompt) do
    %{
      "model" => @openai_model_id,
      "messages" => [
        %{
          "role" => "user",
          "content" => prompt
        }
      ]
    }
    |> Jason.encode!()
  end

  defp parse_response(response_body) do
    messages = Jason.decode!(response_body)["choices"]
    hd(messages)["message"]["content"]
  end
end
