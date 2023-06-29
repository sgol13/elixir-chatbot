defmodule ChatWeb.IndexServer do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end

  def add(id, text) do
    GenServer.cast(__MODULE__, {:add, id, text})
  end

  def lookup(text) do
    GenServer.call(__MODULE__, {:lookup, text}, 100_000)
  end

  @impl true
  def init(_) do
    embedding =
      ElixirChatbotCore.EmbeddingModel.SentenceTransformers.new(
        ChatWeb.Application.default_embedding_model()
      )

    index = ElixirChatbotCore.SimilarityIndex.create_model(embedding)

    {:ok, index}
  end

  @impl true
  def handle_cast({:add, id, text}, index) do
    :ok = ElixirChatbotCore.SimilarityIndex.add(index, id, text)
    {:noreply, index}
  end

  @impl true
  def handle_call({:lookup, text}, _from, index) do
    res = ElixirChatbotCore.SimilarityIndex.lookup(index, text, k: 2)
    {:reply, res, index}
  end
end
