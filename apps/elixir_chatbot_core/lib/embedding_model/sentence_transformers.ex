defmodule ElixirChatbotCore.EmbeddingModel.SentenceTransformers do
  alias ElixirChatbotCore.EmbeddingModel.SentenceTransformers
  import Nx.Defn
  defstruct [:runner, :embedding_size]

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

    %SentenceTransformers{
      runner: runner,
      embedding_size: embedding_size
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

  defimpl ElixirChatbotCore.EmbeddingModel.EmbeddingModel, for: SentenceTransformers do
    @impl true
    @spec generate_embedding(%SentenceTransformers{}, String.t()) ::
            {:ok, Nx.Tensor.t()} | {:error, String.t()}
    def generate_embedding(model, text) do
      SentenceTransformers.generate_embedding(model, text)
    end

    @impl true
    @spec get_embedding_dimension(%SentenceTransformers{}) :: non_neg_integer()
    def get_embedding_dimension(%SentenceTransformers{embedding_size: embedding_size}) do
      embedding_size
    end
  end
end
