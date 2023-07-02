defmodule ElixirChatbotCore.EmbeddingModel.SentenceTransformers do
  alias ElixirChatbotCore.EmbeddingModel.SentenceTransformers
  import Nx.Defn
  defstruct [:runner, :embedding_size, :run_many]

  @base_path "sentence-transformers"

  def new(model_name) do
    ref = "#{@base_path}/#{model_name}"
    {:ok, %{model: model, params: params}} = Bumblebee.load_model({:hf, ref})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, ref})

    input_template = %{
      "attention_mask" => Nx.template({1, 42}, :u32),
      "input_ids" => Nx.template({1, 42}, :u32),
      "token_type_ids" => Nx.template({1, 42}, :u32)
    }

    out_shape = Axon.get_output_shape(model, input_template)
    {_, embedding_size} = out_shape.pooled_state

    {_, predict_function} = Axon.build(model)

    postprocess =
      Nx.Defn.compile(&postprocess/1, [Nx.template(out_shape.pooled_state, :f32)], compiler: EXLA)

    runner = fn tokens ->
      inputs = Bumblebee.apply_tokenizer(tokenizer, tokens)

      res =
        predict_function.(params, inputs).pooled_state
        |> postprocess.()

      {:ok, res}
    end

    run_many = fn texts ->
      inputs = Bumblebee.apply_tokenizer(tokenizer, texts)

      {num_of_inputs, len} = Nx.shape(Map.get(inputs, "attention_mask"))

      {_, compiled_predict} =
        Axon.compile(
          model,
          %{
            "attention_mask" => Nx.template({1, len}, :u32),
            "input_ids" => Nx.template({1, len}, :u32),
            "token_type_ids" => Nx.template({1, len}, :u32)
          },
          params,
          compiler: EXLA
        )

      0..(num_of_inputs - 1)
      |> Stream.map(fn i ->
        transformed_input =
          inputs |> Enum.map(fn {k, v} -> {k, Nx.stack([v[i]])} end) |> Map.new()

        compiled_predict.(params, transformed_input).pooled_state
        |> postprocess.()
      end)
    end

    %SentenceTransformers{
      runner: runner,
      embedding_size: embedding_size,
      run_many: run_many
    }
  end

  defnp postprocess(tokens) do
    Nx.squeeze(tokens)
  end

  def generate_embedding(
        %SentenceTransformers{
          runner: runner
        },
        text
      ) do
    runner.(text)
  end

  def generate_many(%SentenceTransformers{run_many: run_many}, texts) do
    run_many.(texts)
  end

  defimpl ElixirChatbotCore.EmbeddingModel.EmbeddingModel, for: SentenceTransformers do
    @impl true
    @spec generate_embedding(%SentenceTransformers{}, String.t()) ::
            {:ok, Nx.Tensor.t()} | {:error, String.t()}
    def generate_embedding(model, text) do
      SentenceTransformers.generate_embedding(model, text)
    end

    @impl true
    @spec generate_many(%SentenceTransformers{}, [String.t()]) :: Enumerable.t(Nx.Tensor.t())
    def generate_many(model, texts) do
      SentenceTransformers.generate_many(model, texts)
    end

    @impl true
    @spec get_embedding_dimension(%SentenceTransformers{}) :: non_neg_integer()
    def get_embedding_dimension(%SentenceTransformers{embedding_size: embedding_size}) do
      embedding_size
    end
  end
end
