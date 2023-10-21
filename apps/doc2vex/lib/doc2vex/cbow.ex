defmodule Doc2vex.Cbow do
  require Logger
  alias Doc2vex.Helpers

  import Nx.Defn

  defstruct [:embedding_matrix, :vocabulary]

  @spec new(pos_integer(), Enumerable.t(binary()), [
          {:window_size, pos_integer()},
          {:train_test_split, float()}
        ]) ::
          {Axon.t(), map(),
           {Enumerable.t({binary(), [binary()]}), Enumerable.t({binary(), [binary()]})}}
  def new(embedding_size, input_stream, opts \\ []) do
    Logger.debug("Tokenizing input data...")
    sentences = Helpers.texts_to_sentences(input_stream)

    window_size = Keyword.get(opts, :window_size, 5)
    train_test_split = Keyword.get(opts, :train_test_split, 0.8)

    Logger.debug("Generating input contexts...")

    contexts =
      sentences
      |> Flow.from_enumerable()
      |> Flow.partition()
      |> Flow.flat_map(&Helpers.sentence_to_windows(&1, window_size))
      |> Flow.map(fn e -> {e, :rand.uniform()} end)

    {train, test} = {
      contexts
      |> Flow.filter(fn {_, v} -> v <= train_test_split end)
      |> Flow.map(&elem(&1, 0))
      |> Enum.to_list(),
      contexts
      |> Flow.filter(fn {_, v} -> v > train_test_split end)
      |> Flow.map(&elem(&1, 0))
      |> Enum.to_list()
    }

    Logger.debug("Generating vocabulary...")

    vocabulary =
      sentences
      |> Stream.concat()
      |> Flow.from_enumerable()
      |> Flow.partition()
      |> Flow.reduce(fn -> %{} end, fn word, acc ->
        if Map.has_key?(acc, word) do
          acc
        else
          Map.put(acc, word, map_size(acc))
        end
      end)
      |> Map.new()

    inputs = Axon.input("one_hot_input", shape: {nil, map_size(vocabulary), window_size - 1})

    model =
      inputs
      |> Axon.dense(embedding_size, name: "custom_embedding")
      |> Axon.nx(&mean_across_axis1/1)
      |> Axon.dense(map_size(vocabulary))
      |> Axon.softmax()

    {model, vocabulary, {train, test}}
  end

  defnp mean_across_axis1(t) do
    Nx.mean(t, axes: [1])
  end

  @spec predict(%Doc2vex.Cbow{}, binary()) :: {:error, binary()} | Nx.Tensor.t()
  def predict(%__MODULE__{vocabulary: v, embedding_matrix: m}, word) do
    case Map.get(v, String.downcase(word)) do
      nil -> {:error, "Word \"#{word}\" is not included in the model's vocabulary."}
      i -> {:ok, m[i]}
    end
  end

  def train({model, vocabulary, {train_data, test_data}}, opts \\ []) do
    optimizer = Keyword.get(opts, :optimizer, :adam)
    trainer_opts = Keyword.get(opts, :trainer_opts, [])
    runner_opts = Keyword.get(opts, :runner_opts, [])
    batch_size = Keyword.get(opts, :batch_size, 32)

    train_data = context_to_data(train_data, vocabulary, batch_size)

    trained_state =
      Axon.Loop.trainer(model, :categorical_cross_entropy, optimizer, trainer_opts)
      |> Axon.Loop.run(train_data, %{}, runner_opts)

    test_data = context_to_data(test_data, vocabulary, batch_size)

    test_results =
      Axon.Loop.evaluator(model)
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.run(test_data, trained_state, runner_opts)

    {test_results,
     %__MODULE__{
       vocabulary: vocabulary,
       embedding_matrix: trained_state |> Map.get("custom_embedding") |> Map.get("kernel")
     }}
  end

  defp context_to_data(tuples, vocab, batch_size) do
    size = map_size(vocab)

    tuples
    |> Stream.map(fn {word, rest} ->
      expected =
        for i <- 0..(size - 1) do
          if i == Map.get(vocab, word) do
            1.0
          else
            0.0
          end
        end

      input =
        for word <- rest do
          for i <- 0..(size - 1) do
            if Map.get(vocab, word) == i do
              1.0
            else
              0.0
            end
          end
        end

      {Nx.tensor(input), Nx.tensor(expected)}
    end)
    |> Stream.chunk_every(batch_size, batch_size, :discard)
    |> Stream.map(fn chunk ->
      {x, y} = Enum.unzip(chunk)
      {Nx.stack(x), Nx.stack(y)}
    end)
  end
end
