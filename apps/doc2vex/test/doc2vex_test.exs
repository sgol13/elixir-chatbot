defmodule Doc2vexTest do
  use ExUnit.Case
  doctest Doc2vex

  test "greets the world" do
    assert Doc2vex.hello() == :world
  end
end
