defmodule ElixirChatbotCore.GenerationModel do
  defprotocol GenerationModel do
    @spec generate(t(), [String.t()], [String.t()], map()) ::
            {:ok, String.t(), [String.t()]} | :error
    def generate(model, messages, fragments, metadata \\ %{})
  end

  def select_fragments(fragments, count_tokens_fn, max_tokens, opts \\ []) do
    fragment_overhead = Keyword.get(opts, :fragment_overhead, 0)

    selected_fragments = fragments
    |> Enum.reduce({0, []}, fn fragment, {sum, prefix_sums} ->
      new_sum = sum + count_tokens_fn.(fragment) + fragment_overhead
      {new_sum, [{fragment, new_sum} | prefix_sums]}
    end)
    |> Kernel.then(fn {_sum, prefix_sums} -> prefix_sums end)
    |> Enum.reverse
    |> Enum.take_while(fn {_fragment, prefix_sum} -> prefix_sum <= max_tokens end)

    {_last_fragment, total_tokens} = List.last(selected_fragments, 0)

    selected_fragments = selected_fragments
    |> Enum.map(fn {fragment, _prefix_sum} -> fragment end)

    {selected_fragments, total_tokens}
  end
end
