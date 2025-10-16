defmodule AetherLexicon.Validation.Validators do
  @moduledoc """
  Common validation helpers for ATProto lexicon schemas.

  This module provides reusable validation functions for common constraints
  like ranges, lengths, constants, and enumerations. These helpers are used
  throughout the validation system to enforce lexicon constraints consistently.

  All validation functions follow the pattern of returning either `:ok` on
  success or `{:error, message}` on failure.
  """

  @doc """
  Validates that a numeric value is within the specified range.

  Checks minimum and maximum constraints. When both constraints are present,
  the value must satisfy both. When only one is present, only that constraint
  is checked.

  ## Options

    * `:minimum` - The minimum allowed value (inclusive)
    * `:maximum` - The maximum allowed value (inclusive)

  ## Examples

      validate_range(5, [minimum: 1, maximum: 10], "/count")
      #=> :ok

      validate_range(15, [minimum: 1, maximum: 10], "/count")
      #=> {:error, "/count can not be greater than 10"}

      validate_range(0, [minimum: 1], "/count")
      #=> {:error, "/count can not be less than 1"}

      validate_range(50, [maximum: 100], "/count")
      #=> :ok
  """
  @spec validate_range(number(), keyword(), String.t()) :: :ok | {:error, String.t()}
  def validate_range(value, opts, path) when is_number(value) do
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

  @doc """
  Validates that a collection length is within bounds.

  Works with both lists and binaries, automatically determining the appropriate
  length measurement. For lists, counts elements. For binaries, counts bytes.

  The `unit` parameter controls error message formatting and should match the
  type of data being validated.

  ## Options

    * `:min_length` - The minimum allowed length (inclusive)
    * `:max_length` - The maximum allowed length (inclusive)

  ## Unit Types

    * `"elements"` - For list/array validation
    * `"characters"` - For string character count validation
    * `"bytes"` - For binary size validation
    * `"graphemes"` - For Unicode grapheme validation

  ## Examples

      validate_length([1, 2, 3], [min_length: 1, max_length: 5], "/items", "elements")
      #=> :ok

      validate_length("hello", [max_length: 10], "/text", "bytes")
      #=> :ok

      validate_length([1, 2], [min_length: 5], "/items", "elements")
      #=> {:error, "/items must not have fewer than 5 elements"}

      validate_length("hi", [min_length: 10], "/text", "characters")
      #=> {:error, "/text must not be shorter than 10 characters"}
  """
  @spec validate_length(list() | binary(), keyword(), String.t(), String.t()) ::
          :ok | {:error, String.t()}
  def validate_length(value, opts, path, unit \\ "elements")
      when is_list(value) or is_binary(value) do
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

  @doc """
  Validates that a value matches a constant.

  Used to enforce that a field has a specific fixed value. When the constant
  is `nil`, no validation is performed (any value is accepted).

  ## Examples

      validate_const("apple", "apple", "/type")
      #=> :ok

      validate_const("orange", "apple", "/type")
      #=> {:error, "/type must be apple"}

      validate_const(42, 42, "/version")
      #=> :ok

      validate_const("anything", nil, "/field")
      #=> :ok
  """
  @spec validate_const(any(), any(), String.t()) :: :ok | {:error, String.t()}
  def validate_const(_value, nil, _path), do: :ok
  def validate_const(value, const, _path) when value == const, do: :ok
  def validate_const(_value, const, path), do: {:error, "#{path} must be #{const}"}

  @doc """
  Validates that a value is in an enumeration.

  Checks if the value is one of the allowed values in the enumeration list.
  When the enum parameter is not a list (including `nil`), no validation is
  performed.

  ## Examples

      validate_enum("red", ["red", "green", "blue"], "/color")
      #=> :ok

      validate_enum("yellow", ["red", "green", "blue"], "/color")
      #=> {:error, "/color must be one of (red|green|blue)"}

      validate_enum(2, [1, 2, 3], "/priority")
      #=> :ok

      validate_enum("anything", nil, "/field")
      #=> :ok
  """
  @spec validate_enum(any(), list() | any(), String.t()) :: :ok | {:error, String.t()}
  def validate_enum(value, enum, path) when is_list(enum) do
    if value in enum do
      :ok
    else
      {:error, "#{path} must be one of (#{Enum.join(enum, "|")})"}
    end
  end

  def validate_enum(_value, _non_list, _path), do: :ok

  @doc """
  Returns a default value if it matches the expected type.

  Validates that the provided default value matches the expected type before
  returning it. If the types don't match, or for unsupported types, returns
  `nil`.

  This type-safe approach ensures defaults are only applied when they have
  the correct type, preventing type errors in validated data.

  ## Supported Types

    * `"string"` - Binary/string values
    * `"integer"` - Integer values
    * `"boolean"` - Boolean values (true/false)

  ## Examples

      get_default("string", "hello")
      #=> "hello"

      get_default("integer", 42)
      #=> 42

      get_default("boolean", true)
      #=> true

      get_default("boolean", false)
      #=> false

      # Type mismatch - returns nil
      get_default("string", 123)
      #=> nil

      get_default("integer", "not an int")
      #=> nil

      # Unsupported type
      get_default("array", [1, 2, 3])
      #=> nil
  """
  @spec get_default(String.t(), any()) :: any()
  def get_default("string", default) when is_binary(default), do: default
  def get_default("integer", default) when is_integer(default), do: default
  def get_default("boolean", default) when is_boolean(default), do: default
  def get_default(_type, _default), do: nil
end
