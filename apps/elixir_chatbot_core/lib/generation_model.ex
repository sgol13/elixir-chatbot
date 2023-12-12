defmodule ElixirChatbotCore.GenerationModel do
  defprotocol GenerationModel do
    @spec generate(t(), String.t(), [String.t()], map()) :: {:ok, String.t(), [String.t()]} | :error
    def generate(model, question, fragments, metadata \\ %{})
  end
end
