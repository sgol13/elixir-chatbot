defmodule ChatWeb.BotFacade do
  require Logger
  use GenServer

  def start_link(model) do
    GenServer.start_link(__MODULE__, model, name: __MODULE__)
  end

  @impl true
  def init(model) do
    {:ok, model}
  end

  @spec generate(String.t()) ::
          {:ok, String.t(), [%ElixirChatbotCore.DocumentationManager.DocumentationFragment{}]}
          | {:error, String.t()}
  def generate(message) do
    fragments = ChatWeb.ChatbotUtil.lookup_question(message)

    fragments_text =
      fragments
      |> Enum.map(fn e -> "- #{e.fragment_text}" end)
      |> Enum.map(&String.replace(&1, ~r/\n+/u, " "))
      |> Enum.join("\n")

    question = String.replace(message, ~r/\?+$/, "")

    prompt =
      "<|USER|>#{fragments_text}\nIn the Elixir programming language, #{question}?<|ASSISTANT|>"

    model = GenServer.call(__MODULE__, :get_model)
    response = ElixirChatbotCore.GenerationModel.GenerationModel.generate(model, prompt, %{})

    {:ok, response, fragments}
  end

  @impl true
  def handle_call(:get_model, _from, model) do
    {:reply, model, model}
  end
end
