defmodule Mix.Tasks.ManualTests do
  use Mix.Task
  @requirements ["app.config", "app.start"]

  @spec run(args :: [String.t()]) :: any()
  def run(args) do
    IO.inspect(args)

    Tests.ManualEmbeddingTests.run
  end
end
