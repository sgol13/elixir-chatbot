defmodule ElixirChatbotCore.GenerationModel do
  defprotocol GenerationModel do
    @spec generate(t(), String.t(), map()) :: {:text, String.t()} | {:stream, Enumerable.t(String.t())}
    def generate(model, prompt, metadata)
  end
end
