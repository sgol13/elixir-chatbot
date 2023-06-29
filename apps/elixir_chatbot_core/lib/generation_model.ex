defmodule ElixirChatbotCore.GenerationModel do
  use GenServer
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(repository) do
    serving = load_model(repository)
    Logger.info("Generation model loaded.")
    {:ok, serving}
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [{:hf, "gpt2"}]},
      type: :worker
    }
  end

  def generate(prompt) do
    GenServer.call(__MODULE__, {:generate, prompt}, 100_000)
  end

  def generate_answer(question) do
    "Question: #{question} Response: "
    |> generate
  end

  def handle_call({:generate, prompt}, _from, serving) do
    Logger.info("Generating text for prompt [#{prompt}]")
    %{results: [%{text: generated_text}]} = Nx.Serving.run(serving, prompt)
    {:reply, generated_text, serving}
  end

  defp load_model(repository) do
    Logger.info("Loading model #{inspect(repository)}.")
    {:ok, model_info} = Bumblebee.load_model(repository)
    {:ok, tokenizer} = Bumblebee.load_tokenizer(repository)
    {:ok, generation_config} = Bumblebee.load_generation_config(repository)

    generation_config =
      Bumblebee.configure(generation_config, min_new_tokens: 3, max_new_tokens: 50)

    Bumblebee.Text.generation(model_info, tokenizer, generation_config,
      compile: [batch_size: 1, sequence_length: 100]
    )
  end
end
