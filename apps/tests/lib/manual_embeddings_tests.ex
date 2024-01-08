defmodule Tests.ManualEmbeddingTests do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase
  alias Tests.TestSupervisor
  alias Tests.TestUtils
  require Logger

  @output_path "data/manual_embedding_out/"

  @testcases [
    # {Question, Expected Fragment Text (string or regex)}
    # {:module, Timex.Format.DateTime.Formatters.Default, nil}
    {"What time options does the default Timex DateTime formatter support?", "### Time\n\n* `{h24}`     - hour of the day (00..23)\n* `{h12}`     - hour of the day (1..12)\n* `{m}`       - minutes of the hour (00..59)"},
    {"How do I format a 24h time with seconds using Timex?", "### Time\n\n* `{h24}`     - hour of the day (00..23)\n* `{h12}`     - hour of the day (1..12)\n* `{m}`       - minutes of the hour (00..59)"},
    # {:function, ExUnit.DocTest, "doctest_file(file, opts \\\\ [])"}
    {"What code is responsible for generating tests from Markdown files?", "Elixir.ExUnit.DocTest.doctest_file(file, opts \\\\ [])"},
    {"How can I generate doctests from a Markdown file?", "Elixir.ExUnit.DocTest.doctest_file(file, opts \\\\ [])"},
    {"Can you automatically test code written in Markdown documentation?", "Elixir.ExUnit.DocTest.doctest_file(file, opts \\\\ [])"},
    # {:function, Tokenizers.Encoding, "token_to_chars(encoding, token)"}
    {"What does the token_to_chars function in Elixir's Tokenizers.Encoding module return?", "Elixir.Tokenizers.Encoding.token_to_chars(encoding, token)"},
    {"Can you provide an example of using the token_to_chars function from the Tokenizers.Encoding module in Elixir?", "Elixir.Tokenizers.Encoding.token_to_chars(encoding, token)"},
    # {:function, Enum, "sort_by(enumerable, mapper, sorter \\\\ :asc)"}
    {"What does the sorter option represent in the Enum.sort_by function, and how can I use it to sort in descending order?", "## Ascending and descending (since v1.10.0)\n\n`sort_by/3` allows a developer to pass `:asc` or `:desc` as the sorter,"},
    {"How do I sort a list in Elixir in reverse order?", "## Ascending and descending (since v1.10.0)\n\n`sort_by/3` allows a developer to pass `:asc` or `:desc` as the sorter,"},
    # {:function, Nx, "window_scatter_min(tensor, source, init_value, window_dimensions, opts \\\\ [])"}
    {"How does the `window_scatter_min` function in the Nx module determine the minimum index in each window of the input tensor?", "Elixir.Nx.window_scatter_min(tensor, source, init_value, window_dimensions, opts \\\\ [])\n\nPerforms a `window_reduce` to select the minimum index"},
  ]

  @spec run(any()) :: non_neg_integer()
  def run(include_openai \\ false) do
    # {model_name, question_prefix, passage_prefix}
    models = [
      {"sentence-transformers/paraphrase-MiniLM-L6-v2", nil, nil},
      {"sentence-transformers/all-MiniLM-L6-v2", nil, nil},
      {"BAAI/bge-large-en", "Represent this sentence for searching relevant passages: ", nil, nil},
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
          k: 10, #5000,
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
          k: 5000,
          docs_db: database
        }
      end

    cases = if include_openai do
      Enum.concat(openai_cases, cases)
    else
      cases
    end

    test_multiple_cases(cases)
  end

  @spec test_multiple_cases(any()) :: non_neg_integer()
  def test_multiple_cases(test_cases) do
    test_cases
    |> Stream.map(fn test_case ->
      {test_case, run_test(test_case)}
    end)
    |> Stream.each(&save_json_file/1)
    |> Enum.count()
  end

  @spec run_test(%EmbeddingTestsCase{}) :: %{histogram: [...], indexes: list()}
  def run_test(test_case) do
    IO.inspect(%{testcase: test_case})
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = TestSupervisor.start_database(test_case)
    {:ok, index_pid} = TestSupervisor.start_index_server(test_case)
    IO.inspect(%{db: db_pid, index: index_pid})

    # sleep to ensure separate timestamps for saved files
    :timer.sleep(2000)

    dump_db(test_case)

    {histogram, indexes} =
      test_embedding_model(
        Map.get(test_case, :prepend_to_question),
        Map.get(test_case, :k)
      )

    [k1_accuracy | _] = histogram

    Logger.info("Test ended with success rate: #{Float.round(k1_accuracy * 100, 2)}%")

    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)

    %{histogram: histogram, indexes: indexes}
  end

  def test_embedding_model(prepend, k) do
    num_testcases = length @testcases
    res = @testcases
    |> Stream.with_index(1)
    |> Stream.map(fn {testcase, i} ->
      ProgressBar.render(i, num_testcases)

      check_index(prepend, testcase, k)
    end) |> Enum.to_list

    histogram =
      res |> Enum.reduce(for(_ <- 1..k, do: 0), fn res, histogram ->
        case res do
          {:ok, i, _, _} ->
            histogram
            |> Enum.with_index()
            |> Enum.map(fn {hist_hits, hist_i} ->
              if hist_i < i do
                hist_hits
              else
                hist_hits + 1
              end
            end)

          {:mismatch, _, _} ->
            histogram
        end
      end)

    histogram = histogram |> Enum.map(fn hits -> hits / num_testcases end)
    indexes = res |> Enum.map(fn item ->
      case item do
        {:ok, idx, res, question} -> %{question: question, correct: idx, results: res}
        {:mismatch, res, question} -> %{question: question, correct: nil, results: res}
      end
    end)

    {histogram, indexes}
  end

  def matches(haystack, needle) when is_struct(needle, Regex) do
    Regex.match?(needle, haystack)
  end

  def matches(haystack, needle) when is_binary(needle) do
    String.contains?(haystack, needle)
  end

  @spec check_index(nil | binary(), {binary(), binary() | Regex.t()}, non_neg_integer()) ::
          {:mismatch, list(), binary()} | {:ok, nil | non_neg_integer(), list(), binary()}
  def check_index(prepend, testcase, k) do
    {question, match} = testcase
    {:ok, res} = IndexServer.lookup((prepend || "") <> question, k)

    #IO.inspect(testcase)
    res = res |> Nx.to_list() |> List.flatten()
    #IO.inspect(res)

    index = res |> Enum.find_index(fn id -> DocumentationDatabase.get(id).fragment_text |> matches(match) end)

    #IO.inspect(index)

    if is_nil(index) do
      {:mismatch, res, question}
    else
      {:ok, index, res, question}
    end
  end

  @spec dump_db(%EmbeddingTestsCase{}) :: :ok
  def dump_db(testcase) do
    db_data = DocumentationDatabase.get_all() |> Stream.map(fn {id, item} -> [id, Map.from_struct(item)] end) |> Enum.to_list
    json = %{ docs_db: testcase.docs_db, db_data: db_data } |> Jason.encode!
    File.write!(TestUtils.generate_output_path(@output_path, "db.json"), json)
  end

  @spec save_json_file({any(), map()}) :: :ok
  def save_json_file({test_case, content}) do

    content = Map.put(content, :params, test_case)

    json_string = Jason.encode!(content, pretty: true)
    filename = TestUtils.generate_output_path(@output_path, "json")
    File.write!(filename, json_string)
  end
end
