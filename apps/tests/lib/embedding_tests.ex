defmodule Tests.EmbeddingTests do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase
  alias Tests.TestSupervisor
  require Logger

  @output_path "data/embedding_out/"

  def run(include_openai \\ false) do
    # {model_name, question_prefix, passage_prefix, num_tests}
    models = [
      {"intfloat/multilingual-e5-large", "query: ", "passage: ", 2000},
      {"intfloat/e5-large-v2", "query: ", "passage: ", 2000},
      {"sentence-transformers/paraphrase-MiniLM-L6-v2", nil, nil, 2000},
      {"sentence-transformers/all-MiniLM-L6-v2", nil, nil, 2000},
      {"BAAI/bge-large-en", "Represent this sentence for searching relevant passages: ", nil,
       2000},
      {"thenlper/gte-large", nil, nil, 2000}
    ]

    databases =
      ["test-v2-elixir-only", "test-v2-popular-packages"]
      |> Enum.flat_map(&[&1, "#{&1}-more-fragments", "#{&1}-naiive"])

    cases =
      for {model, prepend_q, prepend_p, num_tests} <- models, database <- databases do
        %EmbeddingTestsCase{
          embedding_model: {:hf, model},
          similarity_metrics: :cosine,
          k: 100,
          prepend_to_question: prepend_q,
          prepend_to_fragment: prepend_p,
          docs_db: database,
          num_tests: num_tests,
          chunk_size: 4
        }
      end

    openai_cases =
      for database <- databases do
        %EmbeddingTestsCase{
          embedding_model: {:openai, "text-embedding-ada-002"},
          similarity_metrics: :cosine,
          k: 100,
          docs_db: database,
          num_tests: 2000,
          chunk_size: 256
        }
      end

    cases =
      if include_openai do
        Enum.concat(openai_cases, cases)
      else
        cases
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

    histogram =
      test_embedding_model(
        Map.get(test_case, :prepend_to_question),
        Map.get(test_case, :k),
        Map.get(test_case, :num_tests),
        Map.get(test_case, :chunk_size)
      )

    [k1_accuracy | _] = histogram

    Logger.info("Test ended with success rate: #{Float.round(k1_accuracy * 100, 2)}%")

    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)
    histogram
  end

  defp test_embedding_model(prepend, k, num_cases, chunk_size) do
    all_ids =
      DocumentationDatabase.get_all()
      |> Stream.map(fn {id, _} -> id end)
      |> Enum.to_list()

    all_ids =
      if !is_nil(num_cases) && num_cases < length(all_ids) do
        Enum.take_random(all_ids, num_cases)
      else
        all_ids
      end

    all_ids_len = length(all_ids)

    histogram =
      all_ids
      |> Stream.with_index(1)
      |> Stream.chunk_every(chunk_size)
      |> Stream.map(&Enum.unzip/1)
      |> Stream.flat_map(fn {ids, is} ->
        questions =
          ids
          |> Enum.map(
            &(DocumentationDatabase.get(&1)
              |> create_question(prepend))
          )

        res = check_index(questions, k, ids)

        is
        |> Enum.max()
        |> ProgressBar.render(all_ids_len)

        res
      end)
      |> Enum.reduce(for(_ <- 1..k, do: 0), &construct_histogram/2)

    histogram |> Enum.map(fn hits -> hits / all_ids_len end)
  end

  defp construct_histogram(res, histogram) do
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
  end

  defp check_index(questions, k, ids) do
    {:ok, res} = IndexServer.lookup(questions, k)

    res
    |> Nx.to_list()
    |> Enum.zip(ids)
    |> Enum.map(fn {res_ids, id} ->
      index =
        List.flatten(res_ids)
        |> Enum.find_index(&(&1 == id))

      if is_nil(index) do
        :mismatch
      else
        {:ok, index}
      end
    end)
  end

  defp create_question(fragment, prepend) do
    prompt =
      case fragment.type do
        :function -> "How does #{fragment.function_signature} work?"
        kind when kind in [:module, :callback, :type] -> "What is #{fragment.source_module}?"
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

  defp start_index_server(
         %EmbeddingTestsCase{
           prepend_to_fragment: prepend_to_fragment,
           chunk_size: chunk_size,
           docs_db: docs_db
         } = test_case
       ) do
    test_case
    |> EmbeddingTestsCase.to_embedding_params()
    |> IndexServer.child_spec(docs_db,
      prepend_to_fragment: prepend_to_fragment,
      chunk_size: chunk_size
    )
    |> TestSupervisor.start_child()
  end

  defp save_json_file({test_case, histogram}) do
    content = %{
      params: test_case,
      histogram: histogram
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
