defmodule ElixirChatbotCore.GenerationModel.HuggingfaceModel do
  require Logger
  alias ElixirChatbotCore.GenerationModel.HuggingfaceModel
  alias ElixirChatbotCore.GenerationModel.GenerationModel

  defstruct [:type, :serving, :name]

  @spec new(Bumblebee.repository()) :: %HuggingfaceModel{}
  def new(repository) do
    serving = load_model(repository)
    Logger.info("Generation model loaded.")
    %__MODULE__{serving: serving, type: :inline}
  end

  @spec serve(%HuggingfaceModel{}, atom(), keyword()) ::
          {%HuggingfaceModel{}, {module(), term()}}
  def serve(%__MODULE__{serving: serving}, name, opts \\ []) do
    options =
      Keyword.merge([name: name, serving: serving, batch_size: 1, batch_timeout: 300_000], opts)

    spec = {Nx.Serving, options}
    model = %__MODULE__{name: name, type: :stateful}
    {model, spec}
  end

  defimpl GenerationModel, for: HuggingfaceModel do
    @impl true
    def generate(model, prompt, _metadata) do
      res =
        case model do
          %HuggingfaceModel{type: :stateful, name: name} ->
            Nx.Serving.batched_run(name, prompt)

          %HuggingfaceModel{type: :inline, serving: serving} ->
            Nx.Serving.run(serving, prompt)
        end

      %{results: [%{text: generated_text}]} = res

      generated_text
    end
  end

  defp load_model(repository) do
    Logger.info("Loading model #{inspect(repository)}.")
    {:ok, model_info} = Bumblebee.load_model(repository)
    Logger.info("Loading tokenizer.")
    {:ok, tokenizer} = Bumblebee.load_tokenizer(repository)
    Logger.info("Loading config.")
    {:ok, generation_config} = Bumblebee.load_generation_config(repository)

    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 100)

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 512]
    )
  end
end
