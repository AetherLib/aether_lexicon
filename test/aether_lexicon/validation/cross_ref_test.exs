defmodule AetherLexicon.Validation.CrossRefTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

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
      assert {:ok, ["test"]} = Validation.validate(schema, "crossRef", ["test"])
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
      assert {:ok, "test"} = Validation.validate(schema, "implicitRef", "test")
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
      result = Validation.validate(schema, "closedUnion", %{"$type" => "unknown"})
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
        Validation.validate(schema, "openUnion", %{"$type" => "unknown"})
    end
  end
end
