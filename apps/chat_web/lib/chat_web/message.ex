defmodule ChatWeb.Message do
  defstruct [:text, :sender, :id, :fragments]

  def user_message(message_text) do
    %ChatWeb.Message{text: message_text, sender: :user, id: UUID.uuid4()}
  end

  def bot_message(message_text, fragments \\ []) do
    %ChatWeb.Message{text: message_text, sender: :bot, id: UUID.uuid4(), fragments: fragments}
  end
end
