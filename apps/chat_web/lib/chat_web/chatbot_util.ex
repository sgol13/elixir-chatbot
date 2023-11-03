defmodule ChatWeb.ChatbotUtil do
  alias ChatWeb.IndexServer
  require Logger

  def fetch_documentation(max_word_count \\ nil, filter_modules \\ []) do
    ElixirChatbotCore.DocumentationManager.documentation_fragments(
      max_token_count: max_word_count
    )
    |> Stream.filter(fn fragment ->
      Enum.empty?(filter_modules) || Enum.member?(filter_modules, fragment.source_module) ||
        Enum.any?(filter_modules, fn module ->
          String.starts_with?(
            Atom.to_string(fragment.source_module),
            "#{Atom.to_string(module)}."
          )
        end)
    end)
    |> Stream.with_index(1)
    |> Enum.each(fn {e, i} ->
      ElixirChatbotCore.DocumentationDatabase.add(e)

      if rem(i, 100) == 0 do
        Logger.info("Processed #{i} fragments...")
      end
    end)

    Logger.info("Done.")
    :ok
  end

  def lookup_question(question_text) do
    {:ok, res} = IndexServer.lookup(question_text)

    res
    |> Nx.to_flat_list()
    |> Enum.map(&ElixirChatbotCore.DocumentationDatabase.get/1)
  end
end
