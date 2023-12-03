defmodule TestsTest do
  use ExUnit.Case
  doctest Tests

  test "greets the world" do
    assert Tests.hello() == :world
  end
end
