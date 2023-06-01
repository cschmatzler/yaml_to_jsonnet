defmodule YamlToJsonnet do
  alias YamlToJsonnet.Kind

  def run(files) when is_list(files) do
    files
    |> Enum.map(fn file ->
      Kind.translate_kind(file["kind"], file)
    end)
  end
end
