defmodule Tests.AnswersTests do
  require Logger
  alias ElixirChatbotCore.GenerationModel.OpenAiModel
  alias ElixirChatbotCore.Chatbot
  alias Tests.TestSupervisor
  alias Tests.EmbeddingTestsCase
  alias Tests.TestUtils

  @questions_path "data/answers_in/"
  @output_path "data/answers_out/"

  # Tests.AnswersTests.run
  def run do
    run("questions_4.txt")
  end

  def run(questions_file) do
    questions_path = @questions_path <> questions_file
    test_case = %EmbeddingTestsCase{
      embedding_model: {:openai, "ada-002"},
      similarity_metrics: :cosine,
      docs_db: "test-v3-new"
    }

    TestSupervisor.terminate_all_children()
    {:ok, gen_model_pid} = TestSupervisor.start_chatbot(OpenAiModel.new())
    {:ok, db_pid} = TestSupervisor.start_database(test_case)
    {:ok, index_pid} = TestSupervisor.start_index_server(test_case)

    output =
      File.stream!(questions_path)
      |> execute_tests

    filename = TestUtils.generate_output_path(@output_path, "html")
    File.write!(filename, output)

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
    Logger.info("Testing question #{index}: #{question}")
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
    sorted_metadata = Enum.sort_by(metadata, fn {key, _value} -> key end)

    """
    <%= for {key, value} <- @metadata do %>
      <div><%= key %>: <%= value %></div>
    <% end %>
    """
    |> EEx.eval_string(assigns: [metadata: sorted_metadata])
  end
end
