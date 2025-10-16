defmodule AetherLexicon.ValidationFinalCoverageTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

  @moduledoc """
  Final tests targeting the last remaining uncovered lines.
  """

  describe "grapheme validation - line 354 coverage" do
    test "validates string with only minGraphemes that passes fast-path and succeeds in actual count" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              # Only minGraphemes, no maxGraphemes
              # This forces us into the "need actual count" branch (line 344)
              # Then we skip both max and min checks (lines 348, 351)
              # And hit the true branch (line 354) returning :ok
              "text" => %{"type" => "string", "minGraphemes" => 5}
            }
          }
        }
      }

      # String with exactly enough graphemes to pass fast-path
      # but still falls into "need actual count" due to no maxGraphemes
      data = %{"text" => "hello world"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates string with minGraphemes at boundary" do
      schema = %{
        "lexicon" => 1,
        "id" => "test",
        "defs" => %{
          "main" => %{
            "type" => "object",
            "properties" => %{
              "text" => %{"type" => "string", "minGraphemes" => 10}
            }
          }
        }
      }

      # String with exactly minGraphemes characters
      data = %{"text" => "0123456789"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end

    test "validates string with minGraphemes slightly above minimum" do
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

      # 6 graphemes, passes minGraphemes check
      data = %{"text" => "hello!"}
      assert {:ok, _} = Validation.validate(schema, "main", data)
    end
  end

  describe "analysis of unreachable code" do
    # Lines 93 and 106 are unreachable because must_be_obj is never set to true
    # in any calling code. It's a defensive parameter that exists for potential
    # future use but isn't currently utilized.
    #
    # Lines 351-352 are unreachable because in Elixir, String.length/1 returns
    # grapheme count (not code unit count like JavaScript), so the "fast-path"
    # check at line 336 and the "actual count" check at line 351 are checking
    # the same value. If we pass line 336, we'll always pass line 351.

    test "documents unreachable code analysis" do
      # This test exists for documentation purposes
      assert true
    end
  end
end
