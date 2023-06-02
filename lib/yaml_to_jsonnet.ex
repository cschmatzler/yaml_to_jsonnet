defmodule YamlToJsonnet do
  import YamlToJsonnet.Imports
  alias YamlToJsonnet.Path

  def run(files) when is_list(files) do
    Enum.map(files, fn file ->
      translate_file(file)
    end)
  end

  def translate_file(file) do
    kind = Map.get(file, "kind")
    prefix = prefix(kind)

    {mixins, imports} = translate(file, prefix: prefix)

    render(
      [name: name(file), imports: imports(imports), prefix: prefix, mixins: mixins],
      as: Macro.underscore(kind)
    )
  end

  defp render(assigns, _opts \\ []) do
    EEx.eval_file("lib/templates/output.libsonnet.eex", assigns, trim: true)
  end

  defp translate(file, opts) do
    Enum.map(file, fn {k, v} ->
      Path.translate_path([], k, v, [], opts)
    end)
    |> Path.reduce_outputs()
  end

  defp name(file), do: underscore(get_in(file, ~w(metadata name)))

  defp prefix(kind) do
    {first, rest} = String.split_at(kind, 1)
    "#{String.downcase(first)}#{rest}"
  end

  defp underscore(string), do: String.replace(string, "-", "_")
end
