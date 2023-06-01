defmodule YamlToJsonnet do
  alias YamlToJsonnet.Kind

  def run(files) when is_list(files) do
    Enum.map(files, fn file ->
      Kind.translate_kind(file["kind"], file)
    end)
  end
end
