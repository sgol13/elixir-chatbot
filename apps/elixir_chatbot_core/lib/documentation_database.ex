defmodule ElixirChatbotCore.DocumentationDatabase do
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment

  use GenServer

  def start_link(path) do
    GenServer.start_link(__MODULE__, path, name: __MODULE__)
  end

  @impl true
  def init(path) do
    CubDB.start_link(path)
  end

  @impl true
  def handle_call({:add, documentation_fragment}, _from, db) do
    size = CubDB.size(db)
    CubDB.put(db, size, documentation_fragment)
    {:reply, size, db}
  end

  @impl true
  def handle_call({:get, id}, _from, db) do
    {:reply, CubDB.get(db, id), db}
  end

  @spec add(DocumentationFragment.DocumentationFragment.t()) :: non_neg_integer()
  def add(documentation_fragment) do
    GenServer.call(__MODULE__, {:add, documentation_fragment})
  end

  @spec get(non_neg_integer()) :: DocumentationFragment.DocumentationFragment.t()
  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end
end
