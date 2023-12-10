defmodule ElixirChatbotCore.GenerationModel.OpenAiModel do
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.GenerationModel.GenerationModel
  require Logger

  @openai_completions_url "https://api.openai.com/v1/chat/completions"
  @openai_model_id "gpt-3.5-turbo"

  defstruct []

  def new do
    %__MODULE__{}
  end

  def generate(prompt) do
    headers = build_headers()
    body = build_body(prompt)

    Logger.info("Open API completion...")
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

  defimpl GenerationModel, for: OpenAiModel do
    @impl true
    def generate(_model, prompt, _metadata) do
      OpenAiModel.generate(prompt)
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
