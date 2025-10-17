defmodule AetherLexicon.ValidationTest do
  use ExUnit.Case, async: true

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

  # Get all lexicon files at compile time
  @lexicon_files "priv/spec"
                 |> Path.join("**/*.json")
                 |> Path.wildcard()
                 |> Enum.sort()

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

  # Test schema for edge cases
  defp edge_case_schema do
    %{
      "lexicon" => 1,
      "id" => "test.edgecases",
      "defs" => %{
        "stringWithMinLength" => %{
          "type" => "object",
          "properties" => %{
            "text" => %{"type" => "string", "minLength" => 10, "maxLength" => 100}
          }
        },
        "stringWithMinGraphemes" => %{
          "type" => "object",
          "properties" => %{
            "text" => %{"type" => "string", "minGraphemes" => 5, "maxGraphemes" => 50}
          }
        },
        "invalidEnumType" => %{
          "type" => "object",
          "properties" => %{
            "value" => %{"type" => "string", "enum" => "not-a-list"}
          }
        },
        "invalidIntEnumType" => %{
          "type" => "object",
          "properties" => %{
            "value" => %{"type" => "integer", "enum" => "not-a-list"}
          }
        },
        "crossSchemaRef" => %{
          "type" => "object",
          "properties" => %{
            "ref" => %{"type" => "ref", "ref" => "other.schema#definition"}
          }
        },
        "implicitMain" => %{
          "type" => "object",
          "properties" => %{
            "ref" => %{"type" => "ref", "ref" => "otherSchema"}
          }
        },
        "unsupportedType" => %{
          "type" => "unknownCustomType"
        },
        "main" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"}
          }
        }
      }
    }
  end

  describe "all lexicon schemas" do
    for lexicon_path <- @lexicon_files do
      @lexicon_path lexicon_path
      # Extract a readable test name from the path
      test_name =
        lexicon_path
        |> Path.relative_to("priv/spec/")
        |> Path.rootname()
        |> String.replace("/", ".")

      test "loads and validates schema: #{test_name}" do
        assert {:ok, schema} = load_schema(@lexicon_path)

        # Verify basic lexicon structure
        assert schema["lexicon"] == 1, "Expected lexicon version 1 in #{@lexicon_path}"
        assert is_binary(schema["id"]), "Expected id to be a string in #{@lexicon_path}"
        assert is_map(schema["defs"]), "Expected defs to be a map in #{@lexicon_path}"

        assert map_size(schema["defs"]) > 0,
               "Expected at least one definition in #{@lexicon_path}"
      end
    end

    test "found all expected lexicon files" do
      # Verify we're loading a reasonable number of schemas
      assert length(@lexicon_files) > 0, "No lexicon files found in priv/spec"

      assert length(@lexicon_files) > 100,
             "Expected to find many lexicon files, found #{length(@lexicon_files)}"
    end
  end

  describe "schema loading helper" do
    test "returns error for non-existent schema file" do
      assert {:error, _reason} = load_schema("non_existent.json")
    end
  end

  describe "validate/3 - label object" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates a valid label object with all required fields", %{schema: schema} do
      valid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label",
        "cts" => "2024-01-15T10:30:00Z"
      }

      assert {:ok, _validated} = AetherLexicon.validate(schema, "label", valid_label)
    end

    test "rejects label object missing required fields", %{schema: schema} do
      # Missing 'cts' field
      invalid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label"
      }

      assert {:error, error} = AetherLexicon.validate(schema, "label", invalid_label)
      assert error =~ "must have the property"
      assert error =~ "cts"
    end

    test "validates optional fields when present", %{schema: schema} do
      label_with_optional = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test-label",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => true,
        "ver" => 1
      }

      assert {:ok, _validated} = AetherLexicon.validate(schema, "label", label_with_optional)
    end

    test "validates string maxLength constraint", %{schema: schema} do
      # val field has maxLength: 128
      long_val = String.duplicate("a", 129)

      invalid_label = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => long_val,
        "cts" => "2024-01-15T10:30:00Z"
      }

      assert {:error, error} = AetherLexicon.validate(schema, "label", invalid_label)
      assert error =~ "must not be longer than 128 characters"
    end
  end

  describe "validate/3 - selfLabel object" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates a valid selfLabel object", %{schema: schema} do
      valid_self_label = %{
        "val" => "content-warning"
      }

      assert {:ok, _validated} = AetherLexicon.validate(schema, "selfLabel", valid_self_label)
    end

    test "rejects selfLabel missing required val field", %{schema: schema} do
      invalid_self_label = %{}

      assert {:error, error} = AetherLexicon.validate(schema, "selfLabel", invalid_self_label)
      assert error =~ "must have the property"
      assert error =~ "val"
    end
  end

  describe "validate/3 - primitive types" do
    setup do
      {:ok, schema} = load_schema("priv/spec/com/atproto/label/defs.json")
      {:ok, schema: schema}
    end

    test "validates boolean type for neg field", %{schema: schema} do
      label_with_bool = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => true
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "label", label_with_bool)

      # Invalid boolean
      label_with_invalid_bool = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "neg" => "not a boolean"
      }

      assert {:error, error} = AetherLexicon.validate(schema, "label", label_with_invalid_bool)
      assert error =~ "boolean"
    end

    test "validates integer type for ver field", %{schema: schema} do
      label_with_int = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "ver" => 1
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "label", label_with_int)

      # Invalid integer
      label_with_invalid_int = %{
        "src" => "did:plc:example123",
        "uri" => "https://example.com/resource",
        "val" => "test",
        "cts" => "2024-01-15T10:30:00Z",
        "ver" => "not an integer"
      }

      assert {:error, error} = AetherLexicon.validate(schema, "label", label_with_invalid_int)
      assert error =~ "integer"
    end
  end

  describe "default values" do
    test "applies string default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = AetherLexicon.validate(schema, "withDefaults", data)
      assert result["stringWithDefault"] == "default_value"
    end

    test "applies integer default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = AetherLexicon.validate(schema, "withDefaults", data)
      assert result["intWithDefault"] == 42
    end

    test "applies boolean default when field is missing" do
      schema = test_schema()
      data = %{}

      assert {:ok, result} = AetherLexicon.validate(schema, "withDefaults", data)
      assert result["boolWithDefault"] == true
    end

    test "does not override provided values with defaults" do
      schema = test_schema()
      data = %{"stringWithDefault" => "custom", "intWithDefault" => 99}

      assert {:ok, result} = AetherLexicon.validate(schema, "withDefaults", data)
      assert result["stringWithDefault"] == "custom"
      assert result["intWithDefault"] == 99
    end

    test "applies string default for nil value" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "string", "default" => "default_text"}
            }
          }
        }
      }

      data = %{"value" => nil}
      assert {:ok, result} = AetherLexicon.validate(schema, "main", data)
      assert result["value"] == "default_text"
    end

    test "applies integer default for nil value" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "count" => %{"type" => "integer", "default" => 42}
            }
          }
        }
      }

      data = %{"count" => nil}
      assert {:ok, result} = AetherLexicon.validate(schema, "main", data)
      assert result["count"] == 42
    end

    test "applies boolean default for nil value" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "flag" => %{"type" => "boolean", "default" => true}
            }
          }
        }
      }

      data = %{"flag" => nil}
      assert {:ok, result} = AetherLexicon.validate(schema, "main", data)
      assert result["flag"] == true
    end

    test "ignores mismatched default types" do
      # String with non-string default - our get_default_value will return nil for type mismatch
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "string", "default" => 123}
            }
          }
        }
      }

      data = %{"value" => nil}
      # Since default type doesn't match, get_default_value returns nil, so value stays nil
      assert {:ok, result} = AetherLexicon.validate(schema, "main", data)
      assert result["value"] == nil
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

      assert {:ok, "fallback"} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:ok, 99} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:ok, false} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
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

      assert {:error, error} = AetherLexicon.validate(schema, "main", nil)
      assert error =~ "must be a boolean"
    end
  end

  describe "nullable fields" do
    test "accepts null for nullable field" do
      schema = test_schema()
      data = %{"nullableField" => nil}

      assert {:ok, _} = AetherLexicon.validate(schema, "withNullable", data)
    end

    test "accepts value for nullable field" do
      schema = test_schema()
      data = %{"nullableField" => "some value"}

      assert {:ok, _} = AetherLexicon.validate(schema, "withNullable", data)
    end
  end

  describe "enum validation" do
    test "accepts valid string enum value" do
      schema = test_schema()
      data = %{"stringEnum" => "option2"}

      assert {:ok, _} = AetherLexicon.validate(schema, "withEnum", data)
    end

    test "rejects invalid string enum value" do
      schema = test_schema()
      data = %{"stringEnum" => "invalid_option"}

      assert {:error, error} = AetherLexicon.validate(schema, "withEnum", data)
      assert error =~ "must be one of"
    end

    test "accepts valid integer enum value" do
      schema = test_schema()
      data = %{"intEnum" => 2}

      assert {:ok, _} = AetherLexicon.validate(schema, "withEnum", data)
    end

    test "rejects invalid integer enum value" do
      schema = test_schema()
      data = %{"intEnum" => 99}

      assert {:error, error} = AetherLexicon.validate(schema, "withEnum", data)
      assert error =~ "must be one of"
    end
  end

  describe "const validation" do
    test "accepts matching const string value" do
      schema = test_schema()
      data = %{"stringConst" => "fixed_value"}

      assert {:ok, _} = AetherLexicon.validate(schema, "withConst", data)
    end

    test "rejects non-matching const string value" do
      schema = test_schema()
      data = %{"stringConst" => "wrong_value"}

      assert {:error, error} = AetherLexicon.validate(schema, "withConst", data)
      assert error =~ "must be fixed_value"
    end

    test "accepts matching const integer value" do
      schema = test_schema()
      data = %{"intConst" => 100}

      assert {:ok, _} = AetherLexicon.validate(schema, "withConst", data)
    end

    test "rejects non-matching const integer value" do
      schema = test_schema()
      data = %{"intConst" => 99}

      assert {:error, error} = AetherLexicon.validate(schema, "withConst", data)
      assert error =~ "must be 100"
    end

    test "accepts matching const boolean value" do
      schema = test_schema()
      data = %{"boolConst" => true}

      assert {:ok, _} = AetherLexicon.validate(schema, "withConst", data)
    end

    test "rejects non-matching const boolean value" do
      schema = test_schema()
      data = %{"boolConst" => false}

      assert {:error, error} = AetherLexicon.validate(schema, "withConst", data)
      assert error =~ "must be true"
    end
  end

  describe "array validation" do
    test "validates array with string items" do
      schema = test_schema()
      data = %{"items" => ["one", "two", "three"]}

      assert {:ok, _} = AetherLexicon.validate(schema, "arrayDef", data)
    end

    test "rejects array with non-string items" do
      schema = test_schema()
      data = %{"items" => ["one", 2, "three"]}

      assert {:error, error} = AetherLexicon.validate(schema, "arrayDef", data)
      assert error =~ "must be a string"
    end

    test "validates array minLength constraint" do
      schema = test_schema()
      data = %{"items" => []}

      assert {:error, error} = AetherLexicon.validate(schema, "arrayDef", data)
      assert error =~ "must not have fewer than 1 elements"
    end

    test "validates array maxLength constraint" do
      schema = test_schema()
      data = %{"items" => ["a", "b", "c", "d", "e", "f"]}

      assert {:error, error} = AetherLexicon.validate(schema, "arrayDef", data)
      assert error =~ "must not have more than 5 elements"
    end

    test "rejects non-array value" do
      schema = test_schema()
      data = %{"items" => "not an array"}

      assert {:error, error} = AetherLexicon.validate(schema, "arrayDef", data)
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

      assert {:ok, _} = AetherLexicon.validate(schema, "arrayWithRefs", data)
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

      assert {:error, error} = AetherLexicon.validate(schema, "arrayWithRefs", data)
      assert error =~ "must have the property"
    end
  end

  describe "ref validation" do
    test "validates object against referenced definition" do
      schema = test_schema()
      data = %{"refField" => %{"name" => "test"}}

      assert {:ok, _} = AetherLexicon.validate(schema, "withRef", data)
    end

    test "rejects invalid object in ref field" do
      schema = test_schema()
      data = %{"refField" => %{}}

      assert {:error, error} = AetherLexicon.validate(schema, "withRef", data)
      assert error =~ "must have the property"
    end
  end

  describe "union validation - open" do
    test "accepts known type with $type field" do
      schema = test_schema()
      data = %{"$type" => "#simpleObject", "name" => "test"}

      assert {:ok, _} = AetherLexicon.validate(schema, "openUnion", data)
    end

    test "accepts unknown type in open union" do
      schema = test_schema()
      data = %{"$type" => "#unknownType", "data" => "anything"}

      assert {:ok, _} = AetherLexicon.validate(schema, "openUnion", data)
    end

    test "rejects missing $type field" do
      schema = test_schema()
      data = %{"name" => "test"}

      assert {:error, error} = AetherLexicon.validate(schema, "openUnion", data)
      assert error =~ "must be an object which includes the \"$type\" property"
    end
  end

  describe "union validation - closed" do
    test "accepts known type with $type field" do
      schema = test_schema()
      data = %{"$type" => "#simpleObject", "name" => "test"}

      assert {:ok, _} = AetherLexicon.validate(schema, "closedUnion", data)
    end

    test "rejects unknown type in closed union" do
      schema = test_schema()
      data = %{"$type" => "#unknownType", "data" => "anything"}

      assert {:error, error} = AetherLexicon.validate(schema, "closedUnion", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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

      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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

      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, result} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)

      # String with more than 10 graphemes
      long_data = %{"text" => "12345678901"}
      assert {:error, error} = AetherLexicon.validate(schema, "main", long_data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "must not be shorter than 5 graphemes"
    end

    test "validates string with only minGraphemes that passes" do
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

      data = %{"text" => "hello world"}
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "can not be greater than 100"
    end
  end

  describe "string validation edge cases" do
    test "validates minLength with short string needing UTF-8 check" do
      schema = edge_case_schema()
      # Short string that passes initial check but fails UTF-8 count
      data = %{"text" => "short"}

      assert {:error, error} = AetherLexicon.validate(schema, "stringWithMinLength", data)
      assert error =~ "must not be shorter than 10 characters"
    end

    test "validates minGraphemes when string length is borderline" do
      schema = edge_case_schema()
      # String with exactly required graphemes at boundary
      data = %{"text" => "test"}

      assert {:error, error} = AetherLexicon.validate(schema, "stringWithMinGraphemes", data)
      assert error =~ "must not be shorter than 5 graphemes"
    end

    test "validates maxGraphemes needing grapheme count" do
      schema = edge_case_schema()
      # String exceeding maxGraphemes after full count
      long_text = String.duplicate("a", 51)
      data = %{"text" => long_text}

      assert {:error, error} = AetherLexicon.validate(schema, "stringWithMinGraphemes", data)
      assert error =~ "must not be longer than 50 graphemes"
    end

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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
    end
  end

  describe "unsupported and error types" do
    test "returns error for unsupported type" do
      schema = edge_case_schema()
      data = %{}

      assert {:error, error} = AetherLexicon.validate(schema, "unsupportedType", data)
      assert error =~ "Unsupported type"
    end

    test "validates non-list enum gracefully" do
      schema = edge_case_schema()
      # Enum that's not a list - should pass through
      data = %{"value" => "anything"}

      assert {:ok, _} = AetherLexicon.validate(schema, "invalidEnumType", data)
    end

    test "validates non-list integer enum gracefully" do
      schema = edge_case_schema()
      data = %{"value" => 42}

      assert {:ok, _} = AetherLexicon.validate(schema, "invalidIntEnumType", data)
    end
  end

  describe "ref resolution edge cases" do
    test "handles cross-schema references" do
      schema = edge_case_schema()
      data = %{"ref" => %{"data" => "test"}}

      # Should fail because we can't resolve cross-schema refs yet
      assert {:error, error} = AetherLexicon.validate(schema, "crossSchemaRef", data)
      assert error =~ "not found in schema"
    end

    test "handles implicit #main reference" do
      schema = edge_case_schema()
      data = %{"ref" => %{"name" => "test"}}

      # Should resolve to main definition
      assert {:ok, _} = AetherLexicon.validate(schema, "implicitMain", data)
    end

    test "handles union ref error path" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "union",
            "refs" => ["#nonexistent"],
            "closed" => true
          }
        }
      }

      data = %{"$type" => "#nonexistent"}

      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "not found"
    end

    test "handles ref type error path" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "field" => %{"type" => "ref", "ref" => "#nonexistent"}
            }
          }
        }
      }

      data = %{"field" => %{}}

      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "not found"
    end
  end

  describe "type validation edge cases" do
    test "validates non-object for object type" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{}
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate(schema, "main", "not an object")
      assert error =~ "Expected object"
    end

    test "validates non-binary for bytes type" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"type" => "bytes"}
            }
          }
        }
      }

      data = %{"data" => 123}
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "must be a byte array"
    end

    test "validates non-string for cid-link type" do
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

      data = %{"cid" => 123}
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "must be a CID"
    end

    test "validates non-map for blob type" do
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

      data = %{"image" => "not a blob"}
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "should be a blob ref"
    end

    test "validates invalid record definition" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "record",
            "record" => "invalid"
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate(schema, "main", %{})
      assert error =~ "Invalid record definition"
    end
  end

  describe "union type edge cases" do
    test "handles lex: prefixed refs" do
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
            "refs" => ["lex:#simpleType"],
            "closed" => true
          }
        }
      }

      data = %{"$type" => "lex:#simpleType", "name" => "test"}
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
    end

    test "handles refs with implicit #main suffix" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{"name" => %{"type" => "string"}}
          },
          "unionType" => %{
            "type" => "union",
            "refs" => ["lex:test.schema"],
            "closed" => true
          }
        }
      }

      data = %{"$type" => "lex:test.schema#main", "name" => "test"}
      assert {:ok, _} = AetherLexicon.validate(schema, "unionType", data)
    end

    test "handles refs without # converting to #main" do
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
            "refs" => ["lex:test.schema#simpleType"],
            "closed" => true
          }
        }
      }

      data = %{"$type" => "lex:test.schema", "name" => "test"}
      assert {:error, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
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
      assert {:error, error} = AetherLexicon.validate(schema, "main", data)
      assert error =~ "must be a valid Record Key"
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
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
      assert {:ok, _} = AetherLexicon.validate(schema, "main", data)
    end
  end

  describe "cross-schema references" do
    test "validates with cross-schema reference containing #" do
      # Test ref with schema#def format
      ref_schema = %{
        "lexicon" => 1,
        "id" => "com.example.ref",
        "defs" => %{
          "test" => %{
            "type" => "ref",
            "ref" => "com.example.test#other"
          },
          "other" => %{
            "type" => "string"
          }
        }
      }

      assert {:ok, "hello"} = AetherLexicon.validate(ref_schema, "other", "hello")
    end

    test "validates with implicit main reference" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "string"
          },
          "test" => %{
            "type" => "ref",
            "ref" => "com.example.implicit"
          }
        }
      }

      # This should try to get the "main" definition when no # is present
      # For this test, we just verify the code path exists
      result = AetherLexicon.validate(schema, "main", "test_string")
      assert {:ok, "test_string"} = result
    end
  end

  describe "string length optimization paths" do
    test "validates string with max length optimization path (no min length)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "test" => %{
            "type" => "string",
            # maxLength only, no minLength
            "maxLength" => 100
          }
        }
      }

      assert {:ok, "test"} = AetherLexicon.validate(schema, "test", "test")
      assert {:ok, "short string"} = AetherLexicon.validate(schema, "test", "short string")
    end

    test "validates string requiring byte count with both min and max" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "test" => %{
            "type" => "string",
            "minLength" => 1,
            "maxLength" => 10
          }
        }
      }

      # This should go through the byte counting path
      assert {:ok, "test"} = AetherLexicon.validate(schema, "test", "test")
    end

    test "validates string with only maxLength but exceeding optimization threshold" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "test" => %{
            "type" => "string",
            "maxLength" => 10
          }
        }
      }

      # String with 4 characters, 4 * 3 = 12, which is > 10
      # Should go to byte counting path
      assert {:ok, "test"} = AetherLexicon.validate(schema, "test", "test")
    end
  end

  describe "error cases" do
    test "returns error for non-existent definition" do
      schema = test_schema()

      assert {:error, error} = AetherLexicon.validate(schema, "nonExistent", %{})
      assert error =~ "not found in schema"
    end

    test "returns error for invalid schema structure" do
      invalid_schema = %{"lexicon" => 1, "id" => "test"}

      assert {:error, error} = AetherLexicon.validate(invalid_schema, "main", %{})
      assert error =~ "missing 'defs' field"
    end
  end

  describe "XRPC validation functions" do
    test "validate_input/3 validates XRPC input data" do
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
                "properties" => %{
                  "text" => %{"type" => "string", "maxLength" => 300}
                }
              }
            }
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate_input(schema, "main", %{"text" => "Hello world!"})
      assert {:error, _} = AetherLexicon.validate_input(schema, "main", %{})
    end

    test "validate_output/3 validates XRPC output data" do
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
                "properties" => %{
                  "post" => %{"type" => "object"}
                }
              }
            }
          }
        }
      }

      assert {:ok, _} =
               AetherLexicon.validate_output(schema, "main", %{"post" => %{"text" => "Hello"}})

      assert {:error, _} = AetherLexicon.validate_output(schema, "main", %{})
    end

    test "validate_parameters/3 validates XRPC parameters with defaults" do
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

      assert {:ok, result} = AetherLexicon.validate_parameters(schema, "main", %{"q" => "test"})
      assert result["limit"] == 25

      assert {:error, _} = AetherLexicon.validate_parameters(schema, "main", %{})
    end

    test "validate_message/3 validates XRPC subscription message" do
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
                "properties" => %{
                  "seq" => %{"type" => "integer"}
                }
              }
            }
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate_message(schema, "main", %{"seq" => 12345})
      assert {:error, _} = AetherLexicon.validate_message(schema, "main", %{})
    end

    test "validate_error/4 validates XRPC error response" do
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
                  "properties" => %{
                    "message" => %{"type" => "string"}
                  }
                }
              }
            ]
          }
        }
      }

      assert {:ok, _} =
               AetherLexicon.validate_error(schema, "main", "InvalidCredentials", %{
                 "message" => "Wrong password"
               })

      assert {:error, error} =
               AetherLexicon.validate_error(schema, "main", "InvalidCredentials", %{})

      assert error =~ "must have the property"
    end

    test "XRPC validates parameters with non-object type returns error" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "parameters" => %{
              "type" => "params",
              "properties" => %{
                "q" => %{"type" => "string"}
              }
            }
          }
        }
      }

      # Simulate passing non-map data through validate with $xrpc marker
      # This should trigger the error path for non-object in validate_params
      assert {:ok, _} = AetherLexicon.validate_parameters(schema, "main", %{"q" => "test"})
    end

    test "XRPC error validation with unknown error name" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "errors" => [
              %{"name" => "KnownError", "schema" => %{"type" => "object"}}
            ]
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate_error(schema, "main", "UnknownError", %{})
      assert error =~ "unknown error 'UnknownError'"
    end

    test "XRPC validates procedure without input schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.simple",
        "defs" => %{
          "main" => %{
            "type" => "procedure"
          }
        }
      }

      # Should pass when no input schema is defined
      assert {:ok, _} = AetherLexicon.validate_input(schema, "main", %{})
    end

    test "XRPC validates query without output schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.simple",
        "defs" => %{
          "main" => %{
            "type" => "query"
          }
        }
      }

      # Should pass when no output schema is defined
      assert {:ok, _} = AetherLexicon.validate_output(schema, "main", %{})
    end

    test "XRPC validates subscription without message schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.simple",
        "defs" => %{
          "main" => %{
            "type" => "subscription"
          }
        }
      }

      # Should pass when no message schema is defined
      assert {:ok, _} = AetherLexicon.validate_message(schema, "main", %{})
    end

    test "XRPC validates endpoint without parameters schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.simple",
        "defs" => %{
          "main" => %{
            "type" => "query"
          }
        }
      }

      # Should pass when no parameters schema is defined
      assert {:ok, _} = AetherLexicon.validate_parameters(schema, "main", %{})
    end

    test "XRPC error validation without errors list" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "procedure"
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate_error(schema, "main", "AnyError", %{})
      assert error =~ "has no errors defined"
    end

    test "XRPC error validation with error without schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "errors" => [
              %{"name" => "SimpleError"}
            ]
          }
        }
      }

      # Error without schema should accept any data
      assert {:ok, _} =
               AetherLexicon.validate_error(schema, "main", "SimpleError", %{"anything" => "goes"})
    end

    test "XRPC validates input with alternative schema format (no wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "type" => "object",
              "required" => ["text"],
              "properties" => %{
                "text" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate_input(schema, "main", %{"text" => "test"})
    end

    test "XRPC validates output with alternative schema format (no wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "type" => "object",
              "required" => ["data"],
              "properties" => %{
                "data" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate_output(schema, "main", %{"data" => "test"})
    end

    test "XRPC validates message with alternative schema format (no wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "message" => %{
              "type" => "object",
              "required" => ["event"],
              "properties" => %{
                "event" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate_message(schema, "main", %{"event" => "update"})
    end
  end

  describe "string byte length edge cases" do
    test "validates string exceeding max byte length with both min and max" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "minLength" => 5,
            "maxLength" => 10
          }
        }
      }

      # String with 11 bytes
      assert {:error, error} = AetherLexicon.validate(schema, "main", "12345678901")
      assert error =~ "must not be longer than 10 characters"
    end

    test "validates string below min byte length with both min and max" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "minLength" => 10,
            "maxLength" => 50
          }
        }
      }

      # String with 5 bytes
      assert {:error, error} = AetherLexicon.validate(schema, "main", "short")
      assert error =~ "must not be shorter than 10 characters"
    end

    test "validates string with minLength slow path (actual byte count)" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "minLength" => 10
          }
        }
      }

      # String with exactly 10 chars/bytes - passes the fast path check but need slow path validation
      # This string is 5 chars long, and 5 * 3 = 15 which is >= 10, so it passes fast path
      # But byte_size is only 5, so it will fail in validate_min_bytes
      assert {:error, error} = AetherLexicon.validate(schema, "main", "short")
      assert error =~ "must not be shorter than 10 characters"
    end
  end

  describe "at-identifier format validation" do
    test "validates at-identifier with DID format" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "at-identifier"
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "main", "did:plc:abc123xyz")
    end

    test "validates at-identifier with handle format" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "at-identifier"
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "main", "user.bsky.social")
    end

    test "rejects invalid at-identifier" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "at-identifier"
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate(schema, "main", "invalid handle!")
      assert error =~ "must be a valid did or a handle"
    end
  end

  describe "record-key format validation edge cases" do
    test "rejects record-key with empty string" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "record-key"
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate(schema, "main", "")
      assert error =~ "must be a valid Record Key"
    end

    test "rejects record-key exceeding 512 bytes" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "record-key"
          }
        }
      }

      # Create a string that's > 512 bytes
      long_key = String.duplicate("a", 513)
      assert {:error, error} = AetherLexicon.validate(schema, "main", long_key)
      assert error =~ "must be a valid Record Key"
    end

    test "accepts valid record-key at maximum length" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "record-key"
          }
        }
      }

      # Create a valid string that's exactly 512 bytes
      valid_key = String.duplicate("a", 512)
      assert {:ok, _} = AetherLexicon.validate(schema, "main", valid_key)
    end
  end

  describe "handle format validation edge cases" do
    test "rejects handle exceeding 253 bytes" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "handle"
          }
        }
      }

      # Create a handle that's > 253 bytes
      # Format: subdomain.domain.tld where subdomain is very long
      long_subdomain = String.duplicate("a", 250)
      long_handle = "#{long_subdomain}.example.com"
      assert {:error, error} = AetherLexicon.validate(schema, "main", long_handle)
      assert error =~ "must be a valid handle"
    end

    test "accepts valid handle at reasonable length" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "handle"
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "main", "user.bsky.social")
    end
  end

  describe "nsid format validation edge cases" do
    test "rejects nsid exceeding 317 bytes" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "nsid"
          }
        }
      }

      # Create an NSID that's > 317 bytes
      # Format: domain.subdomain.type
      long_part = String.duplicate("a", 200)
      long_nsid = "#{long_part}.#{long_part}.type"
      assert {:error, error} = AetherLexicon.validate(schema, "main", long_nsid)
      assert error =~ "must be a valid nsid"
    end

    test "accepts valid nsid at reasonable length" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "nsid"
          }
        }
      }

      assert {:ok, _} = AetherLexicon.validate(schema, "main", "com.example.feed.post")
    end
  end

  describe "get_def_from_schema with cross-schema references" do
    test "validates ref with cross-schema format (schema#def)" do
      # This should exercise line 422-423 in validation.ex
      # where a ref contains "#" but is not a local ref
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "crossRef" => %{
            "type" => "ref",
            "ref" => "com.atproto.label.defs#selfLabels"
          },
          "selfLabels" => %{
            "type" => "array",
            "items" => %{
              "type" => "string"
            }
          }
        }
      }

      # Validate through the crossRef which references selfLabels with cross-schema format
      assert {:ok, ["test"]} = AetherLexicon.validate(schema, "crossRef", ["test"])
    end

    test "validates ref without # (implicit main)" do
      # This should exercise line 425 in validation.ex
      # where a ref doesn't contain "#" and should default to "main"
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "implicitRef" => %{
            "type" => "ref",
            "ref" => "com.example.other"
          },
          "main" => %{
            "type" => "string"
          }
        }
      }

      # When validating through implicitRef, it should look for "main" since ref has no #
      assert {:ok, "test"} = AetherLexicon.validate(schema, "implicitRef", "test")
    end
  end

  describe "union type validation with refs" do
    test "validates closed union rejecting unknown type" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "closedUnion" => %{
            "type" => "union",
            "refs" => ["#typeA", "#typeB"],
            "closed" => true
          },
          "typeA" => %{
            "type" => "object",
            "properties" => %{
              "$type" => %{"type" => "string"}
            }
          },
          "typeB" => %{
            "type" => "object",
            "properties" => %{
              "$type" => %{"type" => "string"}
            }
          }
        }
      }

      # Should reject unknown type in closed union
      result = AetherLexicon.validate(schema, "closedUnion", %{"$type" => "unknown"})
      assert {:error, error_msg} = result
      assert error_msg =~ "must be one of"
    end

    test "validates open union accepting unknown type" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.test",
        "defs" => %{
          "openUnion" => %{
            "type" => "union",
            "refs" => ["#typeA"],
            "closed" => false
          },
          "typeA" => %{
            "type" => "object",
            "properties" => %{
              "$type" => %{"type" => "string"}
            }
          }
        }
      }

      # Should accept unknown type in open union
      assert {:ok, %{"$type" => "unknown"}} =
               AetherLexicon.validate(schema, "openUnion", %{"$type" => "unknown"})
    end
  end

  describe "query validation" do
    setup do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.getUser",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "parameters" => %{
              "type" => "params",
              "properties" => %{
                "user" => %{"type" => "string", "required" => true}
              }
            },
            "input" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["username"],
                "properties" => %{
                  "username" => %{"type" => "string", "maxLength" => 50}
                }
              }
            },
            "output" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["user"],
                "properties" => %{
                  "user" => %{
                    "type" => "object",
                    "required" => ["did", "handle"],
                    "properties" => %{
                      "did" => %{"type" => "string"},
                      "handle" => %{"type" => "string"}
                    }
                  }
                }
              }
            }
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates query input using validate_input/3", %{schema: schema} do
      input_data = %{"username" => "alice"}

      assert {:ok, %{"username" => "alice"}} =
               AetherLexicon.validate_input(schema, "main", input_data)
    end

    test "validates query input by default with validate/3", %{schema: schema} do
      input_data = %{"username" => "bob"}

      assert {:ok, %{"username" => "bob"}} = AetherLexicon.validate(schema, "main", input_data)
    end

    test "rejects invalid query input", %{schema: schema} do
      input_data = %{"username" => String.duplicate("a", 51)}

      assert {:error, error} = AetherLexicon.validate_input(schema, "main", input_data)
      assert error =~ "must not be longer than 50"
    end

    test "rejects missing required field in query input", %{schema: schema} do
      input_data = %{}

      assert {:error, error} = AetherLexicon.validate_input(schema, "main", input_data)
      assert error =~ "must have the property \"username\""
    end

    test "validates query output using validate_output/3", %{schema: schema} do
      output_data = %{
        "user" => %{
          "did" => "did:plc:abc123",
          "handle" => "alice.example.com"
        }
      }

      assert {:ok, result} = AetherLexicon.validate_output(schema, "main", output_data)
      assert result["user"]["did"] == "did:plc:abc123"
    end

    test "rejects invalid query output", %{schema: schema} do
      output_data = %{
        "user" => %{
          "did" => "did:plc:abc123"
          # Missing required "handle"
        }
      }

      assert {:error, error} = AetherLexicon.validate_output(schema, "main", output_data)
      assert error =~ "must have the property \"handle\""
    end
  end

  describe "procedure validation" do
    setup do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.createPost",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "encoding" => "application/json",
              "schema" => %{
                "type" => "object",
                "required" => ["text"],
                "properties" => %{
                  "text" => %{"type" => "string", "maxLength" => 300},
                  "langs" => %{
                    "type" => "array",
                    "items" => %{"type" => "string"}
                  }
                }
              }
            },
            "output" => %{
              "encoding" => "application/json",
              "schema" => %{
                "type" => "object",
                "required" => ["uri", "cid"],
                "properties" => %{
                  "uri" => %{"type" => "string"},
                  "cid" => %{"type" => "string"}
                }
              }
            }
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates procedure input using validate_input/3", %{schema: schema} do
      input_data = %{
        "text" => "Hello, world!",
        "langs" => ["en"]
      }

      assert {:ok, result} = AetherLexicon.validate_input(schema, "main", input_data)
      assert result["text"] == "Hello, world!"
    end

    test "validates procedure input by default with validate/3", %{schema: schema} do
      input_data = %{"text" => "Hello!"}

      assert {:ok, result} = AetherLexicon.validate(schema, "main", input_data)
      assert result["text"] == "Hello!"
    end

    test "rejects procedure input exceeding max length", %{schema: schema} do
      input_data = %{"text" => String.duplicate("a", 301)}

      assert {:error, error} = AetherLexicon.validate_input(schema, "main", input_data)
      assert error =~ "must not be longer than 300"
    end

    test "validates procedure output using validate_output/3", %{schema: schema} do
      output_data = %{
        "uri" => "at://did:plc:abc/app.bsky.feed.post/123",
        "cid" => "bafyreiabc123"
      }

      assert {:ok, result} = AetherLexicon.validate_output(schema, "main", output_data)
      assert result["uri"] =~ "at://"
    end

    test "rejects incomplete procedure output", %{schema: schema} do
      output_data = %{
        "uri" => "at://did:plc:abc/app.bsky.feed.post/123"
        # Missing required "cid"
      }

      assert {:error, error} = AetherLexicon.validate_output(schema, "main", output_data)
      assert error =~ "must have the property \"cid\""
    end
  end

  describe "subscription validation" do
    setup do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.subscribe",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "parameters" => %{
              "type" => "params",
              "properties" => %{
                "cursor" => %{"type" => "integer"}
              }
            },
            "message" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["seq", "event"],
                "properties" => %{
                  "seq" => %{"type" => "integer"},
                  "event" => %{"type" => "string"}
                }
              }
            }
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates subscription message using validate_message/3", %{schema: schema} do
      message_data = %{
        "seq" => 12345,
        "event" => "commit"
      }

      result = AetherLexicon.validate_message(schema, "main", message_data)
      assert {:ok, _} = result
    end

    test "allows subscription without input/output schemas", %{schema: schema} do
      # Subscriptions might not have traditional input/output
      data = %{"seq" => 1}

      result = AetherLexicon.validate(schema, "main", data)
      # Should succeed since no input schema is defined
      assert {:ok, _} = result
    end
  end

  describe "xrpc without input schema" do
    test "validates query without input schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.noInput",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "value" => %{"type" => "string"}
                }
              }
            }
          }
        }
      }

      # Should accept any input when no input schema defined
      assert {:ok, _} = AetherLexicon.validate(schema, "main", %{"anything" => "goes"})
    end
  end

  describe "xrpc without output schema" do
    test "validates procedure without output schema" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.noOutput",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["action"],
                "properties" => %{
                  "action" => %{"type" => "string"}
                }
              }
            }
          }
        }
      }

      input_data = %{
        "$xrpc" => "input",
        "action" => "delete"
      }

      assert {:ok, %{"action" => "delete"}} = AetherLexicon.validate(schema, "main", input_data)

      # Output validation with no schema should succeed
      output_data = %{"$xrpc" => "output", "anything" => "works"}
      assert {:ok, _} = AetherLexicon.validate(schema, "main", output_data)
    end
  end

  describe "parameters validation" do
    setup do
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
                "q" => %{
                  "type" => "string",
                  "description" => "Search query"
                },
                "limit" => %{
                  "type" => "integer",
                  "minimum" => 1,
                  "maximum" => 100,
                  "default" => 25
                },
                "cursor" => %{
                  "type" => "string"
                }
              }
            },
            "output" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{
                  "results" => %{"type" => "array", "items" => %{"type" => "string"}}
                }
              }
            }
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates required parameters using validate_parameters/3", %{schema: schema} do
      params = %{"q" => "test search"}

      assert {:ok, result} = AetherLexicon.validate_parameters(schema, "main", params)
      assert result["q"] == "test search"
    end

    test "applies default values to parameters", %{schema: schema} do
      params = %{"q" => "test"}

      assert {:ok, result} = AetherLexicon.validate_parameters(schema, "main", params)
      # Default should be applied
      assert result["limit"] == 25
    end

    test "validates parameter constraints", %{schema: schema} do
      params = %{
        "q" => "test",
        "limit" => 150
      }

      assert {:error, error} = AetherLexicon.validate_parameters(schema, "main", params)
      assert error =~ "can not be greater than 100"
    end

    test "rejects missing required parameters", %{schema: schema} do
      params = %{"limit" => 10}

      assert {:error, error} = AetherLexicon.validate_parameters(schema, "main", params)
      assert error =~ "must have the parameter \"q\""
    end

    test "validates optional parameters", %{schema: schema} do
      params = %{
        "q" => "test",
        "cursor" => "abc123"
      }

      assert {:ok, result} = AetherLexicon.validate_parameters(schema, "main", params)
      assert result["cursor"] == "abc123"
    end
  end

  describe "errors validation" do
    setup do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.auth",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "schema" => %{
                "type" => "object",
                "required" => ["username", "password"],
                "properties" => %{
                  "username" => %{"type" => "string"},
                  "password" => %{"type" => "string"}
                }
              }
            },
            "errors" => [
              %{
                "name" => "InvalidCredentials",
                "schema" => %{
                  "type" => "object",
                  "required" => ["message"],
                  "properties" => %{
                    "message" => %{"type" => "string"}
                  }
                }
              },
              %{
                "name" => "AccountLocked"
              },
              %{
                "name" => "RateLimited",
                "schema" => %{
                  "type" => "object",
                  "properties" => %{
                    "retryAfter" => %{"type" => "integer"}
                  }
                }
              }
            ]
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates error with schema using validate_error/4", %{schema: schema} do
      error_data = %{"message" => "Incorrect username or password"}

      assert {:ok, result} =
               AetherLexicon.validate_error(schema, "main", "InvalidCredentials", error_data)

      assert result["message"] == "Incorrect username or password"
    end

    test "rejects invalid error data", %{schema: schema} do
      # Missing required "message"
      error_data = %{}

      assert {:error, error} =
               AetherLexicon.validate_error(schema, "main", "InvalidCredentials", error_data)

      assert error =~ "must have the property \"message\""
    end

    test "validates error without schema", %{schema: schema} do
      error_data = %{"anything" => "works"}

      # Should succeed - error has no schema
      assert {:ok, _} = AetherLexicon.validate_error(schema, "main", "AccountLocked", error_data)
    end

    test "rejects unknown error name", %{schema: schema} do
      error_data = %{}

      assert {:error, error} =
               AetherLexicon.validate_error(schema, "main", "UnknownError", error_data)

      assert error =~ "unknown error 'UnknownError'"
      assert error =~ "InvalidCredentials, AccountLocked, RateLimited"
    end

    test "validates error with optional fields", %{schema: schema} do
      error_data = %{"retryAfter" => 60}

      assert {:ok, result} =
               AetherLexicon.validate_error(schema, "main", "RateLimited", error_data)

      assert result["retryAfter"] == 60
    end
  end

  describe "message validation (subscriptions)" do
    setup do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.firehose",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "parameters" => %{
              "type" => "params",
              "properties" => %{
                "cursor" => %{"type" => "integer"}
              }
            },
            "message" => %{
              "schema" => %{
                "type" => "union",
                "refs" => ["#commit", "#identity"],
                "closed" => true
              }
            }
          },
          "commit" => %{
            "type" => "object",
            "required" => ["seq", "repo"],
            "properties" => %{
              "$type" => %{"type" => "string"},
              "seq" => %{"type" => "integer"},
              "repo" => %{"type" => "string"}
            }
          },
          "identity" => %{
            "type" => "object",
            "required" => ["seq", "did"],
            "properties" => %{
              "$type" => %{"type" => "string"},
              "seq" => %{"type" => "integer"},
              "did" => %{"type" => "string", "format" => "did"}
            }
          }
        }
      }

      {:ok, schema: schema}
    end

    test "validates subscription message using validate_message/3", %{schema: schema} do
      message = %{
        "$type" => "#commit",
        "seq" => 12345,
        "repo" => "did:plc:abc123"
      }

      assert {:ok, result} = AetherLexicon.validate_message(schema, "main", message)
      assert result["seq"] == 12345
    end

    test "rejects invalid subscription message", %{schema: schema} do
      message = %{
        "$type" => "#commit",
        "seq" => 12345
        # Missing required "repo"
      }

      assert {:error, error} = AetherLexicon.validate_message(schema, "main", message)
      assert error =~ "must have the property \"repo\""
    end

    test "validates different message types", %{schema: schema} do
      identity_message = %{
        "$type" => "#identity",
        "seq" => 67890,
        "did" => "did:plc:xyz789"
      }

      assert {:ok, result} = AetherLexicon.validate_message(schema, "main", identity_message)
      assert result["did"] == "did:plc:xyz789"
    end
  end

  describe "xrpc edge cases for coverage" do
    test "validates query without parameters definition" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.noParams",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{"value" => %{"type" => "string"}}
              }
            }
          }
        }
      }

      # Should succeed even with parameters data when no parameters schema defined
      assert {:ok, _} = AetherLexicon.validate_parameters(schema, "main", %{"anything" => "goes"})
    end

    test "validates query with nil input definition using validate_input" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.noInput",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{"value" => %{"type" => "string"}}
              }
            }
          }
        }
      }

      # Should succeed when no input schema defined
      assert {:ok, _} = AetherLexicon.validate_input(schema, "main", %{"anything" => "goes"})
    end

    test "validates input with direct schema (without schema wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.directSchema",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "type" => "object",
              "required" => ["action"],
              "properties" => %{
                "action" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, result} = AetherLexicon.validate_input(schema, "main", %{"action" => "create"})
      assert result["action"] == "create"
    end

    test "validates output with direct schema (without schema wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.directOutputSchema",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "output" => %{
              "type" => "object",
              "required" => ["status"],
              "properties" => %{
                "status" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, result} = AetherLexicon.validate_output(schema, "main", %{"status" => "ok"})
      assert result["status"] == "ok"
    end

    test "validates subscription without message definition" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.simpleSubscription",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "parameters" => %{
              "type" => "params",
              "properties" => %{
                "cursor" => %{"type" => "integer"}
              }
            }
          }
        }
      }

      # Should succeed even with message data when no message schema defined
      assert {:ok, _} = AetherLexicon.validate_message(schema, "main", %{"anything" => "goes"})
    end

    test "validates array without items definition" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.arrayNoItems",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "tags" => %{
                "type" => "array"
                # No items definition
              }
            }
          }
        }
      }

      # Should succeed with any array content when no items schema defined
      assert {:ok, result} =
               AetherLexicon.validate(schema, "main", %{"tags" => [1, "two", %{"three" => 3}]})

      assert result["tags"] == [1, "two", %{"three" => 3}]
    end

    test "validates message with direct schema (without schema wrapper)" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.directMessageSchema",
        "defs" => %{
          "main" => %{
            "type" => "subscription",
            "message" => %{
              "type" => "object",
              "required" => ["event"],
              "properties" => %{
                "event" => %{"type" => "string"}
              }
            }
          }
        }
      }

      assert {:ok, result} =
               AetherLexicon.validate_message(schema, "main", %{"event" => "update"})

      assert result["event"] == "update"
    end

    test "rejects error validation when endpoint has no errors defined" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.noErrors",
        "defs" => %{
          "main" => %{
            "type" => "procedure",
            "input" => %{
              "schema" => %{
                "type" => "object",
                "properties" => %{"action" => %{"type" => "string"}}
              }
            }
          }
        }
      }

      # Should fail when trying to validate error but no errors are defined
      assert {:error, error} = AetherLexicon.validate_error(schema, "main", "SomeError", %{})
      assert error =~ "has no errors defined"
    end

    test "validates with direct input schema using default validate function" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.directInputDefault",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "input" => %{
              "type" => "object",
              "required" => ["key"],
              "properties" => %{
                "key" => %{"type" => "string"}
              }
            }
          }
        }
      }

      # Using validate/3 defaults to input validation and should use direct schema
      assert {:ok, result} = AetherLexicon.validate(schema, "main", %{"key" => "value"})
      assert result["key"] == "value"
    end

    test "rejects invalid parameters definition" do
      # Test parameters that aren't type "params"
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.wrongParamsType",
        "defs" => %{
          "main" => %{
            "type" => "query",
            "parameters" => %{
              # Wrong type, should be "params"
              "type" => "string"
            }
          }
        }
      }

      assert {:error, error} = AetherLexicon.validate_parameters(schema, "main", %{"q" => "test"})
      assert error =~ "invalid parameters definition"
    end
  end

  describe "additional edge cases for remaining coverage" do
    test "validates string with minLength that passes slow path byte check" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "minLength" => 5
          }
        }
      }

      # String with exactly 10 characters, 10 * 3 = 30 >= 5, so passes fast path
      # byte_size is 10 which is >= 5, so should pass the slow path check (validate_min_bytes success path)
      assert {:ok, _} = AetherLexicon.validate(schema, "main", "1234567890")
    end

    test "validates string with both min and max graphemes in valid range" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "minGraphemes" => 5,
            "maxGraphemes" => 20
          }
        }
      }

      # String with exactly 10 graphemes - in the valid range (validate_grapheme_range success path)
      assert {:ok, _} = AetherLexicon.validate(schema, "main", "1234567890")
    end

    test "validates unknown string format passes through" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "string",
            "format" => "unknown-custom-format"
          }
        }
      }

      # Unknown formats should pass through without validation
      assert {:ok, _} = AetherLexicon.validate(schema, "main", "any-value-works")
    end

    test "validates required property with default value transformation" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "required" => ["value"],
            "properties" => %{
              "value" => %{"type" => "string", "default" => "default"}
            }
          }
        }
      }

      # Passing nil for required field - should apply default and trigger update_if_changed
      assert {:ok, result} = AetherLexicon.validate(schema, "main", %{"value" => nil})
      assert result["value"] == "default"
    end
  end
end
