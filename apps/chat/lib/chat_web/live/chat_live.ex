defmodule ChatWeb.ChatLive do
  use ChatWeb, :live_view

  def mount(_params, _session, socket) do
    initial_messages = [create_bot_message("Hello, how can I help you?")]
    {:ok, assign(socket, messages: initial_messages, new_message: "")}
  end

  def handle_event("send_message", %{"new_message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"new_message" => message_text}, socket) do
    process_user_message(message_text)
    new_messages = [create_user_message(message_text) | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages, new_message: "")}
  end

  def handle_event("message_change", _session, socket) do
    {:noreply, socket}
  end

  defp process_user_message(message_text) do
    Task.async(fn ->
      try do
        response = Chat.BotFacade.send(message_text)
        {:bot_message, response}
      rescue
        exception -> {:bot_error, exception}
      catch
        exception -> {:bot_error, exception}
      end
    end)
  end

  def handle_info({:DOWN, _ref, _, _, _reason}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, {:bot_error, _exception}}, socket) do
    new_messages = [create_bot_message("Error creating the response.") | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages)}
  end

  def handle_info({_ref, {:bot_message, message_text}}, socket) do
    new_messages = [create_bot_message(message_text) | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages)}
  end

  defp create_user_message(message_text) do
    %{text: message_text, sender: :user, id: UUID.uuid4()}
  end

  defp create_bot_message(message_text) do
    %{text: message_text, sender: :bot, id: UUID.uuid4()}
  end
end
