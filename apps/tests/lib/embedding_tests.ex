defmodule Tests.EmbeddingTests do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase
  alias Tests.TestSupervisor
  alias Tests.TestUtils
  require Logger

  @output_path "data/embedding_out/"

  def run(num_cases \\ nil, include_openai \\ false) do
    # {model_name, question_prefix, passage_prefix}
    models = [
      {"sentence-transformers/paraphrase-MiniLM-L6-v2", nil, nil},
      {"sentence-transformers/all-MiniLM-L6-v2", nil, nil},
      {"BAAI/bge-large-en", "Represent this sentence for searching relevant passages: ", nil,
       nil},
      {"thenlper/gte-large", nil, nil},
      {"intfloat/multilingual-e5-large", "query: ", "passage: "},
      {"intfloat/e5-large-v2", "query: ", "passage: "}
    ]

    databases = ["mateon-test"]; #["test-elixir-only", "test-popular-packages"]

    cases =
      for {model, prepend_q, prepend_p} <- models, database <- databases do
        %EmbeddingTestsCase{
          embedding_model: {:hf, model},
          similarity_metrics: :cosine,
          k: 1000,
          prepend_to_question: prepend_q,
          prepend_to_fragment: prepend_p,
          docs_db: database
        }
      end

    openai_cases =
      for database <- databases do
        %EmbeddingTestsCase{
          embedding_model: {:openai, "text-embedding-ada-002"},
          similarity_metrics: :cosine,
          k: 1000,
          docs_db: database
        }
      end

    cases = if include_openai do
      Enum.concat(openai_cases, cases)
    else
      cases
    end

    test_multiple_cases(cases, num_cases)
  end

  def test_multiple_cases(test_cases, num_cases) do
    test_cases
    |> Stream.map(fn test_case ->
      {test_case, run_test(test_case, num_cases)}
    end)
    |> Stream.each(&save_json_file/1)
    |> Enum.count()
  end

  defp run_test(test_case, num_cases) do
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = TestSupervisor.start_database(test_case)
    {:ok, index_pid} = TestSupervisor.start_index_server(test_case)

    histogram =
      test_embedding_model(
        Map.get(test_case, :prepend_to_question),
        Map.get(test_case, :k),
        num_cases
      )

    [k1_accuracy | _] = histogram

    Logger.info("Test ended with success rate: #{Float.round(k1_accuracy * 100, 2)}%")

    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)
    histogram
  end

  defp test_embedding_model(prepend, k, num_cases) do
    all_ids =
      DocumentationDatabase.get_all()
      |> Stream.map(fn {id, _} -> id end)

    all_ids =
      if !is_nil(num_cases) do
        Enum.take_random(all_ids, num_cases)
      else
        Enum.to_list(all_ids)
      end

    all_ids_len = length(all_ids)

    histogram =
      all_ids
      |> Stream.with_index(1)
      |> Stream.map(fn {id, i} ->
        ProgressBar.render(i, all_ids_len)

        DocumentationDatabase.get(id)
        |> create_question(prepend)
        |> check_index(k, id)
      end)
      |> Enum.reduce(for(_ <- 1..k, do: 0), fn res, histogram ->
        case res do
          {:ok, i} ->
            histogram
            |> Enum.with_index()
            |> Enum.map(fn {hist_hits, hist_i} ->
              if hist_i < i do
                hist_hits
              else
                hist_hits + 1
              end
            end)

          _ ->
            histogram
        end
      end)

    histogram |> Enum.map(fn hits -> hits / all_ids_len end)
  end

  defp check_index(question, k, id) do
    {:ok, res} = IndexServer.lookup(question, k)

    index = res |> Nx.to_list() |> List.flatten() |> Enum.find_index(&(&1 == id))

    if is_nil(index) do
      :mismatch
    else
      {:ok, index}
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

  defp save_json_file({test_case, histogram}) do
    content = %{
      params: test_case,
      histogram: histogram
    }

    json_string = Jason.encode!(content, pretty: true)
    filename = TestUtils.generate_output_path(@output_path, "json")
    File.write!(filename, json_string)
  end
end
