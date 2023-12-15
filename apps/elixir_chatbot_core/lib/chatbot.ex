defmodule ElixirChatbotCore.Chatbot do
  alias ElixirChatbotCore.GenerationModel.GenerationModel
  require Logger
  use GenServer

  def start_link(model) do
    GenServer.start_link(__MODULE__, model, name: __MODULE__)
  end

  def child_spec(model) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [model]},
      type: :worker
    }
  end

  def init(model) do
    {:ok, model}
  end

  @spec generate(String.t()) ::
          {:ok, String.t(), [%ElixirChatbotCore.DocumentationManager.DocumentationFragment{}]}
          | {:error, String.t(), [String.t()]}
  def generate(message) do
    GenServer.call(__MODULE__, {:generate, message}, 300_000)
  end

  def handle_call({:generate, message}, _from, model) do
    fragments = lookup_question(message, 100)

    {:ok, response, selected_fragments} = GenerationModel.generate(model, message, fragments)
    IO.inspect(selected_fragments)
    {:reply, {:ok, response, selected_fragments}, model}
  end

  defp lookup_question(question_text, k) do
    {:ok, res} = ElixirChatbotCore.IndexServer.lookup(question_text, k)

    res
    |> Nx.to_flat_list()
    |> Enum.map(&ElixirChatbotCore.DocumentationDatabase.get/1)
  end
end
