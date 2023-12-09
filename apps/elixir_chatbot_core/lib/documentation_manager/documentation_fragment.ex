defmodule ElixirChatbotCore.DocumentationManager.DocumentationFragment do
  require Logger
  defstruct [:type, :fragment_text, :source_module, :function_signature]

  @type t :: %ElixirChatbotCore.DocumentationManager.DocumentationFragment{
          fragment_text: String.t(),
          function_signature: String.t() | nil,
          source_module: atom(),
          type: atom()
        }

  @spec module_to_fragment(atom, String.t(), keyword()) :: Enumerable.t(__MODULE__.t())
  def module_to_fragment(module, doc, opts) do
    case doc do
      :none ->
        []

      :hidden ->
        []

      _ ->
        strings_by_headings(doc, opts)
        |> Stream.map(fn doc ->
          %__MODULE__{
            type: :module,
            fragment_text: "Module #{Atom.to_string(module)}\n\n#{doc}",
            source_module: module,
            function_signature: nil
          }
        end)
    end
  end

  @spec function_to_fragment(atom, {any, String.t()}, keyword()) :: Enumerable.t(__MODULE__.t())
  def function_to_fragment(module, {sig, doc}, opts \\ []) do
    strings_by_headings(doc, opts)
    |> Stream.map(fn doc ->
      %__MODULE__{
        type: :function,
        fragment_text: "#{Atom.to_string(module)}.#{sig}\n\n#{doc}",
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

  defp strings_by_headings(text, opts) do
    max_token_count = Keyword.get(opts, :max_token_count)
    headings_split = Keyword.get(opts, :headings_split)
    prepend_parent_heading = Keyword.get(opts, :prepend_parent_heading)

    strings_by_headings(headings_split, prepend_parent_heading, max_token_count, text, 1)
  end

  defp strings_by_headings(headings_depth, prepend_headings, max_token_count, text, current_depth) do
    text
    |> String.split("\n")
    |> Stream.chunk_while(
      nil,
      fn cur, acc ->
        heading_text =
          if String.starts_with?(cur, String.duplicate("#", current_depth) <> " ") do
            {_, rest} = String.split_at(cur, current_depth)
            String.trim(rest)
          else
            nil
          end

        cond do
          is_nil(acc) && is_nil(heading_text) ->
            # first iteration, first line is not a heading
            {:cont, {[], [cur]}}

          is_nil(acc) && !is_nil(heading_text) ->
            # first iteration, first line is a heading
            {:cont, {[heading_text], [cur]}}

          is_nil(heading_text) ->
            # no new heading detected, continue current chunk
            {old_headings, old_lines} = acc
            {:cont, {old_headings, [cur | old_lines]}}

          true ->
            # new heading detected, emit old chunk and star up new chunk
            {old_headings, old_lines} = acc
            chunk = {old_headings, old_lines |> Enum.reverse() |> Enum.join("\n")}
            {:cont, chunk, {[heading_text], [cur]}}
        end
      end,
      fn acc ->
        if is_nil(acc) do
          # return empty stream
          {:cont, nil}
        else
          # only one iteration was done, wrap up and return a singleton stream
          {headings, lines} = acc
          {:cont, {headings, lines |> Enum.reverse() |> Enum.join("\n")}, nil}
        end
      end
    )
    |> Stream.flat_map(fn {headings, text} ->
      # split texts with regards to subheadings
      if headings_depth == current_depth do
        [{headings, text}]
      else
        strings_by_headings(
          headings_depth,
          prepend_headings,
          max_token_count,
          text,
          current_depth + 1
        )
        |> Stream.map(fn {subheadings, subtext} ->
          {Enum.concat(headings, subheadings), subtext}
        end)
      end
    end)
    |> Stream.flat_map(fn {headings, text} ->
      # split sections which are too long
      if is_nil(max_token_count) do
        [{headings, text}]
      else
        string_to_chunks(max_token_count, text)
        |> Stream.map(fn text ->
          {headings, text}
        end)
      end
    end)
    |> Stream.filter(fn {_, text} ->
      # discard empty texts
      text
      |> String.trim()
      |> String.length() > 0
    end)
    |> Stream.map(fn {headings, text} ->
      if current_depth != 1 do
        {headings, text}
      else
        if prepend_headings do
          IO.inspect(headings)
          prepended =
            headings
            |> Stream.with_index(1)
            |> Stream.map(fn {heading, i} ->
              String.duplicate("#", i) <> " " <> heading
            end)
            |> Enum.join("\n\n")

          prepended <> "\n\n" <> text
        else
          text
        end
      end
    end)
  end
end
