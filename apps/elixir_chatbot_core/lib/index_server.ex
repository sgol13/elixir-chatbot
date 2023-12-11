defmodule ElixirChatbotCore.IndexServer do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.SimilarityIndex
  alias ElixirChatbotCore.EmbeddingModel
  alias ElixirChatbotCore.EmbeddingModel.EmbeddingParameters

  require Logger
  use GenServer

  @spec start_link(String.t(), %EmbeddingParameters{}) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(path, embedding_params) do
    params = {path, embedding_params}
    GenServer.start_link(__MODULE__, params, name: __MODULE__)
  end

  def child_spec(embedding_params, docs_db_name) do
    {_, model_name} = embedding_params.embedding_model
    path = create_index_path(docs_db_name, model_name)

    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [path, embedding_params]},
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
  def init(
        {path,
         %EmbeddingParameters{
            embedding_model: model_config,
            similarity_metrics: similarity_metrics
         }}
      ) do

    embedding_model =
      case model_config do
        {:hf, model_name} ->
          chunk_size = Application.fetch_env!(:chatbot, :hnsw_data_import_padding_chunk_size)
          EmbeddingModel.HuggingfaceModel.new(model_name, chunk_size)

        {:openai, _model_name} ->
          EmbeddingModel.OpenAiModel.new()

        _ ->
          Logger.error("Unknown embedding model.")
      end

    Logger.info("Starting index at #{path}")

    if File.exists?(path) do
      Logger.info("Loading the HNSW index from disk")
      {:ok, SimilarityIndex.load_index(path, embedding_model, similarity_metrics)}
    else
      index = SimilarityIndex.create_model(embedding_model, similarity_metrics)

      Logger.info("Populating the HNSW index")

      num_processed =
        DocumentationDatabase.get_all()
        |> Stream.with_index(1)
        |> Stream.chunk_every(Application.fetch_env!(:chatbot, :hnsw_data_import_batch_size))
        |> Stream.map(fn entries ->
          entries_preprocessed =
            entries |> Stream.map(fn {{id, fragment}, _} -> {id, fragment.fragment_text} end)

          case SimilarityIndex.add_many(index, entries_preprocessed) do
            {:error, err} -> Logger.error(err)
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

        SimilarityIndex.save_index(index, path)
        Logger.info("Index saved")
      end

      {:ok, index}
    end
  end

  @impl true
  def handle_cast({:add, id, text}, index) do
    :ok = SimilarityIndex.add(index, id, text)
    {:noreply, index}
  end

  @impl true
  def handle_call({:lookup, text}, _from, index) do
    res = SimilarityIndex.lookup(index, text, k: 1)
    {:reply, res, index}
  end

  defp create_index_path(docs_db, model_name) do
    model_name = String.replace(model_name, "/", "-")
    "#{Application.fetch_env!(:chatbot, :hnsw_index_path)}-#{docs_db}_#{model_name}"
  end
end
