defmodule ElixirChatbotCore.GenerationModel do
  defprotocol GenerationModel do
    @spec generate(t(), String.t(), map()) :: {:ok, String.t()} | :error
    def generate(model, prompt, metadata)
  end
end
