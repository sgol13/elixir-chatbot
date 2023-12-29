defmodule ChatWeb.ChatLive do
  require Logger
  use ChatWeb, :live_view

  alias ChatWeb.Message

  def mount(_params, _session, socket) do
    initial_messages = [Message.bot_message("Hello, how can I help you?")]
    {:ok, assign(socket, messages: initial_messages, new_message: "")}
  end

  def handle_event("send_message", %{"new_message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"new_message" => message_text}, socket) do
    process_user_message(message_text)
    new_messages = [Message.user_message(message_text) | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages, new_message: "")}
  end

  def handle_event("message_change", _session, socket) do
    {:noreply, socket}
  end

  defp process_user_message(message_text) do
    Task.async(fn ->
      case ElixirChatbotCore.Chatbot.generate(message_text) do
        {:ok, response, fragments, _metadata} -> {:bot_message, response, fragments}
        {:error, err} -> {:bot_error, err}
      end
    end)
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
