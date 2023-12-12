defmodule ElixirChatbotCore.OpenAiClient do
  require Logger

  @openai_url "https://api.openai.com/"
  @openai_embeddings_url @openai_url <> "/v1/embeddings"
  @openai_completions_url @openai_url <> "/v1/chat/completions"

  @expected_http_code 200

  def post_embeddings(body, opts \\ []), do: post(@openai_embeddings_url, body, opts)

  def post_completions(body, opts \\ []), do: post(@openai_completions_url, body, opts)

  defp post(url, body, opts) do
    recv_timeout = Keyword.get(opts, :recv_timeout, 5000)
    retries = Keyword.get(opts, :retries, 0)

    headers = build_headers()

    encoded_body = Jason.encode!(body)
    request_fn = build_post_request_fn(url, encoded_body, headers, recv_timeout)

    case request_with_retries(request_fn, retries) do
      {:ok, %HTTPoison.Response{status_code: @expected_http_code, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      :error ->
        :error
    end
  end

  defp request_with_retries(request_fn, retries) do
    case make_request(request_fn) do
      {:ok, %HTTPoison.Response{status_code: @expected_http_code}} = result ->
        result

      _ when retries > 0 ->
        Logger.info("OpenAI API retry (#{retries} left)")
        request_with_retries(request_fn, retries - 1)

      _ ->
        :error
    end
  end

  defp make_request(request_fn) do
    case request_fn.() do
      {:ok, %HTTPoison.Response{status_code: @expected_http_code}} = result ->
        result

      {:ok, %HTTPoison.Response{status_code: status_code}} = result ->
        Logger.error("OpenAI API request error: received #{status_code}")
        result

      {:error, %HTTPoison.Error{reason: reason}} = result ->
        Logger.error("OpenAI API request error: could not establish connection (#{reason})")
        result
    end
  end

  defp build_post_request_fn(url, body, headers, recv_timeout) do
    fn -> HTTPoison.post(url, body, headers, recv_timeout: recv_timeout) end
  end

  defp build_headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{get_api_key()}"}
    ]
  end

  defp get_api_key, do: Application.fetch_env!(:chatbot, :openai_api_key)
end
