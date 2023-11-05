defmodule ChatWeb.Message do
  defstruct [:text, :sender, :fragments, :timestamp]

  def user_message(message_text) do
    %ChatWeb.Message{text: message_text, sender: :user, timestamp: :calendar.local_time()}
  end

  def bot_message(message_text, fragments \\ []) do
    %ChatWeb.Message{
      text: message_text,
      sender: :bot,
      fragments: fragments,
      timestamp: :calendar.local_time()
    }
  end
end
