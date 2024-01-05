defmodule ElixirChatbotCore.Message do
  alias ElixirChatbotCore.Message

  defstruct [:text, :role, :id, :fragments]

  def user_message(message_text) do
    %Message{text: message_text, role: :user, id: UUID.uuid4()}
  end

  def bot_message(message_text, fragments \\ []) do
    %Message{text: message_text, role: :bot, id: UUID.uuid4(), fragments: fragments}
  end

  def discard_fragments(message) do
    Map.delete(message, :fragments)
  end
end
