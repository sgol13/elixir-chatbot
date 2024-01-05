defmodule ChatWeb.ChatLive do
  alias ElixirChatbotCore.Message
  require Logger

  use ChatWeb, :live_view

  @last_messages_limit 10

  def mount(_params, _session, socket) do
    initial_messages = [Message.bot_message("Hello, how can I help you?")]
    {:ok, assign(socket, messages: initial_messages, new_message: "")}
  end

  def handle_event("send_message", %{"new_message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"new_message" => message_text}, socket) do
    new_messages = process_user_message(message_text, socket.assigns.messages)
    {:noreply, assign(socket, messages: new_messages, new_message: "")}
  end

  def handle_event("message_change", _session, socket) do
    {:noreply, socket}
  end

  defp process_user_message(message_text, past_messages) do
    new_messages = [Message.user_message(message_text) | past_messages]

    last_messages =
      new_messages
      |> Stream.map(&Message.discard_fragments/1)
      |> Enum.take(@last_messages_limit)

    Task.async(fn ->
      case ElixirChatbotCore.Chatbot.generate(last_messages) do
        {:ok, response, fragments, _metadata} -> {:bot_message, response, fragments}
        {:error, err} -> {:bot_error, err}
      end
    end)

    new_messages
  end

  def handle_info({:DOWN, _ref, _, _, _reason}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, {:bot_error, _exception}}, socket) do
    new_messages = [Message.bot_message("Error creating the response.") | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages)}
  end

  def handle_info({_ref, {:bot_message, message_text, fragments}}, socket) do
    new_messages = [Message.bot_message(message_text, fragments) | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages)}
  end
end
