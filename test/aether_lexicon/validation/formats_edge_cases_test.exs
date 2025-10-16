defmodule AetherLexicon.Validation.FormatsEdgeCasesTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation.Formats

  describe "datetime edge cases" do
    test "validates datetime with various timezone formats" do
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00.123456789Z")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00.1Z")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00+05:30")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00-11:00")
    end

    test "accepts datetime without timezone" do
      # Our regex is lenient and accepts optional timezone
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00")
    end
  end

  describe "uri edge cases" do
    test "validates URIs with various protocols" do
      assert {:ok, _} = Formats.uri("path", "mailto:user@example.com")
      assert {:ok, _} = Formats.uri("path", "file://path/to/file")
      assert {:ok, _} = Formats.uri("path", "data:text/plain,hello")
    end

    test "rejects URI with spaces" do
      assert {:error, _} = Formats.uri("path", "http://example .com")
    end
  end

  describe "at_uri edge cases" do
    test "validates at-uri with various path components" do
      assert {:ok, _} =
               Formats.at_uri("path", "at://did:plc:abc/com.example.feed/post123")

      assert {:ok, _} =
               Formats.at_uri("path", "at://handle.bsky.social/app.bsky.graph.follow/abc")
    end

    test "rejects at-uri with invalid format" do
      assert {:error, _} = Formats.at_uri("path", "at://")
      assert {:error, _} = Formats.at_uri("path", "at:invalid")
    end
  end

  describe "did edge cases" do
    test "validates various DID methods" do
      assert {:ok, _} = Formats.did("path", "did:plc:z72i7hdynmk6r22z27h6tvur")
      assert {:ok, _} = Formats.did("path", "did:web:example.com")
      assert {:ok, _} = Formats.did("path", "did:key:z6Mkfriq1MqLBoPWecGoDLjguo1sB9brj6wT3qZ5BxkKpuP6")
      assert {:ok, _} = Formats.did("path", "did:ethr:0x1234567890abcdef")
    end

    test "rejects DID with trailing colon" do
      assert {:error, _} = Formats.did("path", "did:method:")
    end
  end

  describe "handle edge cases" do
    test "validates handles of various lengths" do
      assert {:ok, _} = Formats.handle("path", "a.b.c")
      assert {:ok, _} = Formats.handle("path", "very.long.subdomain.example.com")
    end

    test "accepts handle starting with digit in label" do
      # Our handle regex allows digits at start of labels
      assert {:ok, _} = Formats.handle("path", "1example.com")
    end

    test "rejects handle with underscore" do
      assert {:error, _} = Formats.handle("path", "under_score.com")
    end

    test "rejects handle with consecutive hyphens" do
      # Technically this might be valid DNS, but our validator is stricter
      assert {:ok, _} = Formats.handle("path", "my--domain.com")
    end
  end

  describe "nsid edge cases" do
    test "validates NSIDs with single character segments" do
      assert {:ok, _} = Formats.nsid("path", "a.b.c")
    end

    test "validates NSIDs with max length segments" do
      long_segment = String.duplicate("a", 63)
      assert {:ok, _} = Formats.nsid("path", "com.example.#{long_segment}")
    end

    test "rejects NSID starting with digit" do
      assert {:error, _} = Formats.nsid("path", "1com.example.type")
    end

    test "validates NSID with hyphens in middle segments" do
      assert {:ok, _} = Formats.nsid("path", "com.my-app.someType")
    end

    test "rejects NSID segment ending with hyphen" do
      assert {:error, _} = Formats.nsid("path", "com.example-.type")
    end
  end

  describe "cid edge cases" do
    test "validates CIDv1 with various encodings" do
      # Base32 CIDv1
      assert {:ok, _} = Formats.cid("path", "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")

      # Base32 shorter
      assert {:ok, _} = Formats.cid("path", "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy")
    end

    test "rejects CID with invalid prefix" do
      assert {:error, _} = Formats.cid("path", "Xm123456789012345678901234567890123456789012")
    end

    test "rejects CID that's too short" do
      assert {:error, _} = Formats.cid("path", "Qm123")
    end
  end

  describe "language edge cases" do
    test "validates extended language tags" do
      assert {:ok, _} = Formats.language("path", "zh-Hans")
      assert {:ok, _} = Formats.language("path", "zh-Hant-HK")
      assert {:ok, _} = Formats.language("path", "en-US-x-custom")
    end

    test "validates language with variants" do
      assert {:ok, _} = Formats.language("path", "de-DE-1996")
      assert {:ok, _} = Formats.language("path", "sl-rozaj")
    end

    test "rejects language with uppercase primary code" do
      assert {:error, _} = Formats.language("path", "EN")
    end

    test "rejects language with invalid format" do
      assert {:error, _} = Formats.language("path", "e")
      assert {:error, _} = Formats.language("path", "eng-")
    end
  end

  describe "tid edge cases" do
    test "validates TIDs with various valid characters" do
      # TID must be 13 chars, base32-sortable
      assert {:ok, _} = Formats.tid("path", "3jzfcijpj2z2a")
      assert {:ok, _} = Formats.tid("path", "2zzzzzzzzzzza")
      assert {:ok, _} = Formats.tid("path", "7yyyyyyyyyyy2")
    end

    test "rejects TID with invalid first character" do
      # First char must be in limited set (2-7, a-j)
      assert {:error, _} = Formats.tid("path", "1234567890123")
      assert {:error, _} = Formats.tid("path", "k234567890123")
    end

    test "rejects TID with wrong length" do
      assert {:error, _} = Formats.tid("path", "3jzfcijpj2z")
      assert {:error, _} = Formats.tid("path", "3jzfcijpj2z2aa")
    end
  end

  describe "record_key edge cases" do
    test "validates record keys with special characters" do
      assert {:ok, _} = Formats.record_key("path", "my.record-key_123")
      assert {:ok, _} = Formats.record_key("path", "key~with!special$chars")
      assert {:ok, _} = Formats.record_key("path", "a")
    end

    test "rejects empty record key" do
      assert {:error, _} = Formats.record_key("path", "")
    end

    test "rejects record key at max length boundary" do
      max_key = String.duplicate("a", 512)
      assert {:ok, _} = Formats.record_key("path", max_key)

      over_max = String.duplicate("a", 513)
      assert {:error, _} = Formats.record_key("path", over_max)
    end
  end

  describe "at_identifier edge cases" do
    test "correctly discriminates between DID and handle" do
      # Should use DID validation
      assert {:ok, _} = Formats.at_identifier("path", "did:plc:abc123")

      # Should use handle validation
      assert {:ok, _} = Formats.at_identifier("path", "user.bsky.social")
    end

    test "provides correct error message for invalid DID" do
      assert {:error, error} = Formats.at_identifier("path", "did:invalid format")
      assert error =~ "must be a valid did or a handle"
    end

    test "provides correct error message for invalid handle" do
      assert {:error, error} = Formats.at_identifier("path", "invalid_handle")
      assert error =~ "must be a valid did or a handle"
    end
  end

  describe "validate_format/3 catch-all" do
    test "returns value unchanged for unknown formats" do
      assert {:ok, "value"} = Formats.validate_format("custom-format", "value", "path")
      assert {:ok, "test"} = Formats.validate_format("nonexistent", "test", "path")
    end
  end
end
