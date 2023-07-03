defmodule ChatWeb.IndexServer do
  require Logger
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
        ChatWeb.Application.default_embedding_model(),
        Application.fetch_env!(:chat_web, :hnsw_data_import_padding_chunk_size)
      )

    path = Application.fetch_env!(:chat_web, :hnsw_index_path)

    if File.exists?(path) do
      Logger.info("Loading the HNSW index from disk")
      {:ok, ElixirChatbotCore.SimilarityIndex.load_index(path, embedding)}
    else
      index = ElixirChatbotCore.SimilarityIndex.create_model(embedding)

      Logger.info("Populating the HNSW index")

      num_processed =
        ElixirChatbotCore.DocumentationDatabase.get_all()
        |> Stream.with_index(1)
        |> Stream.chunk_every(Application.fetch_env!(:chat_web, :hnsw_data_import_batch_size))
        |> Stream.map(fn entries ->
          entries_preprocessed =
            entries |> Stream.map(fn {{id, fragment}, _} -> {id, fragment.fragment_text} end)

          case ElixirChatbotCore.SimilarityIndex.add_many(index, entries_preprocessed) do
            {:error, err} -> Logger.warn(err)
            _ -> nil
          end

          i = entries |> Stream.map(fn {_, i} -> i end) |> Enum.max(fn -> 0 end)
          Logger.info("Processed #{i} fragments...")
          i
        end)
        |> Enum.max(fn -> 0 end)

      Logger.info("Done.")

      if num_processed > 0 do
        Logger.info("Saving populated index to disk...")

        ElixirChatbotCore.SimilarityIndex.save_index(index, path)
      end

      {:ok, index}
    end
  end

  @impl true
  def handle_cast({:add, id, text}, index) do
    :ok = ElixirChatbotCore.SimilarityIndex.add(index, id, text)
    {:noreply, index}
  end

  @impl true
  def handle_call({:lookup, text}, _from, index) do
    res = ElixirChatbotCore.SimilarityIndex.lookup(index, text, k: 1)
    {:reply, res, index}
  end
end
