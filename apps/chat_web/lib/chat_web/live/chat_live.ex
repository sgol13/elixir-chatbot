defmodule ChatWeb.ChatLive do
  require Logger
  use ChatWeb, :live_view

  alias ChatWeb.Message

  def mount(_params, _session, socket) do
    key = UUID.uuid4()
    initial_messages = %{key => Message.bot_message("Hello, how can I help you?")}
    {:ok, assign(socket, messages: initial_messages)}
  end

  def handle_event("send_message", %{"new_message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"new_message" => message_text}, socket) do
    process_user_message(message_text)
    new_messages = socket.assigns.messages |> Map.put(UUID.uuid4(), Message.user_message(message_text))
    {:noreply, assign(socket, messages: new_messages)}
  end

  defp process_user_message(message_text) do
    Task.async(fn ->
      case ChatWeb.BotFacade.generate(message_text) do
        {:ok, response, fragments} -> {:bot_message, response, fragments}
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

  def handle_info({_ref, {:bot_message, response, fragments}}, socket) do
    key = UUID.uuid4()
    message_text = case response do
      {:text, _} -> response
      {:stream, response_stream} ->
        :ok = response_stream
        |> Stream.with_index()
        |> Stream.each(fn frag -> Task.async(&({:message_fragment, key, frag})) end)
        |> Stream.run()
        {:stream, []}
    end
    new_messages = [Message.bot_message(message_text, fragments) | socket.assigns.messages]
    {:noreply, assign(socket, messages: new_messages)}
  end

  def handle_info({_ref, {:message_fragment, key, fragment}}, socket) do

  end
end
