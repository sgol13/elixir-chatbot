defmodule ChatWeb.ChatbotUtil do
  alias ChatWeb.IndexServer
  require Logger

  def fetch_documentation(max_word_count \\ nil) do
    ElixirChatbotCore.DocumentationManager.documentation_fragments(
      max_token_count: max_word_count
    )
    |> Stream.with_index(1)
    |> Enum.each(fn {e, i} ->
      id = ElixirChatbotCore.DocumentationDatabase.add(e)

      if rem(i, 100) == 0 do
        Logger.info("Processed #{i} fragments...")
      end
    end)

    Logger.info("Done.")
    :ok
  end

  def lookup_question(question_text) do
    IndexServer.lookup(question_text)
    |> Nx.to_flat_list()
    |> Enum.map(&ElixirChatbotCore.DocumentationDatabase.get/1)
  end
end
