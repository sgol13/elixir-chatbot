defmodule ElixirChatbotCore.Chatbot do
  alias ChatWeb.Message
  alias ElixirChatbotCore.GenerationModel.GenerationModel
  alias ElixirChatbotCore.Message

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

  @spec generate([String.t()]) ::
          {:ok, String.t(), [%ElixirChatbotCore.DocumentationManager.DocumentationFragment{}]}
          | {:error, String.t(), [String.t()]}
  def generate(messages) when is_list(messages) do
    GenServer.call(__MODULE__, {:generate, messages}, 300_000)
  end

  @spec generate(String.t()) ::
          {:ok, String.t(), [%ElixirChatbotCore.DocumentationManager.DocumentationFragment{}]}
          | {:error, String.t(), [String.t()]}
  def generate(user_message_text) when is_binary(user_message_text) do
    user_message = Message.user_message(user_message_text)
    GenServer.call(__MODULE__, {:generate, [user_message], []}, 300_000)
  end

  def handle_call({:generate, messages}, _from, model) do
    [%{text: user_message_text, role: :user} | _past_messages] = messages
    fragments = lookup_question(user_message_text, 100)

    {:ok, response, selected_fragments, metadata} = GenerationModel.generate(model, messages, fragments)

    {:reply, {:ok, response, selected_fragments, metadata}, model}
  end

  defp lookup_question(question_text, k) do
    {:ok, res} = ElixirChatbotCore.IndexServer.lookup(question_text, k)

    res
    |> Nx.to_flat_list()
    |> Enum.map(&ElixirChatbotCore.DocumentationDatabase.get/1)
  end
end
