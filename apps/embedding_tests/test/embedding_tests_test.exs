defmodule EmbeddingTestsTest do
  use ExUnit.Case
  doctest EmbeddingTests

  test "greets the world" do
    assert EmbeddingTests.hello() == :world
  end
end
