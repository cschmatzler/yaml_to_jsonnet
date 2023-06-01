defmodule YamlToJsonnet.Path do
  def translate_path(path, key, value, ignored_keys, replacements, opts \\ [])

  def translate_path(path, key, value, ignored_keys, replacements, opts) when is_map(value) do
    Enum.map(value, fn {k, v} ->
      translate_path(path ++ [key], k, v, ignored_keys, replacements, opts)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&String.equivalent?(&1, ""))
    |> Enum.join(" +\n")
  end

  def translate_path(path, key, value, ignored_keys, replacements, opts) when is_list(value) do
    values = Enum.map(value, &translate_list_item(path, key, &1, ignored_keys, replacements))

    translate_path(
      path,
      key,
      "[#{Enum.join(values, ", ")}]",
      ignored_keys,
      replacements,
      Keyword.put(opts, :quote_value?, false)
    )
  end

  def translate_path(path, key, value, ignored_keys, replacements, opts) do
    unless Enum.any?(ignored_keys, &List.starts_with?(path ++ [key], &1)) do
      quote_value? = Keyword.get(opts, :quote_value?, true)
      value = if quote_value?, do: "\"#{value}\"", else: value
      prefix = Keyword.get(opts, :prefix)
      path = if prefix, do: [prefix | path], else: path

      EEx.eval_file("lib/translator/generic.eex",
        path: replace_in_path(path, replacements),
        key: key,
        value: value
      )
    end
  end

  def translate_list_item(path, key, value, ignored_keys, replacements) when is_map(value),
    do: translate_path(path, key, value, ignored_keys, replacements)

  def translate_list_item(_path, _key, value, _ignored_keys, _replacements) when is_binary(value),
    do: "\"#{value}\""

  def translate_list_item(_path, _key, value, _ignored_keys, _replacements), do: value

  def replace_in_path(path, replacements) do
    if Enum.any?(path, &(&1 in Map.keys(replacements))) do
      Enum.map(path, &Map.get(replacements, &1, &1))
      |> Enum.drop_while(fn v -> v not in Map.values(replacements) end)
    else
      path
    end
  end
end
