defmodule ElixirChatbotCore.GenerationModel do
  defprotocol GenerationModel do
    @spec generate(t(), String.t(), map()) :: String.t()
    def generate(model, prompt, metadata)
  end
end
