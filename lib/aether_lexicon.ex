defmodule AetherLexicon do
  @moduledoc """
  Main interface for ATProto lexicons.

  This module provides the primary API for validating ATProto lexicon schemas.
  All validation functions are delegated to `AetherLexicon.Validation`.

  ## Quick Start

      schema = %{
        "lexicon" => 1,
        "id" => "com.example.post",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "required" => ["text"],
            "properties" => %{
              "text" => %{"type" => "string", "maxLength" => 300}
            }
          }
        }
      }

      # Validate data
      AetherLexicon.validate(schema, "main", %{"text" => "Hello world!"})
      #=> {:ok, %{"text" => "Hello world!"}}

  ## XRPC Validation

  For XRPC endpoints, use the specialized functions:

      # Validate input (request body)
      AetherLexicon.validate_input(schema, "main", %{"text" => "Hello"})

      # Validate output (response body)
      AetherLexicon.validate_output(schema, "main", %{"post" => %{}})

      # Validate parameters (query string)
      AetherLexicon.validate_parameters(schema, "main", %{"limit" => 25})

      # Validate subscription message
      AetherLexicon.validate_message(schema, "main", %{"seq" => 123})

      # Validate error response
      AetherLexicon.validate_error(schema, "main", "InvalidRequest", %{"message" => "Bad input"})

  See `AetherLexicon.Validation` for detailed documentation.
  """

  @type validation_result :: {:ok, any()} | {:error, String.t()}

  @doc """
  Validates data against a lexicon schema definition.

  See `AetherLexicon.Validation.validate/3` for details.
  """
  defdelegate validate(schema, def_name, data), to: AetherLexicon.Validation

  @doc """
  Validates XRPC input data (request body) against a schema.

  See `AetherLexicon.Validation.validate_input/3` for details.
  """
  defdelegate validate_input(schema, def_name, data), to: AetherLexicon.Validation

  @doc """
  Validates XRPC output data (response body) against a schema.

  See `AetherLexicon.Validation.validate_output/3` for details.
  """
  defdelegate validate_output(schema, def_name, data), to: AetherLexicon.Validation

  @doc """
  Validates XRPC parameters (URL/query string parameters) against a schema.

  See `AetherLexicon.Validation.validate_parameters/3` for details.
  """
  defdelegate validate_parameters(schema, def_name, data), to: AetherLexicon.Validation

  @doc """
  Validates XRPC subscription message against a schema.

  See `AetherLexicon.Validation.validate_message/3` for details.
  """
  defdelegate validate_message(schema, def_name, data), to: AetherLexicon.Validation

  @doc """
  Validates XRPC error response against a schema.

  See `AetherLexicon.Validation.validate_error/4` for details.
  """
  defdelegate validate_error(schema, def_name, error_name, data), to: AetherLexicon.Validation
end
