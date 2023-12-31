defmodule ChatWeb.Markdown do
  def to_html(text) do
    text
    |> Earmark.as_html!()
    |> String.replace(~r/<p>/, "<p style=\"padding-top: 5px; padding-bottom: 5px;\">")
    |> String.replace(~r/<ol>/, "<ol style=\"list-style-type: decimal; list-style-position: inside; display: block; list-style: decimal  outside none; margin: 1em 0; padding: 0 0 0 40px;\">")
    |> String.replace(~r/<ul>/, "<ul style=\"list-style-type: disc; list-style-position: inside; display: block; list-style: disc  outside none; margin: 1em 0; padding: 0 0 0 40px;\">")
    |> String.replace(~r/<a/, "<a style=\"text-decoration: underline; color: blue;\"")
    |> String.replace(~r/<pre>/, "<pre style=\"overflow: auto hidden;\">")
    |> String.replace(~r/class="elixir"/, "class=\"language-elixir\"")
    |> String.replace(~r/<code>/, "<code class=\"language-elixir\">")
  end
end
