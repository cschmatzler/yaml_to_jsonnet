defmodule YamlToJsonnet do
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
      [name: name(file), imports: imports(imports, prefix), prefix: prefix, mixins: mixins],
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

  defp prefix("CSIDriver"), do: "csiDriver"

  # Since k8s-libsonnet prefixes start lowercased, naively downcase the first letter of the `Kind` of the file.
  # Needs some extra handling for when this naive approach does not work, see `CSIDriver` above.
  defp prefix(kind) do
    {first, rest} = String.split_at(kind, 1)
    "#{String.downcase(first)}#{rest}"
  end

  defp imports(prefixes, base_prefix) do
    # Opposite of what we are doing in `Path.replace_with_imports/1`, we don't care about the path references here but
    # only about which import paths correspond with an import name.
    import_map =
      Path.as_import()
      |> Enum.map(fn {_ref, {prefix, import}} -> {prefix, import} end)
      |> Map.new()

    [base_prefix | prefixes]
    |> Enum.uniq()
    |> Enum.map(fn prefix -> "#{prefix} = #{Map.get(import_map, prefix)}" end)
    |> Enum.join(",\n")
  end

  # Rudimentary replacement of key-incompatible characters with underscores.
  defp underscore(string), do: string |> String.replace("-", "_") |> String.replace(".", "_")
end
