defmodule Doc2vex.Tokenizer do
  @token_types %{
    word: 0,
    punctuation: 1,
    number: 2,
    symbol: 3,
    unknown: 4
  }

  def token_types, do: @token_types

  @word_re ~r/^\p{L}+$/u
  @number_re ~r/^(?=.)([+-]?([\p{N}]*)([\.,](\p{N}+))?)$/u
  @punctuation_re ~r/^(\p{P})+$/u
  @symbol_re ~r/^\p{S}+$/u
  @sentence_term_re ~r/^[!?\.]+$/u
  @escape_sequence_re ~r/^\\(([0abtnvfres"\#\\])|(x[0-9a-fA-F]{2})|(u[0-9a-fA-F]{4})|(u\{[0-9a-fA-F]{6}\}))$/u
  @other_res [
    # elixir string escape characters
    ~r/^(.*[^\\])((\\[0abtnvfres"\#\\])|(\\x[0-9a-fA-F]{2})|(\\u[0-9a-fA-F]{4})|(\\u\{[0-9a-fA-F]{6}\}))(.+)$/u,
    ~r/^((\\[0abtnvfres"\#\\])|(\\x[0-9a-fA-F]{2})|(\\u[0-9a-fA-F]{4})|(\\u\{[0-9a-fA-F]{6}\}))(.+)$/u,
    ~r/^(.*[^\\])((\\[0abtnvfres"\#\\])|(\\x[0-9a-fA-F]{2})|(\\u[0-9a-fA-F]{4})|(\\u\{[0-9a-fA-F]{6}\}))$/u,
    # prefixed with a punctuation mark
    ~r/^(\p{P}+)(.+)$/u,
    # postfixed with a punctuation mark
    ~r/^(.*[^\p{P}])(\p{P}+)$/u,
    # infixed with punctuation, e.g. hyphenated
    ~r/^(.*[^\p{P}])(\p{P}+)(.+)$/u
  ]

  @spec tokenize(binary()) :: Enumerable.t({binary(), non_neg_integer(), [atom()]})
  def tokenize(text) do
    text
    |> split_initial()
    |> process_split_text()
  end

  defp process_split_text(text), do: process_split_text(text, [])

  defp process_split_text([], done), do: Enum.reverse(done)

  defp process_split_text([head | tail], done) do
    case head do
      _ when is_binary(head) ->
        process_split_text([{:nonterm, head} | tail], done)

      {:nonterm, ""} ->
        process_split_text(tail, done)

      {:nonterm, text} ->
        res =
          @other_res
          |> Stream.map(&Regex.run(&1, text, capture: :all_but_first))
          |> Enum.find(nil, &(!is_nil(&1)))

        if is_nil(res) do
          cond do
            Regex.match?(@word_re, text) ->
              process_split_text(tail, [{String.downcase(text), @token_types.word, []} | done])

            Regex.match?(@number_re, text) ->
              process_split_text(tail, [{text, @token_types.number, []} | done])

            Regex.match?(@escape_sequence_re, text) ->
              cond do
                String.ends_with?(text, "\\") ->
                  process_split_text([{:nonterm, "\\"} | tail], done)

                String.ends_with?(text, "\#") ->
                  process_split_text([{:nonterm, "\#"} | tail], done)

                String.ends_with?(text, "\"") ->
                  process_split_text([{:nonterm, "\""} | tail], done)

                true ->
                  process_split_text(tail, done)
              end

            Regex.match?(@symbol_re, text) ->
              process_split_text(tail, [{text, @token_types.symbol, []} | done])

            Regex.match?(@punctuation_re, text) ->
              opts =
                if Regex.match?(@sentence_term_re, text) do
                  [:eos]
                else
                  []
                end

              process_split_text(tail, [{text, @token_types.punctuation, opts} | done])

            true ->
              process_split_text(tail, [{text, @token_types.unknown, []} | done])
          end
        else
          new_stack =
            res
            |> Enum.map(&{:nonterm, &1})
            |> Enum.concat(tail)

          process_split_text(new_stack, done)
        end
    end
  end

  defp split_initial(text) do
    String.split(text, ~r/\s+/u)
  end
end
