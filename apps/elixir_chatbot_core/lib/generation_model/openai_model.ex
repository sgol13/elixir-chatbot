defmodule ElixirChatbotCore.GenerationModel.OpenAiModel do
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.GenerationModel
  alias ElixirChatbotCore.OpenAiClient
  require Logger

  # context size: 16_385
  @openai_model_id "gpt-3.5-turbo-1106"
  @input_context 8192

  @guideline "You're a helpful assistant answering questions regarding Elixir programming language documentation. " <>
               "You have access to a subset of Elixir modules' documentation in a JSON format. Each element of the list consists " <>
               "of a documentation chunk and the name of the module that it refers to. Provide answers in a markdown format."

  defstruct []

  def new do
    %__MODULE__{}
  end

  def generate(question, fragments) do
    question_tokens = count_tokens(question)
    guideline_tokens = count_tokens(@guideline)
    max_docs_tokens = @input_context - guideline_tokens - question_tokens

    {selected_fragments, docs_tokens} =
      GenerationModel.select_fragments(fragments, &count_tokens/1, max_docs_tokens,
        fragment_overhead: 10
      )

    body = build_body(selected_fragments, question)

    total_tokens = guideline_tokens + question_tokens + docs_tokens
    Logger.info("OpenAI model request [#{total_tokens} tokens]")

    case OpenAiClient.post_completions(body, recv_timeout: 180_000, retries: 10) do
      {:ok, response_body} ->
        response_content = parse_response(response_body)
        Logger.info("OpenAI model response [#{count_tokens(response_content)} tokens]")

        {:ok, response_content, selected_fragments}

      :error ->
        :error
    end
  end

  defimpl GenerationModel.GenerationModel, for: OpenAiModel do
    @impl true
    def generate(_model, question, fragments, _metadata) do
      OpenAiModel.generate(question, fragments)
    end
  end

  defp build_body(fragments, question) do
    messages = [
      build_guideline_message(),
      build_docs_message(fragments),
      build_question_message(question)
    ]

    %{
      model: @openai_model_id,
      messages: messages
    }
  end

  defp build_message(content, role) when role in [:user, :system] do
    %{
      role: role,
      content: content
    }
  end

  defp build_guideline_message do
    build_message(@guideline, :system)
  end

  defp build_docs_message(fragments) do
    fragments
    |> Enum.map(fn %DocumentationFragment{fragment_text: text, source_module: module} ->
      %{text: text, module: module}
    end)
    |> Enum.to_list()
    |> Jason.encode!()
    |> build_message(:system)
  end

  defp build_question_message(question) do
    build_message(question, :user)
  end

  defp parse_response(response_body) do
    messages = response_body["choices"]
    hd(messages)["message"]["content"]
  end

  defp count_tokens(%DocumentationFragment{fragment_text: fragment_text}) do
    count_tokens(fragment_text)
  end

  defp count_tokens(text), do: Gpt3Tokenizer.token_count(text)
end
