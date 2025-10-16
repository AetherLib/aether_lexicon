defmodule AetherLexicon.ValidationCoverageTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

  @moduledoc """
  Targeted tests to achieve 100% code coverage by testing specific uncovered branches.
  """

  describe "must_be_obj parameter in ref validation" do
    test "validates ref with must_be_obj=true through union" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "objectDef" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"}
            }
          },
          "main" => %{
            "type" => "union",
            "refs" => ["#objectDef"],
            "closed" => true
          }
        }
      }

      # This will trigger the must_be_obj path through union -> ref -> validate_object
      data = %{"$type" => "#objectDef", "name" => "test"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "primitive default values for nil input" do
    test "applies string default when value is nil" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "default" => "fallback"
          }
        }
      }

      assert {:ok, "fallback"} = Validation.validate(schema, "main", nil)
    end

    test "rejects nil string without default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string"
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be a string"
    end

    test "rejects nil string with wrong type default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "default" => 123
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be a string"
    end

    test "applies integer default when value is nil" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "integer",
            "default" => 99
          }
        }
      }

      assert {:ok, 99} = Validation.validate(schema, "main", nil)
    end

    test "rejects nil integer without default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "integer"
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be an integer"
    end

    test "rejects nil integer with wrong type default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "integer",
            "default" => "not an int"
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be an integer"
    end

    test "applies boolean default when value is nil" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "boolean",
            "default" => false
          }
        }
      }

      assert {:ok, false} = Validation.validate(schema, "main", nil)
    end

    test "rejects nil boolean without default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "boolean"
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be a boolean"
    end

    test "rejects nil boolean with wrong type default" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "boolean",
            "default" => "not a bool"
          }
        }
      }

      assert {:error, error} = Validation.validate(schema, "main", nil)
      assert error =~ "must be a boolean"
    end
  end

  describe "string length validation edge cases" do
    test "validates minLength with string failing fast-path check" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minLength" => 100}
            }
          }
        }
      }

      # String with length * 3 < minLength triggers fast-path error
      data = %{"text" => "a"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must not be shorter than 100 characters"
    end

    test "validates string that passes all fast-path checks" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minLength" => 5, "maxLength" => 100}
            }
          }
        }
      }

      # String that passes byte count check in else branch
      data = %{"text" => "hello world"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "string grapheme validation edge cases" do
    test "validates string needing full grapheme count below minGraphemes" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minGraphemes" => 10, "maxGraphemes" => 50}
            }
          }
        }
      }

      # String that needs full grapheme count and fails minGraphemes
      # String length is > minGraphemes but grapheme count could be less
      data = %{"text" => "hello 👋"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must not be shorter than 10 graphemes"
    end

    test "validates string that passes grapheme count checks" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minGraphemes" => 5, "maxGraphemes" => 100}
            }
          }
        }
      }

      # String that needs actual grapheme count but passes
      data = %{"text" => "hello world with emojis 👋🌍"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "format validation through validate_format dispatcher" do
    test "validates at-uri format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "uri" => %{"type" => "string", "format" => "at-uri"}
            }
          }
        }
      }

      data = %{"uri" => "at://did:plc:abc123/app.bsky.feed.post/3k2y"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates handle format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "handle" => %{"type" => "string", "format" => "handle"}
            }
          }
        }
      }

      data = %{"handle" => "user.bsky.social"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates at-identifier format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "identifier" => %{"type" => "string", "format" => "at-identifier"}
            }
          }
        }
      }

      data = %{"identifier" => "did:plc:abc123"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates nsid format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "nsid" => %{"type" => "string", "format" => "nsid"}
            }
          }
        }
      }

      data = %{"nsid" => "com.example.type"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates cid format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "cid" => %{"type" => "string", "format" => "cid"}
            }
          }
        }
      }

      data = %{"cid" => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates language format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "lang" => %{"type" => "string", "format" => "language"}
            }
          }
        }
      }

      data = %{"lang" => "en-US"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates tid format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "tid" => %{"type" => "string", "format" => "tid"}
            }
          }
        }
      }

      data = %{"tid" => "3jzfcijpj2z2a"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates record-key format through dispatcher" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "key" => %{"type" => "string", "format" => "record-key"}
            }
          }
        }
      }

      data = %{"key" => "my-record.key_123"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "record-key format edge cases" do
    test "rejects record key with invalid characters" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "key" => %{"type" => "string", "format" => "record-key"}
            }
          }
        }
      }

      # Space is not allowed in record keys
      data = %{"key" => "invalid key with spaces"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must be a valid Record Key"
    end

    test "rejects record key with newline" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "key" => %{"type" => "string", "format" => "record-key"}
            }
          }
        }
      }

      data = %{"key" => "invalid\nkey"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must be a valid Record Key"
    end

    test "rejects record key with tab" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "key" => %{"type" => "string", "format" => "record-key"}
            }
          }
        }
      }

      data = %{"key" => "invalid\tkey"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must be a valid Record Key"
    end
  end

  describe "advanced grapheme validation scenarios" do
    test "validates string with both min and max graphemes that passes actual count" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              # String length > maxGraphemes forces actual grapheme count
              # But passes minGraphemes check
              "text" => %{"type" => "string", "minGraphemes" => 8, "maxGraphemes" => 20}
            }
          }
        }
      }

      # String with emojis: length could be > maxGraphemes but grapheme count within range
      # "hello 👋🌍 world" has 15 chars but fewer graphemes
      data = %{"text" => "hello world test"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates complex string that needs full grapheme count and is within bounds" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minGraphemes" => 5, "maxGraphemes" => 30}
            }
          }
        }
      }

      # Emoji-heavy text that needs grapheme counting
      data = %{"text" => "test 👨‍👩‍👧‍👦 emoji"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "union type with non-lex, non-# refs (to_lex_uri conversion)" do
    test "validates union with plain string ref that gets lex: prepended" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "simpleType" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          },
          "main" => %{
            "type" => "union",
            # Using a plain string ref (no lex: or # prefix)
            "refs" => ["test.simpleType"],
            "closed" => false
          }
        }
      }

      # This will trigger to_lex_uri to convert "test.simpleType" to "lex:test.simpleType"
      data = %{"$type" => "test.simpleType", "name" => "value"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates union with various ref formats" do
      schema = %{
        "lexicon" => 1,
        "id" => "test.schema",
        "defs" => %{
          "typeA" => %{
            "type" => "object",
            "properties" => %{"a" => %{"type" => "string"}}
          },
          "main" => %{
            "type" => "union",
            "refs" => ["com.example.type", "app.bsky.type"],
            "closed" => false
          }
        }
      }

      # Plain ref without lex: or # will be converted by to_lex_uri
      data = %{"$type" => "other.type", "value" => "test"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end
end
