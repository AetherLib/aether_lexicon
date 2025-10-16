defmodule AetherLexicon.Validation do
  @moduledoc """
  Validates data against ATProto lexicon schemas.

  This module provides comprehensive validation for ATProto lexicon schemas,
  supporting all lexicon types including objects, arrays, strings, integers,
  booleans, refs, unions, and more.

  The implementation matches the behavior of the official JavaScript implementation,
  ensuring compatibility with the ATProto specification.

  ## Supported Types

    * `:object` - Structured data with properties, required fields, and defaults
    * `:array` - Lists with optional item type constraints
    * `:string` - Text with length, format, and pattern validation
    * `:integer` - Numeric values with range constraints
    * `:boolean` - True/false values
    * `:bytes` - Binary data with size constraints
    * `:ref` - References to other definitions
    * `:union` - One of several possible types
    * `:cid-link` - Content identifiers
    * `:blob` - Binary large objects
    * `:token` - Authentication tokens
    * `:record` - Record types
    * `:unknown` - Untyped data

  ## Examples

      # Load a schema
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.post",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "required" => ["text"],
            "properties" => %{
              "text" => %{"type" => "string", "maxLength" => 300},
              "createdAt" => %{"type" => "string", "format" => "datetime"}
            }
          }
        }
      }

      # Valid data
      AetherLexicon.Validation.validate(schema, "main", %{
        "text" => "Hello world!",
        "createdAt" => "2024-01-01T00:00:00Z"
      })
      #=> {:ok, %{"text" => "Hello world!", "createdAt" => "2024-01-01T00:00:00Z"}}

      # Invalid data (missing required field)
      AetherLexicon.Validation.validate(schema, "main", %{})
      #=> {:error, "main must have the property \\"text\\""}

      # Invalid data (string too long)
      long_text = String.duplicate("a", 301)
      AetherLexicon.Validation.validate(schema, "main", %{"text" => long_text})
      #=> {:error, "main/text must not be longer than 300 characters"}
  """

  alias AetherLexicon.Validation.Formats
  alias AetherLexicon.Validation.Validators

  @type validation_result :: {:ok, any()} | {:error, String.t()}

  @doc """
  Validates data against a lexicon schema definition.

  Takes a schema map, a definition name, and data to validate. Returns the
  validated data (potentially with defaults applied) or an error message.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.label",
        "defs" => %{
          "label" => %{
            "type" => "object",
            "required" => ["val"],
            "properties" => %{
              "val" => %{"type" => "string"}
            }
          }
        }
      }

      validate(schema, "label", %{"val" => "test"})
      #=> {:ok, %{"val" => "test"}}

      validate(schema, "label", %{})
      #=> {:error, "label must have the property \\"val\\""}

      validate(schema, "nonexistent", %{})
      #=> {:error, "Definition 'nonexistent' not found in schema"}
  """
  @spec validate(map(), String.t(), any()) :: validation_result()
  def validate(schema, def_name, data) do
    case get_definition(schema, def_name) do
      {:ok, definition} ->
        validate_with_definition(schema, definition, data, def_name)

      {:error, _} = error ->
        error
    end
  end

  # Get a specific definition from the schema
  defp get_definition(%{"defs" => defs}, def_name) when is_map(defs) do
    case Map.fetch(defs, def_name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, "Definition '#{def_name}' not found in schema"}
    end
  end

  defp get_definition(_schema, _def_name) do
    {:error, "Invalid schema: missing 'defs' field"}
  end

  # Validate data against a specific definition
  defp validate_with_definition(schema, definition, data, path) do
    validate_one_of(schema, path, definition, data)
  end

  # Main validator that handles all types
  defp validate_one_of(schema, path, definition, value)

  # Handle union types
  defp validate_one_of(schema, path, %{"type" => "union"} = definition, value)
       when is_map(value) and is_map_key(value, "$type") do
    type_value = value["$type"]
    refs = definition["refs"]

    if refs_contain_type?(refs, type_value) do
      with {:ok, concrete_def} <- get_def_from_schema(schema, type_value) do
        validate_one_of(schema, path, concrete_def, value)
      end
    else
      if definition["closed"] do
        {:error, "#{path} $type must be one of #{Enum.join(refs, ", ")}"}
      else
        {:ok, value}
      end
    end
  end

  defp validate_one_of(_schema, path, %{"type" => "union"}, _value) do
    {:error, "#{path} must be an object which includes the \"$type\" property"}
  end

  # Handle ref types
  defp validate_one_of(schema, path, %{"type" => "ref", "ref" => ref}, value) do
    with {:ok, concrete_def} <- get_def_from_schema(schema, ref) do
      validate_one_of(schema, path, concrete_def, value)
    end
  end

  # Handle all other types
  defp validate_one_of(schema, path, definition, value) do
    validate_by_type(schema, path, definition, value)
  end

  # Route to appropriate validator based on type
  defp validate_by_type(schema, path, definition, value) do
    case definition["type"] do
      "object" -> validate_object(schema, path, definition, value)
      "array" -> validate_array(schema, path, definition, value)
      "string" -> validate_string(path, definition, value)
      "integer" -> validate_integer(path, definition, value)
      "boolean" -> validate_boolean(path, definition, value)
      "bytes" -> validate_bytes(path, definition, value)
      "cid-link" -> validate_cid_link(path, value)
      "unknown" -> validate_unknown(path, value)
      "blob" -> validate_blob(path, value)
      "token" -> validate_token(path, value)
      "record" -> validate_record(schema, path, definition, value)
      type -> {:error, "Unsupported type '#{type}' at #{path}"}
    end
  end

  # Object validation
  defp validate_object(schema, path, definition, value) when is_map(value) do
    properties = Map.get(definition, "properties", %{})
    required = Map.get(definition, "required", [])
    nullable = Map.get(definition, "nullable", [])

    result_value = value

    # Validate each property
    result =
      Enum.reduce_while(properties, {:ok, result_value}, fn {key, prop_def}, {:ok, acc_value} ->
        key_value = Map.get(value, key)
        is_required = key in required
        is_nullable = key in nullable

        cond do
          # Null value for nullable field
          is_nil(key_value) and is_nullable ->
            {:cont, {:ok, acc_value}}

          # Undefined value for non-required field
          is_nil(key_value) and not is_required ->
            # Check for default values
            case get_default_value(prop_def) do
              nil ->
                {:cont, {:ok, acc_value}}

              default ->
                new_acc = Map.put(acc_value, key, default)
                {:cont, {:ok, new_acc}}
            end

          # Value needs validation
          true ->
            prop_path = "#{path}/#{key}"

            case validate_one_of(schema, prop_path, prop_def, key_value) do
              {:ok, validated_value} ->
                # Update value if it changed (e.g., defaults applied)
                new_acc =
                  if validated_value != key_value do
                    Map.put(acc_value, key, validated_value)
                  else
                    acc_value
                  end

                {:cont, {:ok, new_acc}}

              {:error, _} = error ->
                # Check if it's a required field error
                if is_nil(key_value) and is_required do
                  {:halt, {:error, "#{path} must have the property \"#{key}\""}}
                else
                  {:halt, error}
                end
            end
        end
      end)

    result
  end

  defp validate_object(_schema, path, _definition, value) do
    {:error, "Expected object at #{path}, got #{inspect(value)}"}
  end

  # Array validation
  defp validate_array(schema, path, definition, value) when is_list(value) do
    with :ok <- Validators.validate_length(value,
                  [min_length: definition["minLength"], max_length: definition["maxLength"]],
                  path, "elements"),
         {:ok, _} <- validate_array_items(schema, path, definition, value) do
      {:ok, value}
    end
  end

  defp validate_array(_schema, path, _definition, value) do
    {:error, "#{path} must be an array, got #{inspect(value)}"}
  end

  defp validate_array_items(schema, path, definition, value) do
    case Map.get(definition, "items") do
      nil ->
        {:ok, value}

      items_def ->
        value
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, value}, fn {item, index}, {:ok, _acc} ->
          item_path = "#{path}/#{index}"

          case validate_one_of(schema, item_path, items_def, item) do
            {:ok, _validated} -> {:cont, {:ok, value}}
            {:error, _} = error -> {:halt, error}
          end
        end)
    end
  end

  # String validation
  defp validate_string(path, definition, value) when is_binary(value) do
    with :ok <- Validators.validate_const(value, definition["const"], path),
         :ok <- Validators.validate_enum(value, definition["enum"], path),
         :ok <- validate_string_length(definition, value, path),
         :ok <- validate_string_graphemes(definition, value, path),
         {:ok, _} <- validate_string_format(definition, value, path) do
      {:ok, value}
    end
  end

  defp validate_string(path, definition, nil) do
    case Validators.get_default("string", definition["default"]) do
      nil -> {:error, "#{path} must be a string"}
      default -> {:ok, default}
    end
  end

  defp validate_string(path, _definition, value) do
    {:error, "#{path} must be a string, got #{inspect(value)}"}
  end

  # String byte length validation (UTF-8 optimized like official implementation)
  defp validate_string_length(definition, value, path) do
    min_length = definition["minLength"]
    max_length = definition["maxLength"]

    if min_length || max_length do
      # Optimization: JS string length * 3 is upper bound for UTF-8 byte length
      string_length = String.length(value)

      cond do
        min_length && string_length * 3 < min_length ->
          {:error, "#{path} must not be shorter than #{min_length} characters"}

        max_length && min_length == nil && string_length * 3 <= max_length ->
          # Can skip UTF-8 byte count
          :ok

        true ->
          # Need to count actual UTF-8 bytes
          byte_length = byte_size(value)

          cond do
            max_length && byte_length > max_length ->
              {:error, "#{path} must not be longer than #{max_length} characters"}

            min_length && byte_length < min_length ->
              {:error, "#{path} must not be shorter than #{min_length} characters"}

            true ->
              :ok
          end
      end
    else
      :ok
    end
  end

  # String grapheme validation
  defp validate_string_graphemes(definition, value, path) do
    min_graphemes = definition["minGraphemes"]
    max_graphemes = definition["maxGraphemes"]

    if min_graphemes || max_graphemes do
      # In Elixir, String.length/1 returns grapheme count (not code units like JavaScript)
      grapheme_length = String.length(value)

      cond do
        max_graphemes && grapheme_length > max_graphemes ->
          {:error, "#{path} must not be longer than #{max_graphemes} graphemes"}

        min_graphemes && grapheme_length < min_graphemes ->
          {:error, "#{path} must not be shorter than #{min_graphemes} graphemes"}

        true ->
          :ok
      end
    else
      :ok
    end
  end

  defp validate_string_format(%{"format" => format}, value, path),
    do: Formats.validate_format(format, value, path)

  defp validate_string_format(_definition, value, _path), do: {:ok, value}

  # Integer validation
  defp validate_integer(path, definition, value) when is_integer(value) do
    with :ok <- Validators.validate_const(value, definition["const"], path),
         :ok <- Validators.validate_enum(value, definition["enum"], path),
         :ok <- Validators.validate_range(value,
                  [minimum: definition["minimum"], maximum: definition["maximum"]], path) do
      {:ok, value}
    end
  end

  defp validate_integer(path, definition, nil) do
    case Validators.get_default("integer", definition["default"]) do
      nil -> {:error, "#{path} must be an integer"}
      default -> {:ok, default}
    end
  end

  defp validate_integer(path, _definition, value) do
    {:error, "#{path} must be an integer, got #{inspect(value)}"}
  end

  # Boolean validation
  defp validate_boolean(path, definition, value) when is_boolean(value) do
    with :ok <- Validators.validate_const(value, definition["const"], path) do
      {:ok, value}
    end
  end

  defp validate_boolean(path, definition, nil) do
    case Validators.get_default("boolean", definition["default"]) do
      nil -> {:error, "#{path} must be a boolean"}
      default -> {:ok, default}
    end
  end

  defp validate_boolean(path, _definition, value) do
    {:error, "#{path} must be a boolean, got #{inspect(value)}"}
  end

  # Bytes validation
  defp validate_bytes(path, definition, value) when is_binary(value) do
    with :ok <- Validators.validate_length(value,
                  [min_length: definition["minLength"], max_length: definition["maxLength"]],
                  path, "bytes") do
      {:ok, value}
    end
  end

  defp validate_bytes(path, _definition, value) do
    {:error, "#{path} must be a byte array, got #{inspect(value)}"}
  end

  # CID Link validation
  @cid_regex ~r/^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{58,})/

  defp validate_cid_link(path, value) when is_binary(value) do
    if String.match?(value, @cid_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a CID"}
    end
  end

  defp validate_cid_link(path, _value), do: {:error, "#{path} must be a CID"}

  # Unknown type - accepts any object
  defp validate_unknown(_path, value) when is_map(value) do
    {:ok, value}
  end

  defp validate_unknown(path, _value) do
    {:error, "#{path} must be an object"}
  end

  # Blob validation - expects a map with blob structure
  defp validate_blob(_path, %{"$type" => "blob"} = value), do: {:ok, value}

  defp validate_blob(path, value) when is_map(value) do
    if Map.has_key?(value, "ref") and Map.has_key?(value, "mimeType") do
      {:ok, value}
    else
      {:error, "#{path} should be a blob ref"}
    end
  end

  defp validate_blob(path, _value), do: {:error, "#{path} should be a blob ref"}

  # Token validation - essentially an empty marker
  defp validate_token(_path, _value) do
    {:ok, nil}
  end

  # Record validation
  defp validate_record(schema, path, %{"record" => record_def}, value) when is_map(record_def),
    do: validate_object(schema, path, record_def, value)

  defp validate_record(_schema, path, _definition, _value),
    do: {:error, "Invalid record definition at #{path}"}

  # Helper: Get default value from definition
  defp get_default_value(%{"type" => type, "default" => default}),
    do: Validators.get_default(type, default)

  defp get_default_value(_definition), do: nil

  # Helper: Check if refs contain a type (with implicit #main handling)
  defp refs_contain_type?(refs, type) do
    lex_uri = to_lex_uri(type)

    lex_uri in refs or
      (String.ends_with?(lex_uri, "#main") and String.slice(lex_uri, 0..-6//1) in refs) or
      (not String.contains?(lex_uri, "#") and "#{lex_uri}#main" in refs)
  end

  # Helper: Convert to lex URI format
  defp to_lex_uri("lex:" <> _ = str), do: str
  defp to_lex_uri("#" <> _ = str), do: str
  defp to_lex_uri(str), do: "lex:#{str}"

  # Helper: Get definition from schema by ref
  defp get_def_from_schema(schema, "#" <> def_name) do
    get_definition(schema, def_name)
  end

  defp get_def_from_schema(schema, ref) when is_binary(ref) do
    if String.contains?(ref, "#") do
      [_schema_id, def_name] = String.split(ref, "#", parts: 2)
      get_definition(schema, def_name)
    else
      get_definition(schema, "main")
    end
  end
end
