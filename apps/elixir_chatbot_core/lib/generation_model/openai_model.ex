defmodule ElixirChatbotCore.GenerationModel.OpenAiModel do
  alias ElixirChatbotCore.Message
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
               "of a documentation chunk and its source (documentation of a module or a specific function). " <>
               "Use markdown format in your responses. Provide practical examples."

  defstruct []

  def new do
    %__MODULE__{}
  end

  def generate(messages, fragments) do
    messages_tokens = count_messages_tokens(messages)
    guideline_tokens = count_tokens(@guideline)
    max_docs_tokens = @input_context - guideline_tokens - messages_tokens

    {selected_fragments, docs_tokens} =
      GenerationModel.select_fragments(fragments, &count_tokens/1, max_docs_tokens,
        fragment_overhead: 10
      )

    body = build_body(selected_fragments, messages)

    total_input_tokens = guideline_tokens + messages_tokens + docs_tokens
    Logger.info("OpenAI model request [#{total_input_tokens} tokens]")

    case OpenAiClient.post_completions(body, recv_timeout: 180_000, retries: 6) do
      {:ok, response_body} ->
        {response_content, usage_stats} = parse_response(response_body)
        Logger.info("OpenAI model response [#{count_tokens(response_content)} tokens]")

        metadata =
          build_metadata(
            selected_fragments,
            response_content,
            docs_tokens,
            guideline_tokens,
            messages_tokens,
            total_input_tokens,
            usage_stats
          )

        {:ok, response_content, selected_fragments, metadata}

      :error ->
        :error
    end
  end

  defimpl GenerationModel.GenerationModel, for: OpenAiModel do
    @impl true
    def generate(_model, messages, fragments, _metadata) do
      OpenAiModel.generate(messages, fragments)
    end
  end

  defp build_body(fragments, chat_messages) do
    messages =
      [
        build_guideline_message(),
        build_docs_message(fragments)
      ] ++
        build_chat_messages(chat_messages)

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
    |> Enum.map(fn fragment ->
      %{
        text: DocumentationFragment.get_docs_fragment(fragment),
        source: "#{fragment.source_module}.#{fragment.function_signature}"
      }
    end)
    |> Enum.to_list()
    |> Jason.encode!()
    |> build_message(:system)
  end

  defp build_chat_messages(messages) do
    messages
    |> Enum.map(fn %{text: text, role: role} ->
      case role do
        :user -> build_message(text, :user)
        :bot -> build_message(text, :system)
      end
    end)
    |> Enum.reverse()
  end

  defp parse_response(response_body) do
    messages = response_body["choices"]
    response_content = hd(messages)["message"]["content"]

    usage = response_body["usage"]
    {response_content, usage}
  end

  defp build_metadata(
         selected_fragments,
         response_content,
         docs_tokens,
         guideline_tokens,
         messages_tokens,
         total_input_tokens,
         usage_stats
       ) do
    response_tokens = count_tokens(response_content)

    %{
      fragments: length(selected_fragments),
      docs_tk: docs_tokens,
      guideline_tk: guideline_tokens,
      messages_tk: messages_tokens,
      total_input_tk: total_input_tokens,
      answer_tk: response_tokens,
      total_tk: total_input_tokens + response_tokens,
      openai_completion_tk: usage_stats["completion_tokens"],
      openai_prompt_tk: usage_stats["prompt_tokens"],
      openai_total_tk: usage_stats["total_tokens"]
    }
  end

  defp count_messages_tokens(messages) do
    messages
    |> Enum.map(fn %Message{text: text} -> count_tokens(text) end)
    |> Enum.sum()
  end

  defp count_tokens(%DocumentationFragment{} = fragment) do
    DocumentationFragment.get_docs_fragment(fragment)
    |> count_tokens()
  end

  defp count_tokens(text), do: Gpt3Tokenizer.token_count(text)
end
