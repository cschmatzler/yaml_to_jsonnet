defmodule YamlToJsonnet.Path do
  @ignored_paths [
    ~w(apiVersion),
    ~w(kind)
  ]
  @as_import %{
    "containers" => "container",
    "initContainers" => "container",
    "env" => "envVar",
    "envFrom" => "envVarSource",
    "secretRef" => "secretReference",
    "ports" => "containerPort",
    "subjects" => "subject",
    "volumeMounts" => "volumeMount",
    "volumes" => "volume"
  }
  @as_object [
    "labels",
    "annotations",
    "imagePullSecrets"
  ]

  def translate_path(path, key, value, imports \\ [], opts \\ [])

  # Custom
  # ------

  # Since `emptyDir` is defined with `{}`, this would get swallowed as an empty value otherwise.
  def translate_path(_path, "emptyDir", %{}, _imports, _opts) do
    {"{emptyDir: {}}", []}
  end

  # Generic
  # -------

  def translate_path(path, key, value, imports, opts)
      when key in @as_object and is_map(value),
      do: translate_object(path, key, value, imports, opts)

  def translate_path(path, key, value, imports, opts)
      when is_map(value) do
    Enum.map(value, fn {k, v} ->
      translate_path(path ++ [key], k, v, imports, opts)
    end)
    |> reduce_outputs()
  end

  def translate_path(path, key, value, imports, opts)
      when is_list(value) do
    {values, imports} =
      Enum.map(value, &translate_list_item(path, key, &1, imports))
      |> reduce_outputs(",")

    translate_path(
      path,
      key,
      "[#{values}]",
      imports,
      Keyword.put(opts, :quote_value?, false)
    )
  end

  def translate_path(path, key, value, imports, opts) do
    unless Enum.any?(@ignored_paths, &List.starts_with?(path ++ [key], &1)) do
      quote_value? = Keyword.get(opts, :quote_value?, true)
      value = if quote_value?, do: "\"#{value}\"", else: value
      prefix = Keyword.get(opts, :prefix)
      path = if(prefix, do: [prefix | path], else: path) |> replace_in_path

      imports = [List.first(path) | imports]

      {EEx.eval_file("lib/templates/path.eex",
         path: path,
         key: key,
         value: value
       ), imports}
    end
  end

  defp translate_list_item(_path, key, value, _imports)
       when key in @as_object and is_map(value),
       do: {Enum.map(value, fn {k, v} -> ~s({"#{k}": "#{v}"}) end) |> Enum.join(" +\n"), []}

  defp translate_list_item(path, key, value, imports)
       when is_map(value),
       do: translate_path(path, key, value, imports)

  defp translate_list_item(_path, _key, value, _imports)
       when is_binary(value),
       do: {"\"#{value}\"", []}

  defp translate_list_item(_path, _key, value, _imports),
    do: {value, []}

  defp translate_object(path, key, value, imports, opts) do
    values = Enum.map(value, fn {k, v} -> ~s({"#{k}": "#{v}"}) end) |> Enum.join(" +\n")

    translate_path(
      path,
      key,
      "[#{values}]",
      imports,
      Keyword.put(opts, :quote_value?, false)
    )
  end

  def reduce_outputs(outputs, joiner \\ "+") do
    outputs
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce({"", []}, fn {file, imports}, {acc_file, acc_imports} = acc ->
      case [file, acc_file] do
        ["", _] ->
          acc

        [_, ""] ->
          {file, [imports | acc_imports] |> List.flatten() |> Enum.uniq()}

        file ->
          {Enum.join(file, " #{joiner}\n"),
           [imports | acc_imports] |> List.flatten() |> Enum.uniq()}
      end
    end)
  end

  defp replace_in_path(path) do
    if Enum.any?(path, &(&1 in Map.keys(@as_import))) do
      path = Enum.map(path, &Map.get(@as_import, &1, &1))

      first =
        path
        |> Enum.reverse()
        |> Enum.drop_while(fn v -> v not in Map.values(@as_import) end)
        |> List.first()

      rest =
        path
        |> Enum.reverse()
        |> Enum.take_while(fn v -> v not in Map.values(@as_import) end)
        |> Enum.reverse()

      [first | rest]
    else
      path
    end
  end
end
