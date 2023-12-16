defmodule Tests.AnswersTests do
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.Chatbot
  alias ElixirChatbotCore.IndexServer
  alias Tests.TestSupervisor
  alias Tests.EmbeddingTestsCase

  @questions_dir "data/answers_in/"
  @responses_dir "data/answers_out/"

  # Tests.AnswersTests.run
  def run do
    run("questions_2.txt", "responses_2.html")
  end

  def run(questions_file, responses_file) do
    questions_path = @questions_dir <> questions_file
    responses_path = @responses_dir <> responses_file
    run_with_paths(questions_path, responses_path)
  end

  defp run_with_paths(questions_path, responses_path) do
    test_case = %EmbeddingTestsCase{
      embedding_model: {:openai, "text-embedding-ada-002"},
      similarity_metrics: :cosine,
      docs_db: "test-elixir-plus-new"
    }

    TestSupervisor.terminate_all_children()
    {:ok, gen_model_pid} = start_chatbot(OpenAiModel.new())
    {:ok, db_pid} = start_database(test_case)
    {:ok, index_pid} = start_index_server(test_case)

    output =
      File.stream!(questions_path)
      |> execute_tests

    File.write!(responses_path, output)

    TestSupervisor.terminate_child(gen_model_pid)
    TestSupervisor.terminate_child(db_pid)
    TestSupervisor.terminate_child(index_pid)
    :ok
  end

  defp execute_tests(questions) do
    questions
    |> Stream.map(&String.trim/1)
    |> Stream.with_index(1)
    |> Stream.map(&ask_question/1)
    |> Stream.map(&build_html_result/1)
    |> concatenate_texts
  end

  defp ask_question({question, index}) do
    IO.puts("#{index}: #{question}")
    {:ok, response, fragments} = Chatbot.generate(question)
    {index, question, fragments, response}
  end

  defp build_html_result({index, question, fragments, response}) do
    rendered_response = Earmark.as_html!(response)

    rendered_fragments =
      fragments
      |> Stream.map(fn %DocumentationFragment{fragment_text: text, source_module: source} ->
        """
          <b> #{source} </b>
          <div style="background-color: #f0f0f0"> #{Earmark.as_html!(text)} </div>
        """
      end)
    |> concatenate_texts

    """
    <h3> #{index}: #{question} </h3>
    <div> #{rendered_response} </div>
    <details>
      <summary>Documentation</summary>
      <div> #{rendered_fragments} </div>
    </details>
    <hr/>
    """
  end

  defp start_chatbot(model) do
    ElixirChatbotCore.Chatbot.child_spec(model)
    |> TestSupervisor.start_child()
  end

  defp start_index_server(test_case) do
    test_case
    |> EmbeddingTestsCase.to_embedding_params()
    |> IndexServer.child_spec(test_case.docs_db)
    |> TestSupervisor.start_child()
  end

  defp start_database(test_case) do
    test_case.docs_db
    |> DocumentationDatabase.child_spec()
    |> TestSupervisor.start_child()
  end

  defp concatenate_texts(texts) do
    texts
    |> Enum.reduce("", fn string, acc -> acc <> string end)
  end
end
