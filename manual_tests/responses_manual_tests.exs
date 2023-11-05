# To run the script:
#   ies -S mix
#   c("manual_tests/responses_manual_tests.exs")

questions_file = "manual_tests/questions.txt"
responses_file = "manual_tests/bot_responses_results.html"

output = File.stream!(questions_file)
  |> Stream.map(&String.trim/1)
  |> Stream.with_index(1)
  |> Stream.map(fn {question, index}  ->
    IO.puts("#{index}: #{question}")
    {:ok, response, _fragments} = ChatWeb.BotFacade.generate(question)
    {index, question, response}
  end
  )
  |> Stream.map(fn {index, question, response} ->
    rendered_response = Earmark.as_html!(response)
    """
    <h3> #{index}: #{question} </h3>
    <p> #{rendered_response} </p>
    <hr/>
    """
  end)
  |> Enum.reduce("", fn string, acc -> acc <> string end)

File.write!(responses_file, output)
