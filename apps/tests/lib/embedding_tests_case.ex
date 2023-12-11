defmodule Tests.EmbeddingTestsCase do
  alias ElixirChatbotCore.EmbeddingModel.EmbeddingParameters
  alias Tests.EmbeddingTestsCase

  defstruct [
    :embedding_model,
    :similarity_metrics,
    :docs_db
  ]

  defimpl Jason.Encoder, for: EmbeddingTestsCase do
    def encode(params, _options) do
      {_source, model_name} = params.embedding_model
      %{
        embedding_model: model_name,
        similarity_metrics: params.similarity_metrics,
        docs_db: params.docs_db
      }
      |> Jason.encode!
    end
  end

  @spec to_embedding_params(%EmbeddingTestsCase{}) :: %EmbeddingParameters{}
  def to_embedding_params(test_case) do
    %EmbeddingParameters{
      embedding_model: test_case.embedding_model,
      similarity_metrics: test_case.similarity_metrics
    }
  end
end
