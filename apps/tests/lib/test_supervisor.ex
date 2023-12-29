defmodule Tests.TestSupervisor do
  alias ElixirChatbotCore.Chatbot
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.Chatbot
  alias ElixirChatbotCore.IndexServer
  alias Tests.EmbeddingTestsCase

  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_chatbot(model) do
    Chatbot.child_spec(model)
    |> start_child()
  end

  def start_index_server(test_case) do
    test_case
    |> EmbeddingTestsCase.to_embedding_params()
    |> IndexServer.child_spec(test_case.docs_db)
    |> start_child()
  end

  def start_database(test_case) do
    test_case.docs_db
    |> DocumentationDatabase.child_spec()
    |> start_child()
  end

  defp start_child(spec) do
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_child(child_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, child_pid)
  end

  def terminate_all_children() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.each(fn {_, pid, _, _} -> terminate_child(pid) end)
  end
end
