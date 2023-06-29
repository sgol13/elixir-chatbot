defmodule ElixirChatbotCore.DocumentationManager.DocumentationFragment do
  require Logger
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment
  defstruct [:type, :fragment_text, :source_module, :function_signature]

  @spec module_to_fragment(atom, String.t(), nil | non_neg_integer()) ::
          [
            %ElixirChatbotCore.DocumentationManager.DocumentationFragment{
              fragment_text: String.t(),
              function_signature: nil,
              source_module: atom,
              type: :module
            }
          ]
  def module_to_fragment(module, doc, nil) do
    case doc do
      :none ->
        []

      :hidden ->
        []

      _ ->
        [
          %DocumentationFragment{
            type: :module,
            fragment_text: "#{Atom.to_string(module)}\n\n#{doc}",
            source_module: module,
            function_signature: nil
          }
        ]
    end
  end

  def module_to_fragment(module, doc, max_word_count) do
    header = Atom.to_string(module)

    string_to_chunks(max_word_count - 1, doc)
    |> Enum.map(fn str ->
      %DocumentationFragment{
        type: :module,
        fragment_text: "#{header}\n\n#{str}",
        source_module: module,
        function_signature: nil
      }
    end)
  end

  @spec function_to_fragment(atom, {any, String.t()}, nil | non_neg_integer()) ::
          [
            %ElixirChatbotCore.DocumentationManager.DocumentationFragment{
              fragment_text: String.t(),
              function_signature: any,
              source_module: atom,
              type: :function
            }
          ]
  def function_to_fragment(module, {sig, doc}, nil) do
    [
      %DocumentationFragment{
        type: :function,
        fragment_text: "Function: #{Atom.to_string(module)}.#{sig}\n\n#{doc}",
        source_module: module,
        function_signature: sig
      }
    ]
  end

  def function_to_fragment(module, {sig, doc}, max_word_count) do
    header = "Function: #{Atom.to_string(module)}.#{sig}"

    string_to_chunks(max_word_count - 2, doc)
    |> Enum.map(fn str ->
      %DocumentationFragment{
        type: :function,
        fragment_text: "#{header}\n\n#{str}",
        source_module: module,
        function_signature: sig
      }
    end)
  end

  defp string_to_chunks(max_word_count, str, current_str \\ "", chunks \\ [])
  defp string_to_chunks(_, "", word, acc), do: [word | acc]

  defp string_to_chunks(max_word_count, str, current_str, chunks) do
    {char, str} = String.next_codepoint(str)
    current_str = current_str <> char

    if current_str |> String.split() |> length() < max_word_count do
      string_to_chunks(max_word_count, str, current_str, chunks)
    else
      string_to_chunks(max_word_count, str, "", [current_str | chunks])
    end
  end
end
