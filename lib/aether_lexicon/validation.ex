defmodule AetherLexicon.Validation do
  @moduledoc """
  Validation module for ATProto lexicon schemas.

  This module provides functionality to validate data against lexicon schemas,
  matching the behavior of the official JavaScript implementation.
  """

  alias AetherLexicon.Validation.Formats

  @type validation_result :: {:ok, any()} | {:error, String.t()}

  @doc """
  Validates data against a lexicon schema definition.

  ## Parameters
    - schema: The loaded schema map containing all definitions
    - def_name: The name of the definition within the schema (e.g., "label", "selfLabel")
    - data: The data to validate

  ## Returns
    - `{:ok, validated_data}` - Data is valid (may include applied defaults)
    - `{:error, error_message}` - Data is invalid with error details
  """
  def validate(schema, def_name, data) do
    case get_definition(schema, def_name) do
      {:ok, definition} ->
        validate_with_definition(schema, definition, data, def_name)

      {:error, _} = error ->
        error
    end
  end

  # Get a specific definition from the schema
  defp get_definition(schema, def_name) do
    case schema do
      %{"defs" => defs} when is_map(defs) ->
        case Map.get(defs, def_name) do
          nil -> {:error, "Definition '#{def_name}' not found in schema"}
          definition -> {:ok, definition}
        end

      _ ->
        {:error, "Invalid schema: missing 'defs' field"}
    end
  end

  # Validate data against a specific definition
  defp validate_with_definition(schema, definition, data, path) do
    validate_one_of(schema, path, definition, data)
  end

  # Main validator that handles all types
  defp validate_one_of(schema, path, definition, value)

  # Handle union types
  defp validate_one_of(schema, path, %{"type" => "union"} = def, value) do
    unless is_map(value) and Map.has_key?(value, "$type") do
      {:error, "#{path} must be an object which includes the \"$type\" property"}
    else

      type_value = value["$type"]

      if refs_contain_type?(def["refs"], type_value) do
        # Type is in the union, validate against it
        concrete_def = get_def_from_schema(schema, type_value)

        case concrete_def do
          {:ok, def_to_validate} ->
            validate_one_of(schema, path, def_to_validate, value)

          {:error, _} = error ->
            error
        end
      else
        # Type not in union
        if def["closed"] do
          {:error, "#{path} $type must be one of #{Enum.join(def["refs"], ", ")}"}
        else
          # Open union - allow unknown types
          {:ok, value}
        end
      end
    end
  end

  # Handle ref types
  defp validate_one_of(schema, path, %{"type" => "ref", "ref" => ref}, value) do
    case get_def_from_schema(schema, ref) do
      {:ok, concrete_def} ->
        validate_one_of(schema, path, concrete_def, value)

      {:error, _} = error ->
        error
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
    # Check length constraints
    with :ok <- validate_array_length(definition, value, path) do
      # Validate each item
      items_def = Map.get(definition, "items")

      if items_def do
        value
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, value}, fn {item, index}, {:ok, _acc} ->
          item_path = "#{path}/#{index}"

          case validate_one_of(schema, item_path, items_def, item) do
            {:ok, _validated} -> {:cont, {:ok, value}}
            {:error, _} = error -> {:halt, error}
          end
        end)
      else
        {:ok, value}
      end
    end
  end

  defp validate_array(_schema, path, _definition, value) do
    {:error, "#{path} must be an array, got #{inspect(value)}"}
  end

  defp validate_array_length(definition, value, path) do
    max_length = definition["maxLength"]
    min_length = definition["minLength"]
    length = length(value)

    cond do
      max_length && length > max_length ->
        {:error, "#{path} must not have more than #{max_length} elements"}

      min_length && length < min_length ->
        {:error, "#{path} must not have fewer than #{min_length} elements"}

      true ->
        :ok
    end
  end

  # String validation
  defp validate_string(path, definition, value) when is_binary(value) do
    with :ok <- validate_string_const(definition, value, path),
         :ok <- validate_string_enum(definition, value, path),
         :ok <- validate_string_length(definition, value, path),
         :ok <- validate_string_graphemes(definition, value, path),
         {:ok, _} <- validate_string_format(definition, value, path) do
      {:ok, value}
    end
  end

  defp validate_string(path, definition, nil) do
    case definition["default"] do
      nil -> {:error, "#{path} must be a string"}
      default when is_binary(default) -> {:ok, default}
      _ -> {:error, "#{path} must be a string"}
    end
  end

  defp validate_string(path, _definition, value) do
    {:error, "#{path} must be a string, got #{inspect(value)}"}
  end

  defp validate_string_const(definition, value, path) do
    case definition["const"] do
      nil -> :ok
      const when const == value -> :ok
      const -> {:error, "#{path} must be #{const}"}
    end
  end

  defp validate_string_enum(definition, value, path) do
    case definition["enum"] do
      nil ->
        :ok

      enum when is_list(enum) ->
        if value in enum do
          :ok
        else
          {:error, "#{path} must be one of (#{Enum.join(enum, "|")})"}
        end

      _ ->
        :ok
    end
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

  defp validate_string_format(definition, value, path) do
    case definition["format"] do
      nil -> {:ok, value}
      format -> Formats.validate_format(format, value, path)
    end
  end

  # Integer validation
  defp validate_integer(path, definition, value) when is_integer(value) do
    with :ok <- validate_integer_const(definition, value, path),
         :ok <- validate_integer_enum(definition, value, path),
         :ok <- validate_integer_range(definition, value, path) do
      {:ok, value}
    end
  end

  defp validate_integer(path, definition, nil) do
    case definition["default"] do
      nil -> {:error, "#{path} must be an integer"}
      default when is_integer(default) -> {:ok, default}
      _ -> {:error, "#{path} must be an integer"}
    end
  end

  defp validate_integer(path, _definition, value) do
    {:error, "#{path} must be an integer, got #{inspect(value)}"}
  end

  defp validate_integer_const(definition, value, path) do
    case definition["const"] do
      nil -> :ok
      const when const == value -> :ok
      const -> {:error, "#{path} must be #{const}"}
    end
  end

  defp validate_integer_enum(definition, value, path) do
    case definition["enum"] do
      nil ->
        :ok

      enum when is_list(enum) ->
        if value in enum do
          :ok
        else
          {:error, "#{path} must be one of (#{Enum.join(enum, "|")})"}
        end

      _ ->
        :ok
    end
  end

  defp validate_integer_range(definition, value, path) do
    max = definition["maximum"]
    min = definition["minimum"]

    cond do
      max && value > max ->
        {:error, "#{path} can not be greater than #{max}"}

      min && value < min ->
        {:error, "#{path} can not be less than #{min}"}

      true ->
        :ok
    end
  end

  # Boolean validation
  defp validate_boolean(path, definition, value) when is_boolean(value) do
    case definition["const"] do
      nil -> {:ok, value}
      const when const == value -> {:ok, value}
      const -> {:error, "#{path} must be #{const}"}
    end
  end

  defp validate_boolean(path, definition, nil) do
    case definition["default"] do
      nil -> {:error, "#{path} must be a boolean"}
      default when is_boolean(default) -> {:ok, default}
      _ -> {:error, "#{path} must be a boolean"}
    end
  end

  defp validate_boolean(path, _definition, value) do
    {:error, "#{path} must be a boolean, got #{inspect(value)}"}
  end

  # Bytes validation
  defp validate_bytes(path, definition, value) when is_binary(value) do
    byte_length = byte_size(value)
    max_length = definition["maxLength"]
    min_length = definition["minLength"]

    cond do
      max_length && byte_length > max_length ->
        {:error, "#{path} must not be larger than #{max_length} bytes"}

      min_length && byte_length < min_length ->
        {:error, "#{path} must not be smaller than #{min_length} bytes"}

      true ->
        {:ok, value}
    end
  end

  defp validate_bytes(path, _definition, value) do
    {:error, "#{path} must be a byte array, got #{inspect(value)}"}
  end

  # CID Link validation - basic check for now
  defp validate_cid_link(path, value) when is_binary(value) do
    # Basic CID format check - starts with b or Q (CIDv0/v1)
    if String.match?(value, ~r/^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{58,})/) do
      {:ok, value}
    else
      {:error, "#{path} must be a CID"}
    end
  end

  defp validate_cid_link(path, _value) do
    {:error, "#{path} must be a CID"}
  end

  # Unknown type - accepts any object
  defp validate_unknown(_path, value) when is_map(value) do
    {:ok, value}
  end

  defp validate_unknown(path, _value) do
    {:error, "#{path} must be an object"}
  end

  # Blob validation - expects a map with blob structure
  defp validate_blob(path, value) when is_map(value) do
    # In JSON representation, blobs have $type, ref, mimeType, size
    cond do
      Map.has_key?(value, "$type") and value["$type"] == "blob" ->
        {:ok, value}

      Map.has_key?(value, "ref") and Map.has_key?(value, "mimeType") ->
        {:ok, value}

      true ->
        {:error, "#{path} should be a blob ref"}
    end
  end

  defp validate_blob(path, _value) do
    {:error, "#{path} should be a blob ref"}
  end

  # Token validation - essentially an empty marker
  defp validate_token(_path, _value) do
    {:ok, nil}
  end

  # Record validation - validates the record.record field
  defp validate_record(schema, path, definition, value) do
    case definition["record"] do
      record_def when is_map(record_def) ->
        validate_object(schema, path, record_def, value)

      _ ->
        {:error, "Invalid record definition at #{path}"}
    end
  end

  # Helper: Get default value from definition
  defp get_default_value(definition) do
    case {definition["type"], definition["default"]} do
      {"string", default} when is_binary(default) -> default
      {"integer", default} when is_integer(default) -> default
      {"boolean", default} when is_boolean(default) -> default
      _ -> nil
    end
  end

  # Helper: Check if refs contain a type (with implicit #main handling)
  defp refs_contain_type?(refs, type) do
    lex_uri = to_lex_uri(type)

    cond do
      lex_uri in refs ->
        true

      String.ends_with?(lex_uri, "#main") ->
        base = String.slice(lex_uri, 0..-6//1)
        base in refs

      not String.contains?(lex_uri, "#") ->
        "#{lex_uri}#main" in refs

      true ->
        false
    end
  end

  # Helper: Convert to lex URI format
  defp to_lex_uri(str) when is_binary(str) do
    cond do
      String.starts_with?(str, "lex:") -> str
      String.starts_with?(str, "#") -> str
      true -> "lex:#{str}"
    end
  end

  # Helper: Get definition from schema by ref
  defp get_def_from_schema(schema, ref) when is_binary(ref) do
    # Handle local refs like "#selfLabel" or full refs like "com.atproto.label.defs#selfLabels"
    cond do
      String.starts_with?(ref, "#") ->
        # Local reference
        def_name = String.trim_leading(ref, "#")
        get_definition(schema, def_name)

      String.contains?(ref, "#") ->
        # Cross-schema reference - for now, just try to extract the def name
        # Full implementation would need a lexicon collection
        [_schema_id, def_name] = String.split(ref, "#", parts: 2)
        get_definition(schema, def_name)

      true ->
        # Implicit #main
        get_definition(schema, "main")
    end
  end
end
