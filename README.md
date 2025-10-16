# AetherLexicon
ATProto Lexicon in for Elixir.

## Features

- ✅ **Complete ATProto validation** - All primitive types, complex types, IPLD types, and XRPC endpoints
- ✅ **String format validation** - datetime, URI, DID, handle, NSID, CID, language tags, and more
- ✅ **XRPC endpoint support** - Validate query parameters, request/response bodies, subscriptions, and errors
- ✅ **Cross-schema references** - Full support for refs and unions across schemas
- ✅ **Comprehensive constraint validation** - min/max, length, enum, const, required, nullable
- ✅ **Functional API** - Simple, stateless validation functions

## Installation

Add `aether_lexicon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aether_lexicon, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Validation

```elixir
alias AetherLexicon.Validation

# Define a schema
schema = %{
  "lexicon" => 1,
  "id" => "com.example.post",
  "defs" => %{
    "main" => %{
      "type" => "record",
      "record" => %{
        "type" => "object",
        "required" => ["text", "createdAt"],
        "properties" => %{
          "text" => %{
            "type" => "string",
            "maxLength" => 300
          },
          "createdAt" => %{
            "type" => "string",
            "format" => "datetime"
          }
        }
      }
    }
  }
}

# Validate data
data = %{
  "text" => "Hello, ATProto!",
  "createdAt" => "2024-01-01T00:00:00Z"
}

case Validation.validate(schema, "main", data) do
  {:ok, validated_data} ->
    # Data is valid and normalized
    IO.puts("Valid: #{inspect(validated_data)}")

  {:error, message} ->
    # Validation failed
    IO.puts("Error: #{message}")
end
```

### XRPC Endpoint Validation

```elixir
# Query endpoint schema
query_schema = %{
  "lexicon" => 1,
  "id" => "com.example.getPosts",
  "defs" => %{
    "main" => %{
      "type" => "query",
      "parameters" => %{
        "type" => "params",
        "properties" => %{
          "limit" => %{"type" => "integer", "minimum" => 1, "maximum" => 100}
        }
      },
      "output" => %{
        "encoding" => "application/json",
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "posts" => %{"type" => "array", "items" => %{"type" => "string"}}
          }
        }
      }
    }
  }
}

# Validate parameters
{:ok, params} = Validation.validate_parameters(query_schema, "main", %{"limit" => "50"})

# Validate output
{:ok, output} = Validation.validate_output(query_schema, "main", %{
  "posts" => ["Post 1", "Post 2"]
})
```

### String Format Validation

```elixir
# DIDs (Decentralized Identifiers)
{:ok, did} = Validation.validate(did_schema, "main", "did:plc:abc123xyz")

# Handles
{:ok, handle} = Validation.validate(handle_schema, "main", "user.bsky.social")

# NSIDs (Namespace IDs)
{:ok, nsid} = Validation.validate(nsid_schema, "main", "com.atproto.server.createSession")

# Datetime (ISO 8601 / RFC 3339)
{:ok, dt} = Validation.validate(datetime_schema, "main", "2024-01-01T12:00:00Z")
```

## Supported Types

### Primitive Types
- `string` - with optional format validation
- `integer` - with min/max constraints
- `boolean`
- `unknown` - accepts any value

### String Formats
- `datetime` - ISO 8601 / RFC 3339
- `uri` - Generic URI
- `at-uri` - AT Protocol URI
- `did` - Decentralized Identifier
- `handle` - DNS-like handle
- `at-identifier` - DID or handle
- `nsid` - Namespace ID
- `cid` - Content Identifier
- `language` - BCP 47 language tag
- `tid` - Timestamp ID
- `record-key` - Record key

### Complex Types
- `object` - with required/nullable properties
- `array` - with min/max length
- `union` - with closed/open unions
- `ref` - references to other definitions

### IPLD Types
- `bytes` - binary data with length constraints
- `cid-link` - CID references

### Special Types
- `blob` - file uploads with accept types and max size
- `token` - opaque token values

### Top-Level Types
- `record` - repository records
- `query` - XRPC GET endpoints
- `procedure` - XRPC POST endpoints
- `subscription` - XRPC WebSocket endpoints

## XRPC Validation Functions

AetherLexicon provides dedicated functions for validating different parts of XRPC endpoints:

- `validate_input/3` - Validates request body
- `validate_output/3` - Validates response body
- `validate_parameters/3` - Validates URL/query parameters
- `validate_message/3` - Validates subscription messages
- `validate_error/4` - Validates named error responses

## Documentation

- [API Documentation](https://hexdocs.pm/aether_lexicon)
- [API Comparison with Official Library](docs/OFFICIAL_LEXICON_COMPARISON.md)
- [ATProto Specification](https://atproto.com/specs/lexicon)

## Comparison with Official Library

AetherLexicon provides **100% validation parity** with the official TypeScript `@atproto/lexicon` library. In fact, we provide additional functionality (error validation) that the official library doesn't have.

The main difference is architectural:
- **Official library**: Collection-based API with schema registry
- **AetherLexicon**: Functional API with direct validation

See [docs/OFFICIAL_LEXICON_COMPARISON.md](docs/OFFICIAL_LEXICON_COMPARISON.md) for a detailed comparison.

## Testing

AetherLexicon has comprehensive test coverage:

```bash
# Run tests
mix test

# Run with coverage
mix test --cover

# Current coverage: 99.38% (550 tests)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE.md](LICENSE.md) for details.

## Acknowledgments

This library implements the ATProto Lexicon specification created by Bluesky PBLLC. The validation logic is based on the official TypeScript implementation at [@atproto/lexicon](https://github.com/bluesky-social/atproto/tree/main/packages/lexicon).
