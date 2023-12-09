defmodule Tests.EmbeddingTestsCase do

  @derive Jason.Encoder
  defstruct [
    :embedding_model,
    :similarity_metrics,
    :docs_db
  ]

  def to_index_params(test_case) do
    Map.take(test_case, [:embedding_model, :similarity_metrics])
  end
end
