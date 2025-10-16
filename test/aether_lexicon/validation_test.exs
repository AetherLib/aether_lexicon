defmodule AetherLexicon.ValidationTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

  # Helper function to load schema from JSON file
  defp load_schema(path) do
    case File.read(path) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, schema} -> {:ok, schema}
          {:error, error} -> {:error, "Failed to parse JSON: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # Get all lexicon files at compile time
  @lexicon_files "priv/spec"
                 |> Path.join("**/*.json")
                 |> Path.wildcard()
                 |> Enum.sort()

  describe "all lexicon schemas" do
    for lexicon_path <- @lexicon_files do
      @lexicon_path lexicon_path
      # Extract a readable test name from the path
      test_name =
        lexicon_path
        |> Path.relative_to("priv/spec/")
        |> Path.rootname()
        |> String.replace("/", ".")

      test "loads and validates schema: #{test_name}" do
        assert {:ok, schema} = load_schema(@lexicon_path)

        # Verify basic lexicon structure
        assert schema["lexicon"] == 1, "Expected lexicon version 1 in #{@lexicon_path}"
        assert is_binary(schema["id"]), "Expected id to be a string in #{@lexicon_path}"
        assert is_map(schema["defs"]), "Expected defs to be a map in #{@lexicon_path}"
        assert map_size(schema["defs"]) > 0, "Expected at least one definition in #{@lexicon_path}"
      end
    end

    test "found all expected lexicon files" do
      # Verify we're loading a reasonable number of schemas
      assert length(@lexicon_files) > 0, "No lexicon files found in priv/spec"
      assert length(@lexicon_files) > 100, "Expected to find many lexicon files, found #{length(@lexicon_files)}"
    end
  end

  describe "schema loading helper" do
    test "returns error for non-existent schema file" do
      assert {:error, _reason} = load_schema("non_existent.json")
    end
  end

  describe "validate/3 - label object" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates a valid label object with all required fields", %{schema: schema} do
      valid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label",
        "cts" => "2024-01-15T10:30:00Z"
      }

      assert {:ok, _validated} = Validation.validate(schema, "label", valid_label)
    end

    test "rejects label object missing required fields", %{schema: schema} do
      # Missing 'cts' field
      invalid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label"
      }

      assert {:error, error} = Validation.validate(schema, "label", invalid_label)
      assert error =~ "must have the property"
      assert error =~ "cts"
    end

    test "validates optional fields when present", %{schema: schema} do
      label_with_optional = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => true,
        "ver" => 1
      }

      assert {:ok, _validated} = Validation.validate(schema, "label", label_with_optional)
    end

    test "validates string maxLength constraint", %{schema: schema} do
      # val field has maxLength: 128
      long_val = String.duplicate("a", 129)

      invalid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => long_val,
        "cts" => "2024-01-15T10:30:00Z"
      }

      assert {:error, error} = Validation.validate(schema, "label", invalid_label)
      assert error =~ "must not be longer than 128 characters"
    end
  end

  describe "validate/3 - selfLabel object" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates a valid selfLabel object", %{schema: schema} do
      valid_self_label = %{
        "val" => "content-warning"
      }

      assert {:ok, _validated} = Validation.validate(schema, "selfLabel", valid_self_label)
    end

    test "rejects selfLabel missing required val field", %{schema: schema} do
      invalid_self_label = %{}

      assert {:error, error} = Validation.validate(schema, "selfLabel", invalid_self_label)
      assert error =~ "must have the property"
      assert error =~ "val"
    end
  end

  describe "validate/3 - primitive types" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates boolean type for neg field", %{schema: schema} do
      label_with_bool = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => true
      }

      assert {:ok, _} = Validation.validate(schema, "label", label_with_bool)

      # Invalid boolean
      label_with_invalid_bool = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => "not a boolean"
      }

      assert {:error, error} = Validation.validate(schema, "label", label_with_invalid_bool)
      assert error =~ "boolean"
    end

    test "validates integer type for ver field", %{schema: schema} do
      label_with_int = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "ver" => 1
      }

      assert {:ok, _} = Validation.validate(schema, "label", label_with_int)

      # Invalid integer
      label_with_invalid_int = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "ver" => "not an integer"
      }

      assert {:error, error} = Validation.validate(schema, "label", label_with_invalid_int)
      assert error =~ "integer"
    end
  end
end
