defmodule ChatWeb.ChatLive do
  require Logger
  use ChatWeb, :live_view

  alias ChatWeb.Message

  def mount(_params, _session, socket) do
    key = UUID.uuid4()
    initial_messages = %{key => Message.bot_message("Hello, how can I help you?")}
    {:ok, assign(socket, messages: initial_messages, new_message: "")}
  end

  def handle_event("send_message", %{"new_message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", %{"new_message" => message_text}, socket) do
    new_messages =
      socket.assigns.messages |> Map.put(UUID.uuid4(), Message.user_message(message_text))

    send_update(ChatWeb.MessagesWindowComponent, id: "messages_window", messages: new_messages)

    pid = self()

    {:noreply,
     socket
     |> assign(new_message: "")
     |> Phoenix.LiveView.start_async(:pending_message, fn ->
       process_user_message(message_text, socket.assigns, pid)
     end)}
  end

  defp process_user_message(message_text, assigns, pid) do
    case ChatWeb.BotFacade.generate(message_text) do
      {:ok, response, fragments} ->
        case response do
          {:text, response_text} ->
            new_messages =
              assigns.messages
              |> Map.put(UUID.uuid4(), Message.bot_message(response_text, fragments))

            send_update(pid, ChatWeb.MessagesWindowComponent,
              id: "messages_window",
              messages: new_messages
            )

          {:stream, response_stream} ->
            key = UUID.uuid4()

            new_messages =
              assigns.messages
              |> Map.put(key, Message.bot_message("", fragments))

            send_update(pid, ChatWeb.MessagesWindowComponent,
              id: "messages_window",
              messages: new_messages
            )

            ts = :calendar.local_time()

            :ok =
              response_stream
              |> Stream.scan(fn cur, acc -> acc <> cur end)
              |> Stream.each(fn message_fragment ->
                new_messages =
                  assigns.messages
                  |> Map.update(
                    key,
                    Message.bot_message(message_fragment, fragments),
                    fn old_message ->
                      %Message{old_message | text: message_fragment, timestamp: ts}
                    end
                  )

                send_update(pid, ChatWeb.MessagesWindowComponent,
                  id: "messages_window",
                  messages: new_messages
                )
              end)
              |> Stream.run()
        end

      {:error, _err} ->
        new_messages =
          assigns.messages |> Map.put(UUID.uuid4(), Message.bot_message("Error creating the response."))

        send_update(pid, ChatWeb.MessagesWindowComponent,
          id: "messages_window",
          messages: new_messages
        )
    end
  end

  def handle_async(:pending_message, _, socket) do
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, _, _, _reason}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, {:message_fragment, key, fragment}}, socket) do
    new_messages =
      socket.messages
      |> Map.update(key, Message.bot_message(fragment), fn prev_message ->
        %Message{prev_message | text: prev_message.text <> fragment}
      end)

    {:noreply, assign(socket, messages: new_messages)}
  end

  def handle_info({_ref, {:hook, _}}, socket) do
    {:noreply, socket}
  end

  def handle_info({_ref, {:batch, _}}, socket) do
    {:noreply, socket}
  end
end
