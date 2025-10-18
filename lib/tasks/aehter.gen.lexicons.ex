# lib/mix/tasks/aether.gen.lexicons.ex
defmodule Mix.Tasks.Aether.Gen.Lexicons do
  use Mix.Task
  @shortdoc "Copies ATProto lexicon JSON schemas to your priv/lexicons folder"

  @moduledoc """
  Copies ATProto lexicon JSON files to your application's priv directory.

  ## Arguments

  You can specify namespace patterns to copy specific lexicons:

      mix aether.gen.lexicons "app.bsky.*"
      mix aether.gen.lexicons "app.bsky.actor.*" "com.atproto.*"

  If no arguments are provided, all lexicons will be copied.

  ## Examples

      # Copy all lexicons
      mix aether.gen.lexicons

      # Copy all app.bsky lexicons
      mix aether.gen.lexicons "app.bsky.*"

      # Copy multiple patterns
      mix aether.gen.lexicons "app.bsky.*" "com.atproto.identity.*"
  """

  @impl true
  def run(args) do
    Mix.shell().info("Copies ATProto lexicon JSON schemas to your priv/lexicons folder")

    source_dir = get_source_dir()

    target_dir = Path.join(File.cwd!(), "priv/lexicons")

    patterns = if args == [], do: ["**"], else: args
    dbg(patterns)

    copied_files = copy_lexicons(source_dir, target_dir, patterns)

    if copied_files == [] do
      Mix.shell().info("No files matched the provided patterns: #{inspect(patterns)}")
    else
      Mix.shell().info("Successfully copied #{length(copied_files)} lexicon files:")
      Enum.each(copied_files, &Mix.shell().info("  - #{&1}"))
    end
  end

  defp get_source_dir do
    %{aether_lexicon: aether_lexicon_path} = Mix.Project.deps_paths()

    Path.join(aether_lexicon_path, "priv/lexicons")
  end

  defp copy_lexicons(source_dir, target_dir, patterns) do
    # Get all JSON files from source directory
    all_files = Path.wildcard(Path.join(source_dir, "**/*.json"))

    # Filter files based on patterns
    matching_files = filter_files_by_patterns(all_files, patterns, source_dir)

    # Copy each matching file
    Enum.flat_map(matching_files, fn source_path ->
      relative_path = Path.relative_to(source_path, source_dir)
      target_path = Path.join(target_dir, relative_path)

      # Ensure target directory exists
      target_dir_path = Path.dirname(target_path)
      File.mkdir_p!(target_dir_path)

      case File.copy(source_path, target_path) do
        {:ok, _bytes} ->
          [relative_path]

        {:error, reason} ->
          Mix.shell().error("Failed to copy #{source_path}: #{reason}")
          []
      end
    end)
  end

  defp filter_files_by_patterns(files, patterns, source_dir) do
    Enum.filter(files, fn file_path ->
      relative_path = Path.relative_to(file_path, source_dir)

      namespace =
        relative_path
        |> String.replace(".json", "")
        |> String.replace("/", ".")

      Enum.any?(patterns, fn pattern ->
        matches_pattern?(namespace, pattern)
      end)
    end)
  end

  defp matches_pattern?(namespace, pattern) do
    regex_pattern =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("*", ".*")
      |> then(&"^#{&1}$")

    Regex.match?(Regex.compile!(regex_pattern), namespace)
  end
end
