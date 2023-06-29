defmodule ElixirChatbotCore.DocumentationManager do
  @spec loaded_modules :: Stream.t(atom())
  def loaded_modules do
    Application.loaded_applications |> Stream.flat_map(fn {app, _, _} -> Application.spec(app, :modules) end)
  end

  defp doc_map_to_binary(doc) do
    case doc do
      :hidden -> :hidden
      :none -> :none
      %{"en" => doc} -> doc
      #%{nil => doc} -> doc # warns it can never match %{binary => binary}, even if I annotate explicitly...
      _ -> :none
    end
  end

  @spec module_doc(atom) :: {:ok, binary | :hidden | :none} | {:error, :module_not_found}
  def module_doc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, module_doc, _, _} -> {:ok, module_doc |> doc_map_to_binary}
      {:error, :module_not_found} -> {:error, :module_not_found}
      {:error, :chunk_not_found} -> {:error, :module_not_found}
    end
  end

  @spec function_docs(atom) :: {:ok, Stream.t({signature, binary | :hidden | :none})} | {:error, :module_not_found}
    when signature: [binary]
  def function_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, docs} ->
        {:ok, Stream.map(docs, fn {_, _, sig, doc, _} -> {sig, doc |> doc_map_to_binary} end)}
      {:error, :module_not_found} -> {:error, :module_not_found}
      {:error, :chunk_not_found} -> {:error, :module_not_found}
    end
  end

  defp module_to_string(module, doc) do
    # TODO: Module name as markdown heading + docstring if present, handle :none. :hidden should error
  end

  defp function_to_string(module, {sig, doc}) do
    # TODO: Module name + signature + docstring if present, handle :none. :hidden should error
  end

  @spec doc_chunks(atom) :: Stream.t(binary) | {:error, :module_not_found}
  def doc_chunks(module) do
    with {:ok, module_doc} <- module_doc(module) do
      with {:ok, docs} <- function_docs(module) do
        docstream = Stream.map(docs, fn doc -> function_to_string(module, doc) end)
        Stream.concat([module_to_string(module, module_doc)], docstream)
      end
    else
      {:error, e} -> {:error, e}
    end
  end
end
