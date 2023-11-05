defmodule ElixirChatbotCore.GenerationModel.HuggingfaceModel do
  require Logger
  alias ElixirChatbotCore.GenerationModel.HuggingfaceModel
  alias ElixirChatbotCore.GenerationModel.GenerationModel

  defstruct [:serving_type, :serving, :name, :output_type]

  @spec new(Bumblebee.repository(), keyword()) :: %HuggingfaceModel{}
  def new(repository, opts \\ []) do
    {output_type, serving} = load_model(repository, opts)
    Logger.info("Generation model loaded.")
    %__MODULE__{serving: serving, serving_type: :inline, output_type: output_type}
  end

  @spec serve(%HuggingfaceModel{}, atom(), keyword()) ::
          {%HuggingfaceModel{}, {module(), term()}}
  def serve(%__MODULE__{serving: serving, output_type: output_type}, name, opts \\ []) do
    options =
      Keyword.merge([name: name, serving: serving, batch_size: 1, batch_timeout: 300_000], opts)

    spec = {Nx.Serving, options}
    model = %__MODULE__{name: name, serving_type: :stateful, output_type: output_type}
    {model, spec}
  end

  defimpl GenerationModel, for: HuggingfaceModel do
    @impl true
    def generate(model, prompt, _metadata) do
      res =
        case model do
          %HuggingfaceModel{serving_type: :stateful, name: name} ->
            Nx.Serving.batched_run(name, prompt)

          %HuggingfaceModel{serving_type: :inline, serving: serving} ->
            Nx.Serving.run(serving, prompt)
        end

      %HuggingfaceModel{output_type: output_type} = model

      case output_type do
        :text ->
          %{results: [%{text: generated_text}]} = res
          {:text, generated_text}
        :stream ->
          {:stream, res}
      end
    end
  end

  defp load_model(repository, opts \\ []) do
    load_model_opts = Keyword.get(opts, :load_model_opts, [])
    load_tokenizer_opts = Keyword.get(opts, :load_tokenizer_opts, [])
    load_generation_config_opts = Keyword.get(opts, :load_generation_config_opts, [])
    configure_opts = Keyword.get(opts, :configure_opts, [])
    generation_opts = Keyword.get(opts, :generation_opts)


    Logger.info("Loading model #{inspect(repository)}.")
    {:ok, model_info} = Bumblebee.load_model(repository, load_model_opts)
    Logger.info("Loading tokenizer.")
    {:ok, tokenizer} = Bumblebee.load_tokenizer(repository, load_tokenizer_opts)
    Logger.info("Loading config.")
    {:ok, generation_config} = Bumblebee.load_generation_config(repository, load_generation_config_opts)

    generation_config = Bumblebee.configure(generation_config, configure_opts)

    type = if Keyword.get(generation_opts, :stream) do
      :stream
    else
      :text
    end

    {type, Bumblebee.Text.generation(model_info, tokenizer, generation_config, generation_opts)}
  end
end
