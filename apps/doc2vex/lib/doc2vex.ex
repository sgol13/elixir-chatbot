defmodule Doc2vex do
  @moduledoc """
  Documentation for `Doc2vex`.
  """
  require Logger

  def test() do
    Logger.debug("Reading texts")

    texts =
      "tmp/stackexchange_duplicate_questions_body_body.jsonl"
      |> File.stream!()
      |> Stream.map(&JSON.decode!/1)
      |> Stream.concat()
      |> Stream.take(500)

    Logger.debug("Creating model")
    cbow = Doc2vex.Cbow.new(300, texts)

    Axon.Display.as_table(elem(cbow, 0), Nx.template({128, 4, map_size(elem(cbow, 1))}, {:f, 32}))
    |> IO.puts()

    Logger.debug("Training model")
    res = Doc2vex.Cbow.train(cbow)

    res
  end
end
