defmodule ElixirChatbotCoreTest do
  use ExUnit.Case
  doctest ElixirChatbotCore

  test "greets the world" do
    assert ElixirChatbotCore.hello() == :world
  end
end
