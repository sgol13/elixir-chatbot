defmodule ElixirChatbotCore.DocumentationManager do
  require Logger
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment
  alias ElixirChatbotCore.DocumentationManager

  @spec documentation_fragments(keyword()) ::
          Enumerable.t(DocumentationFragment.t())
  @doc """
  Fetches the available documentation and optionally slices it.

  Keyword options:

  - `max_token_count: non_neg_integer()` - Approximate count of words after which the fragment will be split into multiple fragments
  - `headings_split: non_neg_integer()` - Depth of headings for which the documentation will be split, e.g. 1 means it will only be split on h1 headings, 2 means h1 and h2 and so on.
  - `prepend_parent_heading: boolean()` - Whether to prepend headings of parent sections to fragments when splitting by headings
  - `allowed_modules: Enumerable.t(atom())` - Modules outside of which documentation should not be fetched
  """
  def documentation_fragments(opts \\ []) do
    allowed_modules = Keyword.get(opts, :allowed_modules)

    loaded_modules()
    |> Stream.filter(fn module ->
      Enum.empty?(allowed_modules) || Enum.member?(allowed_modules, module) ||
        Enum.any?(allowed_modules, fn allowed_module ->
          String.starts_with?(
            Atom.to_string(module),
            "#{Atom.to_string(allowed_module)}."
          )
        end)
    end)
    |> Stream.flat_map(fn module ->
      doc_chunks(module, opts)
    end)
  end

  defp loaded_modules() do
    Application.loaded_applications()
    |> Stream.flat_map(fn {app, _, _} -> Application.spec(app, :modules) end)
  end

  defp doc_map_to_binary(doc) do
    case doc do
      :hidden -> :hidden
      :none -> :none
      %{"en" => doc} -> doc
      _ -> :none
    end
  end

  defp module_doc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", module_doc, _, _} ->
        {:ok, module_doc |> doc_map_to_binary()}

      {:docs_v1, _, _, _, _, _, _} ->
        {:ok, :none}

      {:error, :module_not_found} ->
        {:error, :module_not_found}

      {:error, :chunk_not_found} ->
        {:error, :module_not_found}
    end
  end

  defp function_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", _, _, docs} ->
        {:ok,
         docs
         # |> Stream.filter(fn {{type, _, _}, _, _, _, _} -> type == :function end)
         |> Stream.map(fn {_, _, sig, doc, _} -> {sig, doc |> doc_map_to_binary()} end)}

      {:docs_v1, _, _, _, _, _, _} ->
        {:ok, []}

      {:error, :module_not_found} ->
        {:error, :module_not_found}

      {:error, :chunk_not_found} ->
        {:error, :module_not_found}
    end
  end

  defp doc_chunks(module, opts) do
    with {:ok, module_doc} <- module_doc(module),
         {:ok, docs} <- function_docs(module) do
      docstream =
        docs
        |> Stream.filter(fn {_, doc} -> doc != :none && doc != :hidden end)
        |> Stream.flat_map(fn doc ->
          DocumentationManager.DocumentationFragment.function_to_fragment(
            module,
            doc,
            opts
          )
        end)

      if module_doc == :none || module_doc == :hidden do
        docstream
      else
        Stream.concat(
          DocumentationManager.DocumentationFragment.module_to_fragment(
            module,
            module_doc,
            opts
          ),
          docstream
        )
      end
    else
      {:error, e} ->
        Logger.error(
          "Error while reading documentation for module #{Atom.to_string(module)}: #{e}"
        )

        []
    end
  end
end
