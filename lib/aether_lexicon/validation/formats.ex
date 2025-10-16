defmodule AetherLexicon.Validation.Formats do
  @moduledoc """
  String format validators for ATProto lexicon types.

  Implements validation for various AT Protocol string formats including:
  - datetime (ISO 8601 / RFC 3339)
  - uri (generic URI format)
  - at-uri (AT Protocol URIs like at://did/collection/rkey)
  - did (Decentralized Identifiers)
  - handle (DNS-like handles)
  - at-identifier (either did or handle)
  - nsid (Namespace IDs like com.example.type)
  - cid (Content Identifiers)
  - language (BCP 47 language tags)
  - tid (Timestamp IDs)
  - record-key (Valid record keys)
  """

  @doc """
  Validates a value against a specific format.
  """
  def validate_format(format, value, path) do
    case format do
      "datetime" -> datetime(path, value)
      "uri" -> uri(path, value)
      "at-uri" -> at_uri(path, value)
      "did" -> did(path, value)
      "handle" -> handle(path, value)
      "at-identifier" -> at_identifier(path, value)
      "nsid" -> nsid(path, value)
      "cid" -> cid(path, value)
      "language" -> language(path, value)
      "tid" -> tid(path, value)
      "record-key" -> record_key(path, value)
      _ -> {:ok, value}
    end
  end

  # ISO 8601 / RFC 3339 datetime validation
  def datetime(path, value) do
    # Basic ISO 8601 format check: YYYY-MM-DDTHH:MM:SS(.sss)?(Z|[+-]HH:MM)?
    iso8601_regex =
      ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})?$/

    if String.match?(value, iso8601_regex) do
      {:ok, value}
    else
      {:error,
       "#{path} must be an valid atproto datetime (both RFC-3339 and ISO-8601)"}
    end
  end

  # Generic URI format validation
  def uri(path, value) do
    # Pattern: scheme:path where scheme is alphanumeric and path is non-empty
    uri_regex = ~r/^\w+:(?:\/\/)?[^\s\/][^\s]*$/

    if String.match?(value, uri_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a uri"}
    end
  end

  # AT Protocol URI validation (at://did:plc:xxx/collection/rkey)
  def at_uri(path, value) do
    # at://authority/collection/rkey
    # authority can be DID or handle
    # collection is NSID format
    # rkey is alphanumeric with some special chars
    at_uri_regex =
      ~r/^at:\/\/[a-zA-Z0-9:._-]+\/[a-z][a-z0-9.-]*\.[a-z][a-z0-9.-]*[a-z]\/[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/

    if String.match?(value, at_uri_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a valid at-uri"}
    end
  end

  # DID (Decentralized Identifier) validation
  def did(path, value) do
    # did:method:identifier format
    # Common methods: plc, web, key
    did_regex = ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/

    if String.match?(value, did_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a valid did"}
    end
  end

  # Handle validation (DNS-like format)
  def handle(path, value) do
    # Domain name format: labels separated by dots
    # Each label starts with alphanumeric, can contain hyphens
    handle_regex = ~r/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/

    cond do
      String.length(value) > 253 ->
        {:error, "#{path} must be a valid handle"}

      String.match?(value, handle_regex) ->
        {:ok, value}

      true ->
        {:error, "#{path} must be a valid handle"}
    end
  end

  # AT Identifier (DID or Handle)
  def at_identifier(path, value) do
    # Try DID first if it starts with "did:"
    if String.starts_with?(value, "did:") do
      case did(path, value) do
        {:ok, _} = result -> result
        {:error, _} -> {:error, "#{path} must be a valid did or a handle"}
      end
    else
      case handle(path, value) do
        {:ok, _} = result -> result
        {:error, _} -> {:error, "#{path} must be a valid did or a handle"}
      end
    end
  end

  # NSID (Namespace ID) validation
  def nsid(path, value) do
    # Format: reversed domain notation like com.example.type or com.atproto.server.createSession
    # Minimum 3 segments, alphanumeric (both cases) with hyphens and dots
    # Based on: /^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/
    nsid_regex =
      ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/

    cond do
      String.length(value) > 317 ->
        {:error, "#{path} must be a valid nsid"}

      String.match?(value, nsid_regex) ->
        {:ok, value}

      true ->
        {:error, "#{path} must be a valid nsid"}
    end
  end

  # CID (Content Identifier) validation
  def cid(path, value) do
    # CIDv0: Qm followed by 44 base58 characters
    # CIDv1: base32 or base58 encoded, typically starts with 'b' for base32
    cid_regex = ~r/^(Qm[1-9A-HJ-NP-Za-km-z]{44}|b[a-z2-7]{58,}|[a-z0-9]{59,})$/

    if String.match?(value, cid_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a cid string"}
    end
  end

  # BCP 47 language tag validation
  def language(path, value) do
    # Basic BCP 47 format: 2-3 letter language code, optional script, region, variants
    # Examples: en, en-US, zh-Hans-CN, pt-BR
    language_regex =
      ~r/^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2})?(-[a-zA-Z0-9]{5,8})*(-[a-zA-Z0-9]{1,8})*$/

    if String.match?(value, language_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a well-formed BCP 47 language tag"}
    end
  end

  # TID (Timestamp ID) validation
  def tid(path, value) do
    # TID format: 13 character base32-sortable timestamp
    # Contains only specific base32 characters (2-7, a-z)
    tid_regex = ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/

    if String.match?(value, tid_regex) do
      {:ok, value}
    else
      {:error, "#{path} must be a valid TID"}
    end
  end

  # Record Key validation
  def record_key(path, value) do
    # Record keys: alphanumeric, dots, dashes, underscores, tildes, colons
    # Length constraints and character restrictions
    cond do
      String.length(value) > 512 ->
        {:error, "#{path} must be a valid Record Key"}

      String.length(value) == 0 ->
        {:error, "#{path} must be a valid Record Key"}

      String.match?(value, ~r/^[a-zA-Z0-9._~:@!$&'()*+,;=%[\]-]+$/) ->
        {:ok, value}

      true ->
        {:error, "#{path} must be a valid Record Key"}
    end
  end
end
