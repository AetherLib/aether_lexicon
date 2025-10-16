defmodule AetherLexicon.Validation.Formats do
  @moduledoc """
  String format validators for ATProto lexicon schemas.

  This module implements validation for various AT Protocol string formats,
  ensuring data conforms to the specifications required by the ATProto ecosystem.

  ## Supported Formats

    * `"datetime"` - ISO 8601 / RFC 3339 datetime strings
    * `"uri"` - Generic URI format
    * `"at-uri"` - AT Protocol URIs (e.g., `at://did/collection/rkey`)
    * `"did"` - Decentralized Identifiers
    * `"handle"` - DNS-like handles (e.g., `user.bsky.social`)
    * `"at-identifier"` - Either a DID or handle
    * `"nsid"` - Namespace IDs (e.g., `com.atproto.server.createSession`)
    * `"cid"` - Content Identifiers
    * `"language"` - BCP 47 language tags (e.g., `en-US`)
    * `"tid"` - Timestamp IDs
    * `"record-key"` - Valid record keys

  ## Examples

      # Valid datetime
      datetime("/timestamp", "2024-01-01T00:00:00Z")
      #=> {:ok, "2024-01-01T00:00:00Z"}

      # Invalid datetime
      datetime("/timestamp", "not-a-date")
      #=> {:error, "/timestamp must be an valid atproto datetime (both RFC-3339 and ISO-8601)"}

      # Valid handle
      handle("/handle", "user.bsky.social")
      #=> {:ok, "user.bsky.social"}

      # Valid DID
      did("/did", "did:plc:abc123xyz")
      #=> {:ok, "did:plc:abc123xyz"}
  """

  # Regex patterns defined as module attributes
  @iso8601_regex ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})?$/
  @uri_regex ~r/^\w+:(?:\/\/)?[^\s\/][^\s]*$/
  @at_uri_regex ~r/^at:\/\/[a-zA-Z0-9:._-]+\/[a-z][a-z0-9.-]*\.[a-z][a-z0-9.-]*[a-z]\/[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/
  @did_regex ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/
  @handle_regex ~r/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/
  @nsid_regex ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/
  @cid_regex ~r/^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{58,}|[a-z0-9]{59,})$/
  @language_regex ~r/^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2})?(-[a-zA-Z0-9]{5,8})*(-[a-zA-Z0-9]{1,8})*$/
  @tid_regex ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/
  @record_key_regex ~r/^[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/

  @doc """
  Validates a value against a specific format type.

  Acts as a dispatcher to the appropriate format validator based on the
  format name. Unknown formats are accepted without validation.

  ## Examples

      validate_format("datetime", "2024-01-01T00:00:00Z", "/timestamp")
      #=> {:ok, "2024-01-01T00:00:00Z"}

      validate_format("did", "did:plc:abc123", "/identifier")
      #=> {:ok, "did:plc:abc123"}

      validate_format("unknown-format", "any-value", "/field")
      #=> {:ok, "any-value"}
  """
  @spec validate_format(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_format("datetime", value, path), do: datetime(path, value)
  def validate_format("uri", value, path), do: uri(path, value)
  def validate_format("at-uri", value, path), do: at_uri(path, value)
  def validate_format("did", value, path), do: did(path, value)
  def validate_format("handle", value, path), do: handle(path, value)
  def validate_format("at-identifier", value, path), do: at_identifier(path, value)
  def validate_format("nsid", value, path), do: nsid(path, value)
  def validate_format("cid", value, path), do: cid(path, value)
  def validate_format("language", value, path), do: language(path, value)
  def validate_format("tid", value, path), do: tid(path, value)
  def validate_format("record-key", value, path), do: record_key(path, value)
  def validate_format(_unknown_format, value, _path), do: {:ok, value}

  @doc """
  Validates an ISO 8601 / RFC 3339 datetime string.

  ## Examples

      datetime("/createdAt", "2024-01-01T00:00:00Z")
      #=> {:ok, "2024-01-01T00:00:00Z"}

      datetime("/createdAt", "2024-01-01T12:30:00.123Z")
      #=> {:ok, "2024-01-01T12:30:00.123Z"}

      datetime("/createdAt", "2024-01-01T12:00:00+05:00")
      #=> {:ok, "2024-01-01T12:00:00+05:00"}

      datetime("/createdAt", "not-a-date")
      #=> {:error, "/createdAt must be an valid atproto datetime (both RFC-3339 and ISO-8601)"}
  """
  @spec datetime(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def datetime(path, value) do
    validate_with_regex(value, @iso8601_regex, path,
      "must be an valid atproto datetime (both RFC-3339 and ISO-8601)")
  end

  @doc """
  Validates a Decentralized Identifier (DID).

  DIDs follow the format `did:method:identifier` where method specifies the
  DID method (e.g., `plc`, `web`, `key`) and identifier is method-specific.

  ## Examples

      did("/identifier", "did:plc:abc123xyz")
      #=> {:ok, "did:plc:abc123xyz"}

      did("/identifier", "did:web:example.com")
      #=> {:ok, "did:web:example.com"}

      did("/identifier", "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK")
      #=> {:ok, "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"}

      did("/identifier", "not-a-did")
      #=> {:error, "/identifier must be a valid did"}
  """
  @spec did(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def did(path, value) do
    validate_with_regex(value, @did_regex, path, "must be a valid did")
  end

  @doc """
  Validates a handle in DNS-like format.

  Handles are domain names used as user identifiers in ATProto, following
  standard DNS naming rules with a maximum length of 253 characters.

  ## Examples

      handle("/handle", "user.bsky.social")
      #=> {:ok, "user.bsky.social"}

      handle("/handle", "alice.example.com")
      #=> {:ok, "alice.example.com"}

      handle("/handle", "invalid..handle")
      #=> {:error, "/handle must be a valid handle"}

      handle("/handle", "toolonghandle" <> String.duplicate("a", 250))
      #=> {:error, "/handle must be a valid handle"}
  """
  @spec handle(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def handle(path, value) when byte_size(value) > 253 do
    {:error, "#{path} must be a valid handle"}
  end

  def handle(path, value) do
    validate_with_regex(value, @handle_regex, path, "must be a valid handle")
  end

  @doc """
  Validates a Namespace ID (NSID).

  NSIDs use reversed domain notation to uniquely identify lexicon types and
  methods, with a maximum length of 317 characters.

  ## Examples

      nsid("/lexicon", "com.atproto.server.createSession")
      #=> {:ok, "com.atproto.server.createSession"}

      nsid("/lexicon", "app.bsky.feed.post")
      #=> {:ok, "app.bsky.feed.post"}

      nsid("/lexicon", "invalid")
      #=> {:error, "/lexicon must be a valid nsid"}
  """
  @spec nsid(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def nsid(path, value) when byte_size(value) > 317 do
    {:error, "#{path} must be a valid nsid"}
  end

  def nsid(path, value) do
    validate_with_regex(value, @nsid_regex, path, "must be a valid nsid")
  end

  # Generic URI format validation
  def uri(path, value) do
    validate_with_regex(value, @uri_regex, path, "must be a uri")
  end

  # AT Protocol URI validation (at://did:plc:xxx/collection/rkey)
  def at_uri(path, value) do
    validate_with_regex(value, @at_uri_regex, path, "must be a valid at-uri")
  end

  # AT Identifier (DID or Handle)
  def at_identifier(path, "did:" <> _ = value) do
    validate_did_or_handle(path, value, &did/2)
  end

  def at_identifier(path, value) do
    validate_did_or_handle(path, value, &handle/2)
  end

  # CID (Content Identifier) validation
  def cid(path, value) do
    validate_with_regex(value, @cid_regex, path, "must be a cid string")
  end

  # BCP 47 language tag validation
  def language(path, value) do
    validate_with_regex(value, @language_regex, path, "must be a well-formed BCP 47 language tag")
  end

  # TID (Timestamp ID) validation
  def tid(path, value) do
    validate_with_regex(value, @tid_regex, path, "must be a valid TID")
  end

  # Record Key validation
  def record_key(path, value) when byte_size(value) > 512 do
    {:error, "#{path} must be a valid Record Key"}
  end

  def record_key(path, value) when byte_size(value) == 0 do
    {:error, "#{path} must be a valid Record Key"}
  end

  def record_key(path, value) do
    validate_with_regex(value, @record_key_regex, path, "must be a valid Record Key")
  end

  # Helper: Validate string against regex pattern
  defp validate_with_regex(value, regex, path, error_suffix) do
    case String.match?(value, regex) do
      true -> {:ok, value}
      false -> {:error, "#{path} #{error_suffix}"}
    end
  end

  # Helper: Validate DID or handle with fallback error message
  defp validate_did_or_handle(path, value, validator_fun) do
    case validator_fun.(path, value) do
      {:ok, _} = result -> result
      {:error, _} -> {:error, "#{path} must be a valid did or a handle"}
    end
  end
end
