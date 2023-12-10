defmodule Tests.EmbeddingTests do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase
  alias Tests.TestSupervisor
  require Logger

  @output_path "data/embedding_out/"

  def run() do
    # {model_name, question_prefix, passage_prefix}
    models = [
      {"sentence-transformers/paraphrase-MiniLM-L6-v2", nil, nil},
      {"sentence-transformers/all-MiniLM-L6-v2", nil, nil},
      {"BAAI/bge-large-en", "Represent this sentence for searching relevant passages: ", nil,
       nil},
      {"thenlper/gte-large", nil, nil},
      {"intfloat/multilingual-e5-large", "query: ", "passage: "}
    ]

    cases =
      for metric <- [:l2, :cosine],
          k <- [1, 3, 10, 50],
          {model, prepend_q, prepend_p} <- models do
        %EmbeddingTestsCase{
          embedding_model: model,
          similarity_metrics: metric,
          k: k,
          prepend_to_question: prepend_q,
          prepend_to_fragment: prepend_p,
          docs_db: "test"
        }
      end

    test_multiple_cases(cases)
  end

  def test_multiple_cases(test_cases) do
    test_cases
    |> Stream.map(fn test_case ->
      {test_case, run_test(test_case)}
    end)
    |> Stream.each(&save_json_file/1)
    |> Enum.count()
  end

  defp run_test(test_case) do
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = start_database(test_case)
    {:ok, index_pid} = start_index_server(test_case)

    accuracy =
      test_embedding_model(Map.get(test_case, :prepend_to_question), Map.get(test_case, :k))

    Logger.info("Test ended with success rate: #{Float.round(accuracy * 100, 2)}%")

    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)
    accuracy
  end

  defp test_embedding_model(prepend, k) do
    all = DocumentationDatabase.get_all()

    correct =
      all
      |> Stream.with_index(1)
      |> Stream.map(fn {{id, fragment}, i} ->
        if rem(i, 100) == 0 do
          Logger.info("Testing: #{i} cases done.")
        end

        check_index(create_question(fragment, prepend), k, id)
      end)
      |> Enum.count(fn result ->
        result == :ok
      end)

    correct / (all |> Enum.count())
  end

  defp check_index(question, k, id) do
    {:ok, res} = IndexServer.lookup(question, k)

    if res |> Nx.to_list() |> List.flatten() |> Enum.member?(id) do
      :ok
    else
      :mismatch
    end
  end

  defp create_question(fragment, prepend) do
    prompt =
      case fragment.type do
        :function -> "How does #{fragment.function_signature} work in Elixir?"
        :module -> "What is a #{fragment.source_module} in Elixir?"
        _ -> "What's that? #{fragment.source_module}"
      end

    if is_binary(prepend) do
      prepend <> prompt
    else
      prompt
    end
  end

  defp start_database(test_case) do
    test_case.docs_db
    |> DocumentationDatabase.child_spec()
    |> TestSupervisor.start_child()
  end

  defp start_index_server(test_case) do
    test_case
    |> EmbeddingTestsCase.to_index_params()
    |> IndexServer.child_spec(test_case.docs_db, test_case.prepend_to_fragment)
    |> TestSupervisor.start_child()
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
