defmodule EmbeddingTests.TestGenerator do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.SimilarityIndex
  require Logger

  def test_embedding_model(similarity_index) do
    all = DocumentationDatabase.get_all()

    correct = all |> Stream.map(fn {id, fragment} ->
      check_index(create_question(fragment), id, similarity_index)
    end) |> Enum.count(fn result ->
      result == :ok
    end)

    Logger.info("Test ended with success rate: #{Float.round(correct/(all |> Enum.count())*100, 2)}%")
  end

  defp check_index(question, id, similarity_index) do
    {:ok, res} = SimilarityIndex.lookup(similarity_index, question, k: 3)
    if res |> Nx.to_list() |> List.flatten() |> Enum.member?(id) do
      :ok
    else
      :mismatch
    end
  end

  defp create_question(fragment) do
    case fragment.type do
      :function -> "How does #{fragment.function_signature} work in Elixir?"
      :module -> "What is a #{fragment.source_module} in Elixir?"
      _ -> "What's that? #{fragment.source_module}"
    end
  end
end
