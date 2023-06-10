defmodule Mix.Tasks.Translate do
  use Mix.Task

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [input: :string, name: :string],
        aliases: [i: :input]
      )

    translate(opts)
  end

  defp translate(name: name,input: input) do
    Path.join(File.cwd!(), input)
    |> YamlElixir.read_all_from_file!()
    |> YamlToJsonnet.run(name)
    |> Enum.map(fn {path, content} ->
      content = content
      |> String.replace(~r/\n\s*\+/, " +")
      |> String.replace(~r/\n\s*,/, ",")
      |> String.replace(~r/^\s*/m, "")

      File.write!("out/#{path}", content)
    end)
  end

  defp translate(_), do: IO.puts("Input file is required")
end
