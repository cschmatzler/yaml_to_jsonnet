defmodule YamlToJsonnet.Path do
  @ignored_paths [
    ~w(apiVersion),
    ~w(kind),
    ~w(metadata name)
  ]

  # Format:
  # `reference => {import_name, import_path}`
  # These includes both top-level imports (such as `deployment`, `daemonSet`) and lower-level imports (such as
  # `container`). For-lower level imports, the reference inside the path will be replaced with the import (see
  # `replace_with_imports/1`), for top-level imports, the `reference` will be the same as the `import_name`.
  @as_import %{
    "affinity" => {"affinity", "k.core.v1.affinity"},
    "clusterRole" => {"clusterRole", "k.rbac.v1.clusterRole"},
    "clusterRoleBinding" => {"clusterRoleBinding", "k.rbac.v1.clusterRoleBinding"},
    "containers" => {"container", "k.core.v1.container"},
    "csiDriver" => {"csiDriver", "k.storage.v1.csiDriver"},
    "initContainers" => {"container", "k.core.v1.container"},
    "env" => {"envVar", "k.core.v1.envVar"},
    "envFrom" => {"envVarSource", "k.core.v1.envVarSource"},
    "nodeSelectorTerms" => {"nodeSelectorTerm", "k.core.v1.nodeSelectorTerm"},
    "ports" => {"containerPort", "k.core.v1.containerPort"},
    "rules" => {"policyRule", "k.rbac.v1.policyRule"},
    "secretRef" => {"secretReference", "k.core.v1.secretReference"},
    "subjects" => {"subject", "k.rbac.v1.subject"},
    "tolerations" => {"toleration", "k.core.v1.toleration"},
    "volumeMounts" => {"volumeMount", "k.core.v1.volumeMount"},
    "volumes" => {"volume", "k.core.v1.volume"}
  }
  @as_object [
    "labels",
    "annotations",
    "imagePullSecrets",
    "matchExpressions"
  ]

  def as_import, do: @as_import

  def translate_path(path, key, value, imports \\ [], opts \\ [])

  # Custom
  # ------

  # Since `emptyDir` is defined with `{}`, this would get swallowed as an empty value otherwise.
  def translate_path(_path, "emptyDir", %{}, _imports, _opts) do
    {"{emptyDir: {}}", []}
  end

  # Generic
  # -------

  # Some paths, such as labels and annotations, need to be passed as objects instead of traversing into them.
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
    # Translate each list item individually, then pass them into the rest of the output as comma-separated array.
    {values, imports} =
      Enum.map(value, &translate_list_item(path, key, &1, imports))
      |> reduce_outputs(",")

    translate_path(path, key, "[#{values}]", imports, Keyword.put(opts, :quote_value?, false))
  end

  def translate_path(path, key, value, imports, opts) do
    unless Enum.any?(@ignored_paths, &List.starts_with?(path ++ [key], &1)) do
      quote_value? = Keyword.get(opts, :quote_value?, true)
      value = if quote_value?, do: "\"#{value}\"", else: value
      prefix = Keyword.get(opts, :prefix)
      path = if(prefix, do: [prefix | path], else: path) |> replace_with_imports

      imports = [List.first(path) | imports]

      {EEx.eval_file("lib/templates/path.eex",
         path: path,
         key: key,
         value: value
       ), imports}
    end
  end

  # Create a basic JSON object.
  # Note that we are wrapping the key in quotes. This is not necessarily required by Jsonnet, but since this might
  # include labels with non-alphanumerical characters (such as `app.kubernetes.io/name`), it is safer to wrap it.
  defp translate_list_item(path, key, value, imports)
       when key in @as_object and is_map(value),
       do: translate_object(path, key, value, imports, quote_value?: false)

  defp translate_list_item(path, key, value, imports)
       when is_map(value),
       do: translate_path(path, key, value, imports)

  defp translate_list_item(_path, _key, value, _imports)
       when is_binary(value),
       do: {"\"#{value}\"", []}

  defp translate_object(path, key, value, imports, opts) do
    values = Enum.map(value, fn {k, v} -> ~s({"#{k}": "#{v}"}) end) |> Enum.join(" +\n")

    translate_path(path, key, "[#{values}]", imports, Keyword.put(opts, :quote_value?, false))
  end

  def reduce_outputs(outputs, joiner \\ "+") do
    outputs
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce({"", []}, fn {output, imports}, {acc_output, acc_imports} = acc ->
      case [output, acc_output] do
        # When the output is empty, move on and just return the accumulator.
        ["", _] ->
          acc

        # When we have an output but the accumulator is empty, just return the output.
        # If we joined in this case, we would end up with `someFunction() + ""`, which is incorrect Jsonnet since an
        # object cannot be composed with a string.
        [_, ""] ->
          {output, flat_uniq([imports | acc_imports])}

        # Join our output together with what existed before, and accumulate imports.
        output ->
          output = output |> Enum.reverse() |> Enum.join(" #{joiner}\n")
          {output, flat_uniq([imports | acc_imports])}
      end
    end)
  end

  defp flat_uniq(list), do: list |> List.flatten() |> Enum.uniq()

  defp replace_with_imports(path) do
    # Only take the `reference -> import_name`. We don't care about import paths in this step.
    as_import = Enum.map(@as_import, fn {key, {name, _path}} -> {key, name} end) |> Map.new()

    # Check if we need to replace anything.
    if Enum.any?(path, &(&1 in Map.keys(as_import))) do
      path = Enum.map(path, &Map.get(as_import, &1, &1))

      # Get the *last* reference in our path that was replaced.
      # For example, in a `containers.envFrom.secretRef` path, we have three separate parts that are references,
      # but we only need the `secretRef` import.
      first =
        path
        |> Enum.reverse()
        |> Enum.drop_while(fn v -> v not in Map.values(as_import) end)
        |> List.first()

      # Get all path parts that are after the replaced reference.
      rest =
        path
        |> Enum.reverse()
        |> Enum.take_while(fn v -> v not in Map.values(as_import) end)
        |> Enum.reverse()

      [first | rest]
    else
      path
    end
  end
end
