defmodule Tests.AnswersTests do
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.Chatbot
  alias ElixirChatbotCore.IndexServer
  alias Tests.TestSupervisor
  alias Tests.EmbeddingTestsCase
  alias Tests.TestUtils

  @questions_dir "data/answers_in/"
  @responses_dir "data/answers_out/"

  # Tests.AnswersTests.run
  def run do
    run("questions_3.txt", "test.html")
  end

  def run(questions_file, responses_file) do
    questions_path = @questions_dir <> questions_file
    responses_path = @responses_dir <> responses_file
    run_with_paths(questions_path, responses_path)
  end

  defp run_with_paths(questions_path, responses_path) do
    test_case = %EmbeddingTestsCase{
      embedding_model: {:openai, "intfloat/multilingual-e5-large"},
      similarity_metrics: :cosine,
      docs_db: "test-elixir-only"
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
    |> Stream.map(&build_html_output/1)
    |> Enum.join()
  end

  defp ask_question({question, index}) do
    IO.puts("#{index}: #{question}")
    {:ok, response, fragments, metadata} = Chatbot.generate(question)
    {index, question, response, fragments, metadata}
  end

  defp build_html_output({index, question, response, fragments, metadata}) do
    rendered_response = Earmark.as_html!(response)
    rendered_metadata = build_html_metadata(metadata)
    rendered_fragments = TestUtils.fragments_to_html(fragments)

    """
    <h3> #{index}: #{question} </h3>
    <div> #{rendered_response} </div>

    <details>
      <summary>Details</summary>
      <div> #{rendered_metadata} </div>
      <br/>
      <div> #{rendered_fragments} </div>
    </details>

    <hr/>
    """
  end

  defp build_html_metadata(metadata) do
    """
    <%= for {key, value} <- @metadata do %>
      <div><%= key %>: <%= value %></div>
    <% end %>
    """
    |> EEx.eval_string(assigns: [metadata: metadata])
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
end
