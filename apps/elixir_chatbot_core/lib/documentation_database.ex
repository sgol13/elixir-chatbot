defmodule ElixirChatbotCore.DocumentationDatabase do
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment

  use GenServer

  def start_link(path) do
    GenServer.start_link(__MODULE__, path, name: __MODULE__)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [Application.fetch_env!(:chat_web, :database_path)]},
      type: :worker
    }
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

  @impl true
  def handle_call(:get_all, _from, db) do
    {:reply, CubDB.select(db), db}
  end

  @spec add(DocumentationFragment.DocumentationFragment.t()) :: non_neg_integer()
  def add(documentation_fragment) do
    GenServer.call(__MODULE__, {:add, documentation_fragment})
  end

  @spec get(non_neg_integer()) :: DocumentationFragment.DocumentationFragment.t()
  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end
end
