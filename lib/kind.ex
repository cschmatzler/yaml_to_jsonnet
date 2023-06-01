defmodule YamlToJsonnet.Kind do
  alias YamlToJsonnet.Imports
  alias YamlToJsonnet.Path

  @ignored_keys [
    ~w(apiVersion),
    ~w(kind),
    # FIXME: fix labels
    # and probably annotations, too - same format
    ~w(metadata labels),
    ~w(spec selector),
    ~w(spec template metadata labels)
  ]
  @core_replacements %{
    "containers" => "containers",
    "env" => "envVar",
    "ports" => "containerPort",
    "subjects" => "subject",
    "volumeMounts" => "volumeMount",
    "volumes" => "volume"
  }

  def translate_kind("Deployment" = kind, file) do
    # Move containers to their own definitions to make the resulting file more readable
    containers_path = ~w(spec template spec containers)
    ignored_keys = [containers_path]

    # TODO: Make images configurable through `$._images`.
    containers =
      Enum.map(
        get_in(file, containers_path),
        &{underscore(&1["name"]),
         translate(
           &1,
           @ignored_keys,
           @core_replacements,
           prefix: "container"
         )}
      )

    mixins =
      translate(file, @ignored_keys ++ ignored_keys, @core_replacements, prefix: "deployment")

    render_kind(kind,
      name: name(file),
      containers: containers,
      mixins: mixins
    )
  end

  def translate_kind(kind, file) do
    prefix = prefix(kind)
    mixins = translate(file, @ignored_keys, @core_replacements, prefix: prefix)

    render_kind(
      "generic",
      [name: name(file), imports: Imports.imports(kind), prefix: prefix, mixins: mixins],
      as: Macro.underscore(kind)
    )
  end

  defp render_kind(kind, assigns, _opts \\ []) do
    EEx.eval_file("lib/translator/#{Macro.underscore(kind)}.libsonnet.eex", assigns, trim: true)
  end

  defp translate(file, ignored_keys, replacements, opts) do
    file
    |> Enum.map(fn {k, v} -> Path.translate_path([], k, v, ignored_keys, replacements, opts) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" +\n")
  end

  defp name(file), do: underscore(get_in(file, ~w(metadata name)))

  defp prefix(kind) do
    {first, rest} = String.split_at(kind, 1)
    "#{String.downcase(first)}#{rest}"
  end

  defp underscore(string), do: String.replace(string, "-", "_")
end
