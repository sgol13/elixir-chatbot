defmodule Tests.DocsFetcher do
  alias Tests.TestSupervisor
  alias ElixirChatbotCore.DocumentationDatabase
  alias ElixirChatbotCore.DocumentationManager
  require Logger

  @spec fetch_documentation(String.t(), keyword()) :: {:ok, integer()}
  @doc """
  Fetches the available documentation and optionally slices it, then inserts into the specified database.

  Keyword options:

  - `max_token_count: non_neg_integer()` - Approximate count of words after which the fragment will be split into multiple fragments
  - `headings_split: non_neg_integer()` - Depth of headings for which the documentation will be split, e.g. 1 means it will only be split on h1 headings, 2 means h1 and h2 and so on.
  - `prepend_parent_heading: boolean()` - Whether to prepend headings of parent sections to fragments when splitting by headings
  - `allowed_modules: Enumerable.t(atom())` - Modules outside of which documentation should not be fetched
  """
  def fetch_documentation(docs_db_name, opts \\ []) do
    TestSupervisor.terminate_all_children()
    {:ok, db_pid} = start_database(docs_db_name)

    fragments_counter =
      DocumentationManager.documentation_fragments(opts)
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
    |> DocumentationDatabase.child_spec()
    |> TestSupervisor.start_child()
  end
end