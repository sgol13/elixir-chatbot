defmodule Tests.EmbeddingTests do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase
  alias Tests.TestSupervisor
  require Logger

  @output_path "data/embedding_out/"
  @test_size 10

  def run() do
    [
      %EmbeddingTestsCase{
        embedding_model: {:openai, "text-embedding-ada-002"},
        similarity_metrics: :cosine,
        docs_db: "test2"
      }
    ]
    |> test_multiple_cases()
  end

  def test_multiple_cases(test_cases) do
    test_cases
    |> Stream.map(fn test_case ->
      {test_case, run_test(test_case)}
    end)
    |> Stream.each(&save_json_file/1)
    |> Enum.count
  end

  defp run_test(test_case) do
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = start_database(test_case)
    {:ok, index_pid} = start_index_server(test_case)

    Logger.info("Starting embedding test...")
    accuracy = test_embedding_model()
    Logger.info("Test ended with success rate: #{Float.round(accuracy * 100, 2)}%")

    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)
    accuracy
  end

  defp test_embedding_model() do
    all = DocumentationDatabase.get_all()
      |> Enum.to_list
      |> Enum.take_random(@test_size)
      |> Stream.with_index()

      correct = all
      |> Stream.map(fn {{id, fragment}, loop_id} ->
        ProgressBar.render(loop_id, @test_size)
      check_index(create_question(fragment), id)
    end) |> Enum.count(fn result ->
      result == :ok
    end)

    correct / (all |> Enum.count())
  end

  defp check_index(question, id) do
    {:ok, res} = IndexServer.lookup(question)
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

  defp start_database(test_case) do
    test_case.docs_db
    |> DocumentationDatabase.child_spec
    |> TestSupervisor.start_child
  end

  defp start_index_server(test_case) do
    test_case
    |> EmbeddingTestsCase.to_embedding_params
    |> IndexServer.child_spec(test_case.docs_db)
    |> TestSupervisor.start_child
  end

  defp save_json_file({test_case, accuracy}) do
    content = %{
      params: test_case,
      accuracy: accuracy
    }

    json_string = Jason.encode!(content)
    filename = "#{@output_path}/#{generate_output_name()}.json"
    File.write!(filename, json_string)
  end

  defp generate_output_name do
    DateTime.utc_now()
    |> Timex.format!("{YYYY}-{0M}-{0D}-{h24}{m}{s}")
  end
end
