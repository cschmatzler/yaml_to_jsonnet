defmodule YamlToJsonnet do
  alias YamlToJsonnet.Path

  def run(files, name) when is_list(files) do
    Enum.map(files, fn file ->
      translate_file(file, name)
    end)
  end

  def translate_file(file, name) do
    kind = Map.get(file, "kind")
    prefix = prefix(kind)

    {mixins, imports, images} = translate(file, name: Path.underscore(name), prefix: prefix)

    render(
      [
        name: Path.underscore(name),
        imports: imports(imports, prefix),
        images: images,
        prefix: prefix,
        mixins: mixins
      ],
      name: name,
      kind: Path.underscore(kind)
    )
  end

  defp render(assigns, opts) do
    {"#{opts[:kind]}-#{opts[:name]}.libsonnet",
     EEx.eval_file("lib/templates/output.libsonnet.eex", assigns, trim: true)}
  end

  defp translate(file, opts) do
    Enum.map(file, fn {k, v} ->
      Path.translate_path([], k, v, [], [], opts)
    end)
    |> Path.reduce_outputs()
  end

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

end
