defmodule AetherLexicon.Validation.FormatsTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation.Formats

  describe "datetime/2" do
    test "validates valid ISO 8601 datetime" do
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00Z")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00.123Z")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00+00:00")
      assert {:ok, _} = Formats.datetime("path", "2024-01-15T10:30:00-05:00")
    end

    test "rejects invalid datetime format" do
      assert {:error, error} = Formats.datetime("path", "not-a-date")
      assert error =~ "must be an valid atproto datetime"

      assert {:error, _} = Formats.datetime("path", "2024-01-15")
      assert {:error, _} = Formats.datetime("path", "10:30:00")
    end
  end

  describe "uri/2" do
    test "validates valid URIs" do
      assert {:ok, _} = Formats.uri("path", "https://example.com")
      assert {:ok, _} = Formats.uri("path", "http://example.com/path")
      assert {:ok, _} = Formats.uri("path", "ftp://file.server.com")
      assert {:ok, _} = Formats.uri("path", "custom:something")
    end

    test "rejects invalid URI format" do
      assert {:error, error} = Formats.uri("path", "not a uri")
      assert error =~ "must be a uri"

      assert {:error, _} = Formats.uri("path", "://noscheme")
      assert {:error, _} = Formats.uri("path", "")
    end
  end

  describe "at_uri/2" do
    test "validates valid AT URIs" do
      assert {:ok, _} = Formats.at_uri("path", "at://did:plc:abc123/app.bsky.feed.post/3k2y")
      assert {:ok, _} =
               Formats.at_uri("path", "at://user.bsky.social/app.bsky.feed.post/record123")
    end

    test "rejects invalid AT URI format" do
      assert {:error, error} = Formats.at_uri("path", "https://example.com")
      assert error =~ "must be a valid at-uri"

      assert {:error, _} = Formats.at_uri("path", "at://")
      assert {:error, _} = Formats.at_uri("path", "not-an-at-uri")
    end
  end

  describe "did/2" do
    test "validates valid DIDs" do
      assert {:ok, _} = Formats.did("path", "did:plc:abc123xyz")
      assert {:ok, _} = Formats.did("path", "did:web:example.com")
      assert {:ok, _} = Formats.did("path", "did:key:z6MkhaXg")
    end

    test "rejects invalid DID format" do
      assert {:error, error} = Formats.did("path", "not-a-did")
      assert error =~ "must be a valid did"

      assert {:error, _} = Formats.did("path", "did:")
      assert {:error, _} = Formats.did("path", "did:method:")
    end
  end

  describe "handle/2" do
    test "validates valid handles" do
      assert {:ok, _} = Formats.handle("path", "user.bsky.social")
      assert {:ok, _} = Formats.handle("path", "example.com")
      assert {:ok, _} = Formats.handle("path", "sub.domain.example.com")
    end

    test "rejects invalid handle format" do
      assert {:error, error} = Formats.handle("path", "not_a_handle")
      assert error =~ "must be a valid handle"

      assert {:error, _} = Formats.handle("path", "no-tld")
      assert {:error, _} = Formats.handle("path", ".starts-with-dot.com")
      assert {:error, _} = Formats.handle("path", "ends-with-dot.com.")

      # Too long
      long_handle = String.duplicate("a", 254)
      assert {:error, _} = Formats.handle("path", long_handle)
    end
  end

  describe "at_identifier/2" do
    test "validates DIDs" do
      assert {:ok, _} = Formats.at_identifier("path", "did:plc:abc123")
    end

    test "validates handles" do
      assert {:ok, _} = Formats.at_identifier("path", "user.bsky.social")
    end

    test "rejects invalid identifiers" do
      assert {:error, error} = Formats.at_identifier("path", "not-valid")
      assert error =~ "must be a valid did or a handle"
    end
  end

  describe "nsid/2" do
    test "validates valid NSIDs" do
      assert {:ok, _} = Formats.nsid("path", "com.example.type")
      assert {:ok, _} = Formats.nsid("path", "app.bsky.feed.post")
      assert {:ok, _} = Formats.nsid("path", "com.atproto.server.createSession")
    end

    test "rejects invalid NSID format" do
      assert {:error, error} = Formats.nsid("path", "not.valid")
      assert error =~ "must be a valid nsid"

      # Too few segments
      assert {:error, _} = Formats.nsid("path", "onlyone")
      assert {:error, _} = Formats.nsid("path", "only.two")

      # Invalid characters (underscore not allowed)
      assert {:error, _} = Formats.nsid("path", "com.ex_ample.type")

      # Too long
      long_nsid = "com.example." <> String.duplicate("a", 310)
      assert {:error, _} = Formats.nsid("path", long_nsid)

      # Cannot start with digit
      assert {:error, _} = Formats.nsid("path", "1com.example.type")
    end
  end

  describe "cid/2" do
    test "validates valid CIDs" do
      # CIDv0 format (starts with Qm, 46 chars total)
      assert {:ok, _} = Formats.cid("path", "QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N")

      # CIDv1 base32 format
      assert {:ok, _} = Formats.cid("path", "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
    end

    test "rejects invalid CID format" do
      assert {:error, error} = Formats.cid("path", "not-a-cid")
      assert error =~ "must be a cid string"

      assert {:error, _} = Formats.cid("path", "Qm123")
      assert {:error, _} = Formats.cid("path", "")
    end
  end

  describe "language/2" do
    test "validates valid BCP 47 language tags" do
      assert {:ok, _} = Formats.language("path", "en")
      assert {:ok, _} = Formats.language("path", "en-US")
      assert {:ok, _} = Formats.language("path", "zh-Hans-CN")
      assert {:ok, _} = Formats.language("path", "pt-BR")
      assert {:ok, _} = Formats.language("path", "es-419")
    end

    test "rejects invalid language tags" do
      assert {:error, error} = Formats.language("path", "not_valid")
      assert error =~ "must be a well-formed BCP 47 language tag"

      assert {:error, _} = Formats.language("path", "EN")
      assert {:error, _} = Formats.language("path", "e")
    end
  end

  describe "tid/2" do
    test "validates valid TIDs" do
      # TID is 13 character base32-sortable timestamp
      assert {:ok, _} = Formats.tid("path", "3jzfcijpj2z2a")
      assert {:ok, _} = Formats.tid("path", "3k2y4prq5jk2p")
    end

    test "rejects invalid TID format" do
      assert {:error, error} = Formats.tid("path", "not-a-tid")
      assert error =~ "must be a valid TID"

      assert {:error, _} = Formats.tid("path", "too-short")
      assert {:error, _} = Formats.tid("path", "UPPERCASE123")
      assert {:error, _} = Formats.tid("path", "123456789abcd")
    end
  end

  describe "record_key/2" do
    test "validates valid record keys" do
      assert {:ok, _} = Formats.record_key("path", "3jzfcijpj2z2a")
      assert {:ok, _} = Formats.record_key("path", "self")
      assert {:ok, _} = Formats.record_key("path", "my-record.key_123")
    end

    test "rejects invalid record keys" do
      assert {:error, error} = Formats.record_key("path", "")
      assert error =~ "must be a valid Record Key"

      # Too long
      long_key = String.duplicate("a", 513)
      assert {:error, _} = Formats.record_key("path", long_key)
    end
  end

  describe "validate_format/3" do
    test "routes to correct validator based on format string" do
      assert {:ok, _} = Formats.validate_format("datetime", "2024-01-15T10:30:00Z", "path")
      assert {:ok, _} = Formats.validate_format("uri", "https://example.com", "path")
      assert {:ok, _} = Formats.validate_format("did", "did:plc:abc123", "path")
    end

    test "returns ok for unknown format" do
      assert {:ok, "value"} = Formats.validate_format("unknown-format", "value", "path")
    end
  end
end
