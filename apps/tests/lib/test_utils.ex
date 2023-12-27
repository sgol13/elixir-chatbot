defmodule Tests.TestUtils do
  alias ElixirChatbotCore.DocumentationManager.DocumentationFragment

  @spec generate_output_name() :: String.t()
  def generate_output_name do
    DateTime.utc_now()
    |> Timex.format!("{YYYY}-{0M}-{0D}-{h24}{m}{s}")
  end

  @spec fragments_to_html(DocumentationFragment.t()) :: String.t()
  def fragments_to_html(fragments) do
    fragments
    |> Stream.map(fn fragment ->
      """
        <b> [#{fragment.type}] #{fragment.source_module}.#{fragment.function_signature} </b>
        <div style="background-color: #f0f0f0"> #{Earmark.as_html!(fragment.fragment_text)} </div>
      """
    end)
    |> Enum.join
  end
end
