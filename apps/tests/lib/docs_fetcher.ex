defmodule Tests.DocsFetcher do
  alias Tests.TestSupervisor
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.DocumentationManager
  require Logger

  def fetch_documentation(docs_db_name, max_word_count \\ nil, filter_modules \\ []) do
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = start_database(docs_db_name)

    fragments_counter =
    DocumentationManager.documentation_fragments(
      max_token_count: max_word_count
    )
    |> Stream.filter(fn fragment ->
      Enum.empty?(filter_modules) || Enum.member?(filter_modules, fragment.source_module) ||
        Enum.any?(filter_modules, fn module ->
          String.starts_with?(
            Atom.to_string(fragment.source_module),
            "#{Atom.to_string(module)}."
          )
        end)
    end)
    |> Stream.with_index(1)
    |> Stream.map(fn {e, i} ->
      DocumentationDatabase.add(e)

      if rem(i, 100) == 0 do
        Logger.info("Processed #{i} fragments...")
      end
      i
    end)
    |> Enum.max(fn -> 0 end)

    TestSupervisor.terminate_child(db_pid)

    Logger.info("Done.")
    {:ok, fragments_counter}
  end

  defp start_database(docs_db_name) do
    docs_db_name
    |> DocumentationDatabase.child_spec
    |> TestSupervisor.start_child
  end
end
