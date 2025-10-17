defmodule AetherLexicon.Validation do
  @moduledoc """
  Validates data against ATProto lexicon schemas.

  This module provides comprehensive validation for ATProto lexicon schemas,
  supporting all lexicon types including objects, arrays, strings, integers,
  booleans, refs, unions, and XRPC endpoints.

  The implementation matches the behavior of the official JavaScript implementation,
  ensuring compatibility with the ATProto specification.

  ## Supported Types

  ### Data Types

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
    * `:unknown` - Untyped data

  ### Lexicon Types

    * `:record` - Repository record schemas
    * `:token` - Authentication tokens
    * `:query` - XRPC read-only endpoints (GET)
    * `:procedure` - XRPC write endpoints (POST)
    * `:subscription` - XRPC streaming endpoints (WebSocket)

  ## XRPC Endpoint Validation

  For XRPC endpoint types (query, procedure, subscription), use the dedicated
  validation functions to validate different parts of the endpoint:

    * `validate_input/3` - Validates request body against input schema
    * `validate_output/3` - Validates response body against output schema
    * `validate_parameters/3` - Validates URL/query parameters
    * `validate_message/3` - Validates subscription message (WebSocket)
    * `validate_error/4` - Validates named error response

  The general `validate/3` function works for all schema types and defaults to
  validating input for XRPC endpoints.

  ## Examples

      # Validating a record
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

  @type validation_result :: {:ok, any()} | {:error, String.t()}

  # Format validation regex patterns (from Formats module)
  @iso8601_regex ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})?$/
  @uri_regex ~r/^\w+:(?:\/\/)?[^\s\/][^\s]*$/
  @at_uri_regex ~r/^at:\/\/[a-zA-Z0-9:._-]+\/[a-z][a-z0-9.-]*\.[a-z][a-z0-9.-]*[a-z]\/[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/
  @did_regex ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/
  @handle_regex ~r/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/
  @nsid_regex ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/
  @cid_format_regex ~r/^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{58,}|[a-z0-9]{59,})$/
  @language_regex ~r/^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2})?(-[a-zA-Z0-9]{5,8})*(-[a-zA-Z0-9]{1,8})*$/
  @tid_regex ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/
  @record_key_regex ~r/^[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/

  @doc """
  Validates data against a lexicon schema definition.

  Takes a schema map, a definition name, and data to validate. Returns the
  validated data (potentially with defaults applied) or an error message.

  This is the general-purpose validation function that works for all schema types.
  For XRPC endpoints, consider using the dedicated functions (`validate_input/3`,
  `validate_output/3`, etc.) for more explicit validation.

  ## Parameters

    * `schema` - The lexicon schema map
    * `def_name` - The definition name to validate against (e.g., "main", "label")
    * `data` - The data to validate

  ## Returns

    * `{:ok, validated_data}` - Validation succeeded, returns data with defaults applied
    * `{:error, message}` - Validation failed with an error message

  ## Examples

      # Validating a record schema
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

      # For XRPC endpoints, use dedicated functions:
      # validate_input/3, validate_output/3, validate_parameters/3, etc.
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

  @doc """
  Validates XRPC input data (request body) against a schema.

  For XRPC endpoints (query, procedure), this validates the data sent in the
  request body against the `input` schema definition.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.createPost",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["text"],
                "properties" => %{"text" => %{"type" => "string", "maxLength" => 300}}
              }
            }
          }
        }
      }

      validate_input(schema, "main", %{"text" => "Hello world!"})
      #=> {:ok, %{"text" => "Hello world!"}}
  """
  @spec validate_input(map(), String.t(), map()) :: validation_result()
  def validate_input(schema, def_name, data) when is_map(data) do
    validate(schema, def_name, Map.put(data, "$xrpc", "input"))
  end

  @doc """
  Validates XRPC output data (response body) against a schema.

  For XRPC endpoints (query, procedure), this validates the data returned in the
  response body against the `output` schema definition.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.getPost",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["post"],
                "properties" => %{"post" => %{"type" => "object"}}
              }
            }
          }
        }
      }

      validate_output(schema, "main", %{"post" => %{"text" => "Hello"}})
      #=> {:ok, %{"post" => %{"text" => "Hello"}}}
  """
  @spec validate_output(map(), String.t(), map()) :: validation_result()
  def validate_output(schema, def_name, data) when is_map(data) do
    validate(schema, def_name, Map.put(data, "$xrpc", "output"))
  end

  @doc """
  Validates XRPC parameters (URL/query string parameters) against a schema.

  For XRPC endpoints, this validates query string parameters against the
  `parameters` schema definition.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.search",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "parameters" => %{
              "type" => "params",
              "required" => ["q"],
              "properties" => %{
                "q" => %{"type" => "string"},
                "limit" => %{"type" => "integer", "default" => 25}
              }
            }
          }
        }
      }

      validate_parameters(schema, "main", %{"q" => "test"})
      #=> {:ok, %{"q" => "test", "limit" => 25}}
  """
  @spec validate_parameters(map(), String.t(), map()) :: validation_result()
  def validate_parameters(schema, def_name, data) when is_map(data) do
    validate(schema, def_name, Map.put(data, "$xrpc", "parameters"))
  end

  @doc """
  Validates XRPC subscription message against a schema.

  For subscription endpoints, this validates WebSocket messages against the
  `message` schema definition.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.subscribe",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "message" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["seq"],
                "properties" => %{"seq" => %{"type" => "integer"}}
              }
            }
          }
        }
      }

      validate_message(schema, "main", %{"seq" => 12345})
      #=> {:ok, %{"seq" => 12345}}
  """
  @spec validate_message(map(), String.t(), map()) :: validation_result()
  def validate_message(schema, def_name, data) when is_map(data) do
    validate(schema, def_name, Map.put(data, "$xrpc", "message"))
  end

  @doc """
  Validates XRPC error response against a schema.

  For XRPC endpoints, this validates error responses against the named error
  definition in the `errors` list.

  ## Examples

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.auth",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "errors" => [
              %{
                "name" => "InvalidCredentials",
                "schema" => %{
                  "type" => "object",
                  "required" => ["message"],
                  "properties" => %{"message" => %{"type" => "string"}}
                }
              }
            ]
          }
        }
      }

      validate_error(schema, "main", "InvalidCredentials", %{"message" => "Wrong password"})
      #=> {:ok, %{"message" => "Wrong password"}}
  """
  @spec validate_error(map(), String.t(), String.t(), map()) :: validation_result()
  def validate_error(schema, def_name, error_name, data) when is_map(data) do
    validate(schema, def_name, Map.merge(data, %{"$xrpc" => "error", "$error" => error_name}))
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

  # Route to appropriate validator based on type using pattern matching
  defp validate_by_type(schema, path, %{"type" => "object"} = definition, value),
    do: validate_object(schema, path, definition, value)

  defp validate_by_type(schema, path, %{"type" => "array"} = definition, value),
    do: validate_array(schema, path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => "string"} = definition, value),
    do: validate_string(path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => "integer"} = definition, value),
    do: validate_integer(path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => "boolean"} = definition, value),
    do: validate_boolean(path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => "bytes"} = definition, value),
    do: validate_bytes(path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => "cid-link"}, value),
    do: validate_cid_link(path, value)

  defp validate_by_type(_schema, path, %{"type" => "unknown"}, value),
    do: validate_unknown(path, value)

  defp validate_by_type(_schema, path, %{"type" => "blob"}, value),
    do: validate_blob(path, value)

  defp validate_by_type(_schema, path, %{"type" => "token"}, value),
    do: validate_token(path, value)

  defp validate_by_type(schema, path, %{"type" => "record"} = definition, value),
    do: validate_record(schema, path, definition, value)

  defp validate_by_type(schema, path, %{"type" => type} = definition, value)
      when type in ["query", "procedure", "subscription"],
    do: validate_xrpc_io(schema, path, definition, value)

  defp validate_by_type(_schema, path, %{"type" => type}, _value),
    do: {:error, "Unsupported type '#{type}' at #{path}"}

  # Object validation - dispatcher
  defp validate_object(schema, path, definition, value) when is_map(value) do
    properties = Map.get(definition, "properties", %{})
    required = Map.get(definition, "required", [])
    nullable = Map.get(definition, "nullable", [])

    # Validate each property
    Enum.reduce_while(properties, {:ok, value}, fn {key, prop_def}, {:ok, acc_value} ->
      validate_object_property(schema, path, key, prop_def, value, acc_value, required, nullable)
    end)
  end

  defp validate_object(_schema, path, _definition, value) do
    {:error, "Expected object at #{path}, got #{inspect(value)}"}
  end

  # Helper: Validate a single object property using pattern matching
  defp validate_object_property(schema, path, key, prop_def, original_value, acc_value, required, nullable) do
    key_value = Map.get(original_value, key)

    # Build validation context
    ctx = %{
      schema: schema,
      path: path,
      key: key,
      prop_def: prop_def,
      value: key_value,
      acc: acc_value,
      required?: key in required,
      nullable?: key in nullable
    }

    validate_property_value(ctx)
  end

  # Nil value for nullable property - skip validation
  defp validate_property_value(%{value: nil, nullable?: true, acc: acc}) do
    {:cont, {:ok, acc}}
  end

  # Nil value for optional (non-required) property - check for defaults
  defp validate_property_value(%{value: nil, required?: false, key: key, prop_def: prop_def, acc: acc}) do
    apply_default_value(key, prop_def, acc)
  end

  # Nil value for required property - will be caught during validation
  defp validate_property_value(%{value: nil, required?: true} = ctx) do
    %{schema: schema, path: path, key: key, prop_def: prop_def, acc: acc} = ctx
    prop_path = "#{path}/#{key}"

    case validate_one_of(schema, prop_path, prop_def, nil) do
      {:ok, validated_value} ->
        new_acc = update_if_changed(acc, key, nil, validated_value)
        {:cont, {:ok, new_acc}}

      {:error, _} ->
        {:halt, {:error, "#{path} must have the property \"#{key}\""}}
    end
  end

  # Non-nil value - validate it
  defp validate_property_value(%{value: value} = ctx) when not is_nil(value) do
    %{schema: schema, path: path, key: key, prop_def: prop_def, acc: acc} = ctx
    prop_path = "#{path}/#{key}"

    case validate_one_of(schema, prop_path, prop_def, value) do
      {:ok, validated_value} ->
        new_acc = update_if_changed(acc, key, value, validated_value)
        {:cont, {:ok, new_acc}}

      {:error, _} = error ->
        {:halt, error}
    end
  end

  # Helper: Apply default value if present
  defp apply_default_value(key, prop_def, acc_value) do
    case get_default_value(prop_def) do
      nil -> {:cont, {:ok, acc_value}}
      default -> {:cont, {:ok, Map.put(acc_value, key, default)}}
    end
  end

  # Helper: Update accumulator only if value changed (guards for efficiency)
  defp update_if_changed(acc_value, _key, original, validated) when original == validated,
    do: acc_value
  defp update_if_changed(acc_value, key, _original, validated),
    do: Map.put(acc_value, key, validated)

  # Array validation
  defp validate_array(schema, path, definition, value) when is_list(value) do
    with :ok <- validate_length(value,
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
    with :ok <- validate_const(value, definition["const"], path),
         :ok <- validate_enum(value, definition["enum"], path),
         :ok <- validate_string_length(definition, value, path),
         :ok <- validate_string_graphemes(definition, value, path),
         {:ok, _} <- validate_string_format(definition, value, path) do
      {:ok, value}
    end
  end

  defp validate_string(path, definition, nil) do
    case get_default("string", definition["default"]) do
      nil -> {:error, "#{path} must be a string"}
      default -> {:ok, default}
    end
  end

  defp validate_string(path, _definition, value) do
    {:error, "#{path} must be a string, got #{inspect(value)}"}
  end

  # String byte length validation (UTF-8 optimized like official implementation) - dispatcher
  defp validate_string_length(definition, value, path) do
    min_length = Map.get(definition, "minLength")
    max_length = Map.get(definition, "maxLength")

    validate_length_constraints(min_length, max_length, value, path)
  end

  # No length constraints
  defp validate_length_constraints(nil, nil, _value, _path), do: :ok

  # Both min and max length constraints
  defp validate_length_constraints(min, max, value, path)
      when not is_nil(min) and not is_nil(max) do
    byte_length = byte_size(value)
    validate_byte_range(byte_length, min, max, path)
  end

  # Only minimum length constraint
  defp validate_length_constraints(min, nil, value, path) when not is_nil(min) do
    string_length = String.length(value)
    validate_min_byte_length(value, string_length, min, path)
  end

  # Only maximum length constraint (with UTF-8 optimization)
  defp validate_length_constraints(nil, max, value, path) when not is_nil(max) do
    string_length = String.length(value)
    validate_max_byte_length(value, string_length, max, path)
  end

  # Fallback for unexpected cases
  defp validate_length_constraints(_, _, _value, _path), do: :ok

  # Validate byte length is within range using guards
  defp validate_byte_range(length, _min, max, path) when length > max,
    do: {:error, "#{path} must not be longer than #{max} characters"}
  defp validate_byte_range(length, min, _max, path) when length < min,
    do: {:error, "#{path} must not be shorter than #{min} characters"}
  defp validate_byte_range(_length, _min, _max, _path), do: :ok

  # Validate minimum byte length with UTF-8 optimization
  # Fast path: if string_length * 3 < min, it's definitely too short
  defp validate_min_byte_length(_value, string_length, min, path)
      when string_length * 3 < min,
    do: {:error, "#{path} must not be shorter than #{min} characters"}

  # Slow path: need to check actual byte size
  defp validate_min_byte_length(value, _string_length, min, path) do
    byte_length = byte_size(value)
    validate_min_bytes(byte_length, min, path)
  end

  defp validate_min_bytes(length, min, path) when length < min,
    do: {:error, "#{path} must not be shorter than #{min} characters"}
  defp validate_min_bytes(_length, _min, _path), do: :ok

  # Validate maximum byte length with UTF-8 optimization
  # Fast path: if string_length * 3 <= max, it's definitely ok
  defp validate_max_byte_length(_value, string_length, max, _path)
      when string_length * 3 <= max,
    do: :ok

  # Slow path: need to check actual byte size
  defp validate_max_byte_length(value, _string_length, max, path) do
    byte_length = byte_size(value)
    validate_max_bytes(byte_length, max, path)
  end

  defp validate_max_bytes(length, max, path) when length > max,
    do: {:error, "#{path} must not be longer than #{max} characters"}
  defp validate_max_bytes(_length, _max, _path), do: :ok

  # String grapheme validation - dispatcher
  defp validate_string_graphemes(definition, value, path) do
    min_graphemes = Map.get(definition, "minGraphemes")
    max_graphemes = Map.get(definition, "maxGraphemes")

    validate_grapheme_constraints(min_graphemes, max_graphemes, value, path)
  end

  # No grapheme constraints
  defp validate_grapheme_constraints(nil, nil, _value, _path), do: :ok

  # Both min and max grapheme constraints
  defp validate_grapheme_constraints(min, max, value, path)
      when not is_nil(min) and not is_nil(max) do
    # In Elixir, String.length/1 returns grapheme count (not code units like JavaScript)
    grapheme_length = String.length(value)
    validate_grapheme_range(grapheme_length, min, max, path)
  end

  # Only minimum grapheme constraint
  defp validate_grapheme_constraints(min, nil, value, path) when not is_nil(min) do
    grapheme_length = String.length(value)
    validate_min_graphemes(grapheme_length, min, path)
  end

  # Only maximum grapheme constraint
  defp validate_grapheme_constraints(nil, max, value, path) when not is_nil(max) do
    grapheme_length = String.length(value)
    validate_max_graphemes(grapheme_length, max, path)
  end

  # Fallback for unexpected cases
  defp validate_grapheme_constraints(_, _, _value, _path), do: :ok

  # Validate grapheme count is within range using guards
  defp validate_grapheme_range(length, min, _max, path) when length < min,
    do: {:error, "#{path} must not be shorter than #{min} graphemes"}
  defp validate_grapheme_range(length, _min, max, path) when length > max,
    do: {:error, "#{path} must not be longer than #{max} graphemes"}
  defp validate_grapheme_range(_length, _min, _max, _path), do: :ok

  # Validate minimum grapheme count using guards
  defp validate_min_graphemes(length, min, path) when length < min,
    do: {:error, "#{path} must not be shorter than #{min} graphemes"}
  defp validate_min_graphemes(_length, _min, _path), do: :ok

  # Validate maximum grapheme count using guards
  defp validate_max_graphemes(length, max, path) when length > max,
    do: {:error, "#{path} must not be longer than #{max} graphemes"}
  defp validate_max_graphemes(_length, _max, _path), do: :ok

  defp validate_string_format(%{"format" => format}, value, path),
    do: validate_format(format, value, path)

  defp validate_string_format(_definition, value, _path), do: {:ok, value}

  # Integer validation
  defp validate_integer(path, definition, value) when is_integer(value) do
    with :ok <- validate_const(value, definition["const"], path),
         :ok <- validate_enum(value, definition["enum"], path),
         :ok <- validate_range(value,
                  [minimum: definition["minimum"], maximum: definition["maximum"]], path) do
      {:ok, value}
    end
  end

  defp validate_integer(path, definition, nil) do
    case get_default("integer", definition["default"]) do
      nil -> {:error, "#{path} must be an integer"}
      default -> {:ok, default}
    end
  end

  defp validate_integer(path, _definition, value) do
    {:error, "#{path} must be an integer, got #{inspect(value)}"}
  end

  # Boolean validation
  defp validate_boolean(path, definition, value) when is_boolean(value) do
    with :ok <- validate_const(value, definition["const"], path) do
      {:ok, value}
    end
  end

  defp validate_boolean(path, definition, nil) do
    case get_default("boolean", definition["default"]) do
      nil -> {:error, "#{path} must be a boolean"}
      default -> {:ok, default}
    end
  end

  defp validate_boolean(path, _definition, value) do
    {:error, "#{path} must be a boolean, got #{inspect(value)}"}
  end

  # Bytes validation
  defp validate_bytes(path, definition, value) when is_binary(value) do
    with :ok <- validate_length(value,
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
    validate_with_regex(value, @cid_regex, path, " must be a CID")
  end

  defp validate_cid_link(path, _value), do: {:error, "#{path} must be a CID"}

  # Helper: validate string against regex
  defp validate_with_regex(value, regex, path, error_suffix) do
    case String.match?(value, regex) do
      true -> {:ok, value}
      false -> {:error, "#{path}#{error_suffix}"}
    end
  end

  # Unknown type - accepts any object
  defp validate_unknown(_path, value) when is_map(value) do
    {:ok, value}
  end

  defp validate_unknown(path, _value) do
    {:error, "#{path} must be an object"}
  end

  # Blob validation - expects a map with blob structure
  defp validate_blob(_path, %{"$type" => "blob"} = value), do: {:ok, value}

  defp validate_blob(_path, %{"ref" => _, "mimeType" => _} = value), do: {:ok, value}

  defp validate_blob(path, %{}), do: {:error, "#{path} should be a blob ref"}

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

  # XRPC endpoint validation (query, procedure, subscription)
  # Validates different parts of XRPC schemas based on $xrpc marker

  # Validate parameters (query string params)
  defp validate_xrpc_io(schema, path, definition, %{"$xrpc" => "parameters"} = data) do
    case definition["parameters"] do
      nil ->
        {:ok, data}

      params_def ->
        actual_data = Map.delete(data, "$xrpc")
        # Parameters have type "params" but are validated like objects
        validate_params(schema, "#{path}/parameters", params_def, actual_data)
    end
  end

  # Validate input
  defp validate_xrpc_io(schema, path, definition, %{"$xrpc" => "input"} = data) do
    case definition["input"] do
      nil ->
        {:ok, data}

      %{"schema" => input_schema} ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/input", input_schema, actual_data)

      input_schema ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/input", input_schema, actual_data)
    end
  end

  # Validate output
  defp validate_xrpc_io(schema, path, definition, %{"$xrpc" => "output"} = data) do
    case definition["output"] do
      nil ->
        {:ok, data}

      %{"schema" => output_schema} ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/output", output_schema, actual_data)

      output_schema ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/output", output_schema, actual_data)
    end
  end

  # Validate message (for subscriptions)
  defp validate_xrpc_io(schema, path, definition, %{"$xrpc" => "message"} = data) do
    case definition["message"] do
      nil ->
        {:ok, data}

      %{"schema" => message_schema} ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/message", message_schema, actual_data)

      message_schema ->
        actual_data = Map.delete(data, "$xrpc")
        validate_one_of(schema, "#{path}/message", message_schema, actual_data)
    end
  end

  # Validate errors (named error responses)
  defp validate_xrpc_io(schema, path, definition, %{"$xrpc" => "error", "$error" => error_name} = data) do
    case definition["errors"] do
      nil ->
        {:error, "#{path} has no errors defined"}

      errors when is_list(errors) ->
        actual_data = data |> Map.delete("$xrpc") |> Map.delete("$error")

        # Find the named error
        error_def = Enum.find(errors, fn err -> err["name"] == error_name end)

        case error_def do
          nil ->
            available = Enum.map(errors, & &1["name"]) |> Enum.join(", ")
            {:error, "#{path} unknown error '#{error_name}', available: #{available}"}

          %{"schema" => error_schema} ->
            validate_one_of(schema, "#{path}/errors/#{error_name}", error_schema, actual_data)

          _error_without_schema ->
            # Error defined but no schema - accept any data
            {:ok, actual_data}
        end
    end
  end

  # Default: validate against input schema
  defp validate_xrpc_io(schema, path, definition, value) do
    case definition["input"] do
      nil ->
        {:ok, value}

      %{"schema" => input_schema} ->
        validate_one_of(schema, "#{path}/input", input_schema, value)

      input_schema ->
        validate_one_of(schema, "#{path}/input", input_schema, value)
    end
  end

  # Validate parameters (type: "params")
  defp validate_params(_schema, path, %{"type" => "params"}, value) when not is_map(value) do
    {:error, "#{path} must be an object"}
  end

  defp validate_params(schema, path, %{"type" => "params"} = params_def, value) when is_map(value) do
    # Parameters are like objects with properties and required fields
    properties = Map.get(params_def, "properties", %{})
    required = Map.get(params_def, "required", [])

    # Validate each parameter
    Enum.reduce_while(properties, {:ok, value}, fn {key, prop_def}, {:ok, acc_value} ->
      validate_param_property(schema, path, key, prop_def, acc_value, key in required)
    end)
  end

  defp validate_params(_schema, path, _params_def, _value) do
    {:error, "#{path} invalid parameters definition"}
  end

  # Helper: Validate a single parameter property
  defp validate_param_property(schema, path, key, prop_def, acc_value, is_required) do
    param_value = Map.get(acc_value, key)

    case {is_nil(param_value), is_required} do
      {true, false} ->
        # Optional parameter - check for defaults
        case get_default_value(prop_def) do
          nil -> {:cont, {:ok, acc_value}}
          default -> {:cont, {:ok, Map.put(acc_value, key, default)}}
        end

      {true, true} ->
        # Required parameter missing
        {:halt, {:error, "#{path} must have the parameter \"#{key}\""}}

      {false, _} ->
        # Validate the parameter value
        param_path = "#{path}/#{key}"

        case validate_one_of(schema, param_path, prop_def, param_value) do
          {:ok, validated_value} ->
            new_acc =
              case validated_value != param_value do
                true -> Map.put(acc_value, key, validated_value)
                false -> acc_value
              end

            {:cont, {:ok, new_acc}}

          {:error, _} = error ->
            {:halt, error}
        end
    end
  end

  # Helper: Get default value from definition
  defp get_default_value(%{"type" => type, "default" => default}),
    do: get_default(type, default)

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

  # ============================================================================
  # Common validation helpers (from Validators module)
  # ============================================================================

  # Validates that a numeric value is within the specified range
  defp validate_range(value, opts, path) when is_number(value) do
    with :ok <- validate_minimum(value, opts[:minimum], path),
         :ok <- validate_maximum(value, opts[:maximum], path) do
      :ok
    end
  end

  defp validate_minimum(_value, nil, _path), do: :ok
  defp validate_minimum(value, min, _path) when value >= min, do: :ok
  defp validate_minimum(_value, min, path), do: {:error, "#{path} can not be less than #{min}"}

  defp validate_maximum(_value, nil, _path), do: :ok
  defp validate_maximum(value, max, _path) when value <= max, do: :ok
  defp validate_maximum(_value, max, path), do: {:error, "#{path} can not be greater than #{max}"}

  # Validates that a collection length is within bounds
  defp validate_length(value, opts, path, unit) when is_list(value) or is_binary(value) do
    length = if is_list(value), do: length(value), else: byte_size(value)

    with :ok <- validate_min_length(length, opts[:min_length], path, unit),
         :ok <- validate_max_length(length, opts[:max_length], path, unit) do
      :ok
    end
  end

  defp validate_min_length(_length, nil, _path, _unit), do: :ok
  defp validate_min_length(length, min, _path, _unit) when length >= min, do: :ok

  defp validate_min_length(_length, min, path, "elements"),
    do: {:error, "#{path} must not have fewer than #{min} elements"}

  defp validate_min_length(_length, min, path, "characters"),
    do: {:error, "#{path} must not be shorter than #{min} characters"}

  defp validate_min_length(_length, min, path, "bytes"),
    do: {:error, "#{path} must not be smaller than #{min} bytes"}

  defp validate_min_length(_length, min, path, "graphemes"),
    do: {:error, "#{path} must not be shorter than #{min} graphemes"}

  defp validate_max_length(_length, nil, _path, _unit), do: :ok
  defp validate_max_length(length, max, _path, _unit) when length <= max, do: :ok

  defp validate_max_length(_length, max, path, "elements"),
    do: {:error, "#{path} must not have more than #{max} elements"}

  defp validate_max_length(_length, max, path, "characters"),
    do: {:error, "#{path} must not be longer than #{max} characters"}

  defp validate_max_length(_length, max, path, "bytes"),
    do: {:error, "#{path} must not be larger than #{max} bytes"}

  defp validate_max_length(_length, max, path, "graphemes"),
    do: {:error, "#{path} must not be longer than #{max} graphemes"}

  # Validates that a value matches a constant
  defp validate_const(_value, nil, _path), do: :ok
  defp validate_const(value, const, _path) when value == const, do: :ok
  defp validate_const(_value, const, path), do: {:error, "#{path} must be #{const}"}

  # Validates that a value is in an enumeration
  defp validate_enum(value, enum, path) when is_list(enum) do
    if value in enum do
      :ok
    else
      {:error, "#{path} must be one of (#{Enum.join(enum, "|")})"}
    end
  end

  defp validate_enum(_value, _non_list, _path), do: :ok

  # Returns a default value if it matches the expected type
  defp get_default("string", default) when is_binary(default), do: default
  defp get_default("integer", default) when is_integer(default), do: default
  defp get_default("boolean", default) when is_boolean(default), do: default
  defp get_default(_type, _default), do: nil

  # ============================================================================
  # String format validators (from Formats module)
  # ============================================================================

  # Validates a value against a specific format type
  defp validate_format("datetime", value, path), do: datetime(path, value)
  defp validate_format("uri", value, path), do: uri(path, value)
  defp validate_format("at-uri", value, path), do: at_uri(path, value)
  defp validate_format("did", value, path), do: did(path, value)
  defp validate_format("handle", value, path), do: handle(path, value)
  defp validate_format("at-identifier", value, path), do: at_identifier(path, value)
  defp validate_format("nsid", value, path), do: nsid(path, value)
  defp validate_format("cid", value, path), do: cid(path, value)
  defp validate_format("language", value, path), do: language(path, value)
  defp validate_format("tid", value, path), do: tid(path, value)
  defp validate_format("record-key", value, path), do: record_key(path, value)
  defp validate_format(_unknown_format, value, _path), do: {:ok, value}

  # Validates an ISO 8601 / RFC 3339 datetime string
  defp datetime(path, value) do
    validate_with_regex(value, @iso8601_regex, path,
      "must be an valid atproto datetime (both RFC-3339 and ISO-8601)")
  end

  # Validates a Decentralized Identifier (DID)
  defp did(path, value) do
    validate_with_regex(value, @did_regex, path, "must be a valid did")
  end

  # Validates a handle in DNS-like format
  defp handle(path, value) when byte_size(value) > 253 do
    {:error, "#{path} must be a valid handle"}
  end

  defp handle(path, value) do
    validate_with_regex(value, @handle_regex, path, "must be a valid handle")
  end

  # Validates a Namespace ID (NSID)
  defp nsid(path, value) when byte_size(value) > 317 do
    {:error, "#{path} must be a valid nsid"}
  end

  defp nsid(path, value) do
    validate_with_regex(value, @nsid_regex, path, "must be a valid nsid")
  end

  # Generic URI format validation
  defp uri(path, value) do
    validate_with_regex(value, @uri_regex, path, "must be a uri")
  end

  # AT Protocol URI validation
  defp at_uri(path, value) do
    validate_with_regex(value, @at_uri_regex, path, "must be a valid at-uri")
  end

  # AT Identifier (DID or Handle)
  defp at_identifier(path, "did:" <> _ = value) do
    validate_did_or_handle(path, value, &did/2)
  end

  defp at_identifier(path, value) do
    validate_did_or_handle(path, value, &handle/2)
  end

  # CID (Content Identifier) validation
  defp cid(path, value) do
    validate_with_regex(value, @cid_format_regex, path, "must be a cid string")
  end

  # BCP 47 language tag validation
  defp language(path, value) do
    validate_with_regex(value, @language_regex, path, "must be a well-formed BCP 47 language tag")
  end

  # TID (Timestamp ID) validation
  defp tid(path, value) do
    validate_with_regex(value, @tid_regex, path, "must be a valid TID")
  end

  # Record Key validation
  defp record_key(path, value) when byte_size(value) > 512 do
    {:error, "#{path} must be a valid Record Key"}
  end

  defp record_key(path, value) when byte_size(value) == 0 do
    {:error, "#{path} must be a valid Record Key"}
  end

  defp record_key(path, value) do
    validate_with_regex(value, @record_key_regex, path, "must be a valid Record Key")
  end

  # Helper: Validate DID or handle with fallback error message
  defp validate_did_or_handle(path, value, validator_fun) do
    case validator_fun.(path, value) do
      {:ok, _} = result -> result
      {:error, _} -> {:error, "#{path} must be a valid did or a handle"}
    end
  end
end
