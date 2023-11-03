defmodule ChatWeb.BotFacade do
  require Logger
  def send(message) do
    fragments = ChatWeb.ChatbotUtil.lookup_question(message)

    Logger.debug(fragments)
    fragments_text = fragments
    |> Enum.map(fn e -> e.fragment_text end)
    |> Enum.reduce(&<>/2)

    prompt = "Context:\n#{fragments_text}\n\nAnswer the following prompt regarding the Elixir programming language: #{message}"
    response = ElixirChatbotCore.GenerationModel.generate(prompt)
    {:ok, response, fragments}
  end
end
