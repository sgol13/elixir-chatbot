defmodule ElixirChatbotCore.EmbeddingModel.HuggingfaceModel do
  require Logger
  alias ElixirChatbotCore.EmbeddingModel.HuggingfaceModel
  import Nx.Defn
  defstruct [:embedding_size, :serving]

  def new(model_name, chunk_size) do
    {:ok, %{model: model, params: params}} = Bumblebee.load_model({:hf, model_name})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name})

    input_template = %{
      "attention_mask" => Nx.template({1, 42}, :u32),
      "input_ids" => Nx.template({1, 42}, :u32),
      "token_type_ids" => Nx.template({1, 42}, :u32)
    }

    out_shape = Axon.get_output_shape(model, input_template)
    {_, embedding_size} = out_shape.pooled_state

    serving =
      Nx.Serving.new(fn opts ->
        runner = Nx.Defn.jit(&runner/3)
        {_, predict_fun} = Axon.build(model, opts)

        fn input ->
          {input, _} =
            Nx.LazyContainer.traverse(input, nil, fn template, t, _ ->
              if Nx.rank(template) > 2 do
                [tok_size | _] =
                  template
                  |> Nx.shape()
                  |> Tuple.to_list()
                  |> Enum.reverse()

                {Nx.reshape(t.(), {:auto, tok_size}), nil}
              else
                {t.(), nil}
              end
            end)

          res = runner.(predict_fun, params, input)

          Nx.stack([res.pooled_state])
        end
      end)
      |> Nx.Serving.client_preprocessing(fn input ->
        input = Bumblebee.apply_tokenizer(tokenizer, input)

        {input, _} =
          Nx.LazyContainer.traverse(input, nil, fn template, tensor, _ ->
            {_, len} = Nx.shape(template)
            remainder = rem(len, chunk_size)

            t =
              if remainder == 0 do
                tensor.()
              else
                pad_amount = chunk_size - remainder
                Nx.pad(tensor.(), 0, [{0, 0, 0}, {0, pad_amount, 0}])
              end

            {t, nil}
          end)

        batch = Nx.Batch.stack([input])

        {batch, nil}
      end)

    %HuggingfaceModel{
      serving: serving,
      embedding_size: embedding_size
    }
  end

  defnp runner(predict_fn, params, input) do
    predict_fn.(params, input)
  end

  def generate_embedding(%HuggingfaceModel{serving: serving}, text) do
    Nx.Serving.run(serving, [text])
    |> Nx.squeeze()
  end

  def generate_many(%HuggingfaceModel{serving: serving}, texts) do
    serving
    |> Nx.Serving.run(texts)
    |> Nx.reshape({length(texts), :auto})
  end

  defimpl ElixirChatbotCore.EmbeddingModel.EmbeddingModel, for: HuggingfaceModel do
    @impl true
    @spec generate_embedding(%HuggingfaceModel{}, String.t()) :: Nx.Tensor.t()
    def generate_embedding(model, text) do
      HuggingfaceModel.generate_embedding(model, text)
    end

    @impl true
    @spec generate_many(%HuggingfaceModel{}, [String.t()]) :: Nx.Tensor.t()
    def generate_many(model, texts) do
      HuggingfaceModel.generate_many(model, texts)
    end

    @impl true
    @spec get_embedding_dimension(%HuggingfaceModel{}) :: non_neg_integer()
    def get_embedding_dimension(%HuggingfaceModel{embedding_size: embedding_size}) do
      embedding_size
    end
  end
end
