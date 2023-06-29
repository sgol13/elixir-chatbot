defmodule ChatWeb.LoadEmbeddingsTask do
  require Logger
  alias ChatWeb.IndexServer
  use Task

  def start_link(_) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    ElixirChatbotCore.DocumentationDatabase.get_all()
    |> Stream.with_index(1)
    |> Enum.each(fn {{id, fragment}, i} ->
      :ok = IndexServer.add(id, fragment.fragment_text)

      if rem(i, 100) == 0 do
        Logger.info("Processed #{i} fragments...")
      end
    end)

    Logger.info("Done.")
    :ok
  end
end
