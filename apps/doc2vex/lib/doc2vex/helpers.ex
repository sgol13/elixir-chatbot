defmodule Doc2vex.Helpers do
  alias Doc2vex.Tokenizer

  @spec texts_to_sentences(Enumerable.t(binary())) :: Enumerable.t(Enumerable.t(binary()))
  def texts_to_sentences(texts) do
    texts
    |> Stream.map(&Tokenizer.tokenize/1)
    |> Stream.map(
      &Stream.chunk_while(
        &1,
        [],
        fn {word, type, opts}, acc ->
          is_word = type == Tokenizer.token_types().word

          chunk =
            if is_word do
              [word | acc]
            else
              acc
            end

          if Enum.member?(opts, :eos) do
            {:cont, chunk |> Enum.reverse(), []}
          else
            {:cont, chunk}
          end
        end,
        fn
          [] -> {:cont, []}
          acc -> {:cont, Enum.reverse(acc), []}
        end
      )
    )
    |> Stream.flat_map(&Function.identity/1)
  end

  @spec sentence_to_windows(Enumerable.t(binary()), pos_integer()) :: [
          {binary(), Enumerable.t(binary())}
        ]
  def sentence_to_windows(sentence, window_size) do
    sentence_to_windows(sentence, window_size, [])
  end

  defp sentence_to_windows(sentence, window_size, acc) when length(sentence) < window_size do
    acc
  end

  defp sentence_to_windows(sentence, window_size, acc) do
    context = Enum.take(sentence, window_size)
    {pre, [center | post]} = Enum.split(context, div(window_size, 2))

    [_ | next] = sentence
    sentence_to_windows(next, window_size, [{center, Enum.concat(pre, post)} | acc])
  end
end
