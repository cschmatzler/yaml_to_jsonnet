defmodule Mix.Tasks.Translate do
  use Mix.Task

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [input: :string, output: :string],
        aliases: [i: :input, o: :output]
      )

    translate(opts)
    |> IO.puts()
  end

  defp translate(input: input) do
    Path.join(File.cwd!(), input)
    |> YamlElixir.read_all_from_file!()
    |> YamlToJsonnet.run()
    |> Enum.map(fn file ->
      file
      |> String.replace(~r/\n\s*\+/, " +")
      |> String.replace(~r/\n\s*,/, ",")
      |> String.replace(~r/^\s*/m, "")
    end)

    # TODO: write to file
  end

  defp translate(_), do: IO.puts("Input file is required")
end
