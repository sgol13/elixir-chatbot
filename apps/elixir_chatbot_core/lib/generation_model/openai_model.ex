defmodule ElixirChatbotCore.GenerationModel.OpenAiModel do
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.GenerationModel.GenerationModel
  alias ElixirChatbotCore.OpenAiClient
  require Logger

  @openai_model_id "gpt-3.5-turbo-1106"

  defstruct []

  def new do
    %__MODULE__{}
  end

  def generate(prompt) do
    body = build_body(prompt)

    Logger.info("OpenAI model request [#{Gpt3Tokenizer.token_count(prompt)} tokens]")

    case OpenAiClient.post_completions(body, recv_timeout: 180_000, retries: 3) do
      {:ok, response_body} ->
        response_content = parse_response(response_body)
        Logger.info("OpenAI model response [#{Gpt3Tokenizer.token_count(response_content)} tokens]")
        {:ok, response_content, []}

      :error ->
        :error
    end
  end

  defimpl GenerationModel, for: OpenAiModel do
    @impl true
    def generate(_model, question, _fragments, _metadata) do
      OpenAiModel.generate(question)
    end
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
  end

  defp parse_response(response_body) do
    messages = response_body["choices"]
    hd(messages)["message"]["content"]
  end
end
