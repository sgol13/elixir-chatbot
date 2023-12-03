defmodule ElixirChatbotCore.DocumentationManager do
  require Logger
  alias ElixirChatbotCore.DocumentationManager

  def documentation_fragments(opts \\ []) do
    max_token_count = Keyword.get(opts, :max_token_count)

    Stream.flat_map(loaded_modules(), fn module ->
      doc_chunks(module, max_token_count: max_token_count)
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
      {:docs_v1, _, _, "text/markdown", module_doc, _, _} -> {:ok, module_doc |> doc_map_to_binary()}
      {:docs_v1, _, _, _, _, _, _} -> {:ok, :none}
      {:error, :module_not_found} -> {:error, :module_not_found}
      {:error, :chunk_not_found} -> {:error, :module_not_found}
    end
  end

  defp function_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, "text/markdown", _, _, docs} ->
        {:ok,
         docs
         # |> Stream.filter(fn {{type, _, _}, _, _, _, _} -> type == :function end)
         |> Stream.map(fn {_, _, sig, doc, _} -> {sig, doc |> doc_map_to_binary()} end)}

      {:docs_v1, _, _, _, _, _, _} -> {:ok, []}

      {:error, :module_not_found} ->
        {:error, :module_not_found}

      {:error, :chunk_not_found} ->
        {:error, :module_not_found}
    end
  end

  defp doc_chunks(module, opts) do
    max_token_count = Keyword.get(opts, :max_token_count)

    with {:ok, module_doc} <- module_doc(module),
         {:ok, docs} <- function_docs(module) do
      docstream =
        docs
        |> Stream.filter(fn {_, doc} -> doc != :none && doc != :hidden end)
        |> Stream.flat_map(fn doc ->
          DocumentationManager.DocumentationFragment.function_to_fragment(
            module,
            doc,
            max_token_count
          )
        end)

      if module_doc == :none || module_doc == :hidden do
        docstream
      else
        Stream.concat(
          DocumentationManager.DocumentationFragment.module_to_fragment(
            module,
            module_doc,
            max_token_count
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
