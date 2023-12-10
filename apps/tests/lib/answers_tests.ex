# The script reads questions from txt files in the ./questions directory
# and saves bot's responses to html files in the ./responses directory.
# To run the script:
#   ies -S mix
#   c("manual_tests/bot_manual_tests.ex")
#
#   Tests.AnswersTests.run() - run the script using default files questions_1.txt and responses_1.html
#
#   Tests.AnswersTests.run("questions_2.txt", "responses_2.html") - run the script using custom files

defmodule Tests.AnswersTests do
  alias Tests.TestSupervisor
  alias ElixirChatbotCore.Chatbot

  @questions_dir "data/answers_in/"
  @responses_dir "data/answers_out/"

  def run do
    run("questions_1.txt", "responses_1.html")
  end

  def run(questions_file, responses_file) do
    questions_path = @questions_dir <> questions_file
    responses_path = @responses_dir <> responses_file
    run_with_paths(questions_path, responses_path)
  end

  defp run_with_paths(questions_path, responses_path) do
    TestSupervisor.terminate_all_children()
    {:ok, gen_model_pid} = start_generation_model()

    output = File.stream!(questions_path)
      |> execute_tests

    File.write!(responses_path, output)

    TestSupervisor.terminate_child(gen_model_pid)
    :ok
  end

  defp execute_tests(questions) do
    questions
    |> Stream.map(&String.trim/1)
    |> Stream.with_index(1)
    |> Stream.map(&ask_question/1)
    |> Stream.map(&build_html_result/1)
    |> Enum.reduce("", fn string, acc -> acc <> string end)
  end

  defp ask_question({question, index}) do
    IO.puts("#{index}: #{question}")
    {:ok, response, _fragments} = Chatbot.generate(question)
    {index, question, response}
  end

  defp build_html_result({index, question, response}) do
    rendered_response = Earmark.as_html!(response)
    """
    <h3> #{index}: #{question} </h3>
    <p> #{rendered_response} </p>
    <hr/>
    """
  end

  defp start_generation_model do
    {:ok, nil}
  end
end