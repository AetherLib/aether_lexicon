defmodule AetherLexicon.ValidationAdvancedTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

  # Helper function to load schema from JSON file
  defp load_schema(path) do
    case File.read(path) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, schema} -> {:ok, schema}
          {:error, error} -> {:error, "Failed to parse JSON: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  # Create a test schema with various features
  defp test_schema do
    %{
      "lexicon" => 1,
      "id" => "test.schema",
      "defs" => %{
        "main" => %{
          "type" => "object",
          "required" => ["required_field"],
          "properties" => %{
            "required_field" => %{"type" => "string"}
          }
        },
        "withDefaults" => %{
          "type" => "object",
          "properties" => %{
            "stringWithDefault" => %{"type" => "string", "default" => "default_value"},
            "intWithDefault" => %{"type" => "integer", "default" => 42},
            "boolWithDefault" => %{"type" => "boolean", "default" => true}
          }
        },
        "withNullable" => %{
          "type" => "object",
          "nullable" => ["nullableField"],
          "properties" => %{
            "nullableField" => %{"type" => "string"}
          }
        },
        "withEnum" => %{
          "type" => "object",
          "properties" => %{
            "stringEnum" => %{"type" => "string", "enum" => ["option1", "option2", "option3"]},
            "intEnum" => %{"type" => "integer", "enum" => [1, 2, 3]}
          }
        },
        "withConst" => %{
          "type" => "object",
          "properties" => %{
            "stringConst" => %{"type" => "string", "const" => "fixed_value"},
            "intConst" => %{"type" => "integer", "const" => 100},
            "boolConst" => %{"type" => "boolean", "const" => true}
          }
        },
        "arrayDef" => %{
          "type" => "object",
          "properties" => %{
            "items" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "minLength" => 1,
              "maxLength" => 5
            }
          }
        },
        "arrayWithRefs" => %{
          "type" => "object",
          "properties" => %{
            "refs" => %{
              "type" => "array",
              "items" => %{"type" => "ref", "ref" => "#simpleObject"}
            }
          }
        },
        "simpleObject" => %{
          "type" => "object",
          "required" => ["name"],
          "properties" => %{
            "name" => %{"type" => "string"}
          }
        },
        "withRef" => %{
          "type" => "object",
          "properties" => %{
            "refField" => %{"type" => "ref", "ref" => "#simpleObject"}
          }
        },
        "openUnion" => %{
          "type" => "union",
          "refs" => ["#simpleObject"],
          "closed" => false
        },
        "closedUnion" => %{
          "type" => "union",
          "refs" => ["#simpleObject"],
          "closed" => true
        }
      }
    }
  end

  describe "default values" do
    test "applies string default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = Validation.validate(schema, "withDefaults", data)
      assert result["stringWithDefault"] == "default_value"
    end

    test "applies integer default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = Validation.validate(schema, "withDefaults", data)
      assert result["intWithDefault"] == 42
    end

    test "applies boolean default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = Validation.validate(schema, "withDefaults", data)
      assert result["boolWithDefault"] == true
    end

    test "does not override provided values with defaults" do
      schema = test_schema()
      data = %{"stringWithDefault" => "custom", "intWithDefault" => 99}

      assert {:ok, result} = Validation.validate(schema, "withDefaults", data)
      assert result["stringWithDefault"] == "custom"
      assert result["intWithDefault"] == 99
    end
  end

  describe "nullable fields" do
    test "accepts null for nullable field" do
      schema = test_schema()
      data = %{"nullableField" => nil}

      assert {:ok, _} = Validation.validate(schema, "withNullable", data)
    end

    test "accepts value for nullable field" do
      schema = test_schema()
      data = %{"nullableField" => "some value"}

      assert {:ok, _} = Validation.validate(schema, "withNullable", data)
    end
  end

  describe "enum validation" do
    test "accepts valid string enum value" do
      schema = test_schema()
      data = %{"stringEnum" => "option2"}

      assert {:ok, _} = Validation.validate(schema, "withEnum", data)
    end

    test "rejects invalid string enum value" do
      schema = test_schema()
      data = %{"stringEnum" => "invalid_option"}

      assert {:error, error} = Validation.validate(schema, "withEnum", data)
      assert error =~ "must be one of"
    end

    test "accepts valid integer enum value" do
      schema = test_schema()
      data = %{"intEnum" => 2}

      assert {:ok, _} = Validation.validate(schema, "withEnum", data)
    end

    test "rejects invalid integer enum value" do
      schema = test_schema()
      data = %{"intEnum" => 99}

      assert {:error, error} = Validation.validate(schema, "withEnum", data)
      assert error =~ "must be one of"
    end
  end

  describe "const validation" do
    test "accepts matching const string value" do
      schema = test_schema()
      data = %{"stringConst" => "fixed_value"}

      assert {:ok, _} = Validation.validate(schema, "withConst", data)
    end

    test "rejects non-matching const string value" do
      schema = test_schema()
      data = %{"stringConst" => "wrong_value"}

      assert {:error, error} = Validation.validate(schema, "withConst", data)
      assert error =~ "must be fixed_value"
    end

    test "accepts matching const integer value" do
      schema = test_schema()
      data = %{"intConst" => 100}

      assert {:ok, _} = Validation.validate(schema, "withConst", data)
    end

    test "rejects non-matching const integer value" do
      schema = test_schema()
      data = %{"intConst" => 99}

      assert {:error, error} = Validation.validate(schema, "withConst", data)
      assert error =~ "must be 100"
    end

    test "accepts matching const boolean value" do
      schema = test_schema()
      data = %{"boolConst" => true}

      assert {:ok, _} = Validation.validate(schema, "withConst", data)
    end

    test "rejects non-matching const boolean value" do
      schema = test_schema()
      data = %{"boolConst" => false}

      assert {:error, error} = Validation.validate(schema, "withConst", data)
      assert error =~ "must be true"
    end
  end

  describe "array validation" do
    test "validates array with string items" do
      schema = test_schema()
      data = %{"items" => ["one", "two", "three"]}

      assert {:ok, _} = Validation.validate(schema, "arrayDef", data)
    end

    test "rejects array with non-string items" do
      schema = test_schema()
      data = %{"items" => ["one", 2, "three"]}

      assert {:error, error} = Validation.validate(schema, "arrayDef", data)
      assert error =~ "must be a string"
    end

    test "validates array minLength constraint" do
      schema = test_schema()
      data = %{"items" => []}

      assert {:error, error} = Validation.validate(schema, "arrayDef", data)
      assert error =~ "must not have fewer than 1 elements"
    end

    test "validates array maxLength constraint" do
      schema = test_schema()
      data = %{"items" => ["a", "b", "c", "d", "e", "f"]}

      assert {:error, error} = Validation.validate(schema, "arrayDef", data)
      assert error =~ "must not have more than 5 elements"
    end

    test "rejects non-array value" do
      schema = test_schema()
      data = %{"items" => "not an array"}

      assert {:error, error} = Validation.validate(schema, "arrayDef", data)
      assert error =~ "must be an array"
    end
  end

  describe "array with refs" do
    test "validates array items against referenced definition" do
      schema = test_schema()

      data = %{
        "refs" => [
          %{"name" => "item1"},
          %{"name" => "item2"}
        ]
      }

      assert {:ok, _} = Validation.validate(schema, "arrayWithRefs", data)
    end

    test "rejects invalid items in ref array" do
      schema = test_schema()

      data = %{
        "refs" => [
          %{"name" => "item1"},
          %{}
          # missing required 'name'
        ]
      }

      assert {:error, error} = Validation.validate(schema, "arrayWithRefs", data)
      assert error =~ "must have the property"
    end
  end

  describe "ref validation" do
    test "validates object against referenced definition" do
      schema = test_schema()
      data = %{"refField" => %{"name" => "test"}}

      assert {:ok, _} = Validation.validate(schema, "withRef", data)
    end

    test "rejects invalid object in ref field" do
      schema = test_schema()
      data = %{"refField" => %{}}

      assert {:error, error} = Validation.validate(schema, "withRef", data)
      assert error =~ "must have the property"
    end
  end

  describe "union validation - open" do
    test "accepts known type with $type field" do
      schema = test_schema()
      data = %{"$type" => "#simpleObject", "name" => "test"}

      assert {:ok, _} = Validation.validate(schema, "openUnion", data)
    end

    test "accepts unknown type in open union" do
      schema = test_schema()
      data = %{"$type" => "#unknownType", "data" => "anything"}

      assert {:ok, _} = Validation.validate(schema, "openUnion", data)
    end

    test "rejects missing $type field" do
      schema = test_schema()
      data = %{"name" => "test"}

      assert {:error, error} = Validation.validate(schema, "openUnion", data)
      assert error =~ "must be an object which includes the \"$type\" property"
    end
  end

  describe "union validation - closed" do
    test "accepts known type with $type field" do
      schema = test_schema()
      data = %{"$type" => "#simpleObject", "name" => "test"}

      assert {:ok, _} = Validation.validate(schema, "closedUnion", data)
    end

    test "rejects unknown type in closed union" do
      schema = test_schema()
      data = %{"$type" => "#unknownType", "data" => "anything"}

      assert {:error, error} = Validation.validate(schema, "closedUnion", data)
      assert error =~ "$type must be one of"
    end
  end

  describe "bytes validation" do
    test "validates bytes type with binary data" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "bytes", "maxLength" => 100}
            }
          }
        }
      }

      data = %{"data" => <<1, 2, 3, 4, 5>>}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates bytes maxLength constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "bytes", "maxLength" => 5}
            }
          }
        }
      }

      data = %{"data" => <<1, 2, 3, 4, 5, 6>>}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must not be larger than 5 bytes"
    end

    test "validates bytes minLength constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "bytes", "minLength" => 10}
            }
          }
        }
      }

      data = %{"data" => <<1, 2, 3>>}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must not be smaller than 10 bytes"
    end
  end

  describe "cid-link validation" do
    test "validates valid CID string" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "cid" => %{"type" => "cid-link"}
            }
          }
        }
      }

      data = %{"cid" => "QmYyQSo1c1Ym7orWxLYvCrM2EmxFTANf8wXmmE7DWjhx5N"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "rejects invalid CID" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "cid" => %{"type" => "cid-link"}
            }
          }
        }
      }

      data = %{"cid" => "not-a-cid"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must be a CID"
    end
  end

  describe "unknown type validation" do
    test "accepts any object for unknown type" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "unknown"}
            }
          }
        }
      }

      data = %{"data" => %{"anything" => "goes", "nested" => %{"data" => 123}}}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "rejects non-object for unknown type" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "unknown"}
            }
          }
        }
      }

      data = %{"data" => "not an object"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must be an object"
    end
  end

  describe "blob validation" do
    test "validates blob with $type field" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "image" => %{"type" => "blob"}
            }
          }
        }
      }

      data = %{
        "image" => %{
          "$type" => "blob",
          "ref" => %{"$link" => "bafyxyz"},
          "mimeType" => "image/jpeg",
          "size" => 12345
        }
      }

      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates blob with ref and mimeType" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "image" => %{"type" => "blob"}
            }
          }
        }
      }

      data = %{
        "image" => %{
          "ref" => "bafyxyz",
          "mimeType" => "image/png"
        }
      }

      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "rejects invalid blob structure" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "image" => %{"type" => "blob"}
            }
          }
        }
      }

      data = %{"image" => %{"something" => "else"}}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "should be a blob ref"
    end
  end

  describe "token validation" do
    test "accepts any value for token type" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "marker" => %{"type" => "token"}
            }
          }
        }
      }

      data = %{"marker" => "anything"}
      assert {:ok, result} = Validation.validate(schema, "main", data)
      # Token type returns nil
      assert result["marker"] == nil
    end
  end

  describe "record type validation" do
    test "validates record type with nested object" do
      {:ok, schema} = load_schema("priv/spec/app/bsky/feed/post.json")

      # Valid post record
      data = %{
        "text" => "Hello, world!",
        "createdAt" => "2024-01-15T10:30:00Z"
      }

      # The 'main' def is a record type with a nested 'record' object
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "string graphemes validation" do
    test "validates maxGraphemes constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "maxGraphemes" => 10}
            }
          }
        }
      }

      # String with exactly 10 graphemes
      data = %{"text" => "1234567890"}
      assert {:ok, _} = Validation.validate(schema, "main", data)

      # String with more than 10 graphemes
      long_data = %{"text" => "12345678901"}
      assert {:error, error} = Validation.validate(schema, "main", long_data)
      assert error =~ "must not be longer than 10 graphemes"
    end

    test "validates minGraphemes constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minGraphemes" => 5}
            }
          }
        }
      }

      # String shorter than minGraphemes
      data = %{"text" => "1234"}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "must not be shorter than 5 graphemes"
    end
  end

  describe "integer range validation" do
    test "validates minimum constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "count" => %{"type" => "integer", "minimum" => 0}
            }
          }
        }
      }

      data = %{"count" => -1}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "can not be less than 0"
    end

    test "validates maximum constraint" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "count" => %{"type" => "integer", "maximum" => 100}
            }
          }
        }
      }

      data = %{"count" => 101}
      assert {:error, error} = Validation.validate(schema, "main", data)
      assert error =~ "can not be greater than 100"
    end
  end

  describe "error cases" do
    test "returns error for non-existent definition" do
      schema = test_schema()

      assert {:error, error} = Validation.validate(schema, "nonExistent", %{})
      assert error =~ "not found in schema"
    end

    test "returns error for invalid schema structure" do
      invalid_schema = %{"lexicon" => 1, "id" => "test"}

      assert {:error, error} = Validation.validate(invalid_schema, "main", %{})
      assert error =~ "missing 'defs' field"
    end
  end
end
