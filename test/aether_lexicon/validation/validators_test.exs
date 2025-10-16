defmodule AetherLexicon.Validation.ValidatorsTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation.Validators

  describe "validate_range/3" do
    test "passes when value is within range" do
      assert :ok = Validators.validate_range(5, [minimum: 1, maximum: 10], "/test")
    end

    test "passes when only minimum is set and value is above" do
      assert :ok = Validators.validate_range(5, [minimum: 1], "/test")
    end

    test "passes when only maximum is set and value is below" do
      assert :ok = Validators.validate_range(5, [maximum: 10], "/test")
    end

    test "passes when no constraints are set" do
      assert :ok = Validators.validate_range(5, [], "/test")
    end

    test "passes when value equals minimum" do
      assert :ok = Validators.validate_range(1, [minimum: 1], "/test")
    end

    test "passes when value equals maximum" do
      assert :ok = Validators.validate_range(10, [maximum: 10], "/test")
    end

    test "fails when value is below minimum" do
      assert {:error, "/test can not be less than 1"} =
               Validators.validate_range(0, [minimum: 1], "/test")
    end

    test "fails when value is above maximum" do
      assert {:error, "/test can not be greater than 10"} =
               Validators.validate_range(11, [maximum: 10], "/test")
    end

    test "works with floats" do
      assert :ok = Validators.validate_range(5.5, [minimum: 1.0, maximum: 10.0], "/test")

      assert {:error, "/test can not be less than 1.0"} =
               Validators.validate_range(0.5, [minimum: 1.0], "/test")

      assert {:error, "/test can not be greater than 10.0"} =
               Validators.validate_range(10.5, [maximum: 10.0], "/test")
    end
  end

  describe "validate_length/4" do
    test "validates list length with elements unit" do
      assert :ok = Validators.validate_length([1, 2, 3], [min_length: 1, max_length: 5], "/test", "elements")
    end

    test "validates string length with bytes unit" do
      assert :ok = Validators.validate_length("hello", [min_length: 1, max_length: 10], "/test", "bytes")
    end

    test "validates with default elements unit" do
      assert :ok = Validators.validate_length([1, 2], [min_length: 1, max_length: 5], "/test")
    end

    test "passes when no constraints are set" do
      assert :ok = Validators.validate_length([1, 2, 3], [], "/test", "elements")
    end

    test "passes when length equals minimum" do
      assert :ok = Validators.validate_length([1, 2], [min_length: 2], "/test", "elements")
    end

    test "passes when length equals maximum" do
      assert :ok = Validators.validate_length([1, 2], [max_length: 2], "/test", "elements")
    end

    test "fails with elements unit when too short" do
      assert {:error, "/test must not have fewer than 5 elements"} =
               Validators.validate_length([1, 2], [min_length: 5], "/test", "elements")
    end

    test "fails with elements unit when too long" do
      assert {:error, "/test must not have more than 2 elements"} =
               Validators.validate_length([1, 2, 3], [max_length: 2], "/test", "elements")
    end

    test "fails with characters unit when too short" do
      assert {:error, "/test must not be shorter than 10 characters"} =
               Validators.validate_length("hi", [min_length: 10], "/test", "characters")
    end

    test "fails with characters unit when too long" do
      assert {:error, "/test must not be longer than 2 characters"} =
               Validators.validate_length("hello", [max_length: 2], "/test", "characters")
    end

    test "fails with bytes unit when too small" do
      assert {:error, "/test must not be smaller than 10 bytes"} =
               Validators.validate_length("hi", [min_length: 10], "/test", "bytes")
    end

    test "fails with bytes unit when too large" do
      assert {:error, "/test must not be larger than 2 bytes"} =
               Validators.validate_length("hello", [max_length: 2], "/test", "bytes")
    end

    test "fails with graphemes unit when too short" do
      assert {:error, "/test must not be shorter than 10 graphemes"} =
               Validators.validate_length("hi", [min_length: 10], "/test", "graphemes")
    end

    test "fails with graphemes unit when too long" do
      assert {:error, "/test must not be longer than 2 graphemes"} =
               Validators.validate_length("hello", [max_length: 2], "/test", "graphemes")
    end
  end

  describe "validate_const/3" do
    test "passes when const is nil" do
      assert :ok = Validators.validate_const("any_value", nil, "/test")
      assert :ok = Validators.validate_const(123, nil, "/test")
      assert :ok = Validators.validate_const(true, nil, "/test")
    end

    test "passes when value matches const" do
      assert :ok = Validators.validate_const("test", "test", "/test")
      assert :ok = Validators.validate_const(42, 42, "/test")
      assert :ok = Validators.validate_const(true, true, "/test")
      assert :ok = Validators.validate_const(false, false, "/test")
    end

    test "fails when value does not match const" do
      assert {:error, "/test must be expected"} =
               Validators.validate_const("actual", "expected", "/test")

      assert {:error, "/test must be 42"} =
               Validators.validate_const(41, 42, "/test")

      assert {:error, "/test must be true"} =
               Validators.validate_const(false, true, "/test")
    end
  end

  describe "validate_enum/3" do
    test "passes when value is in enum list" do
      assert :ok = Validators.validate_enum("a", ["a", "b", "c"], "/test")
      assert :ok = Validators.validate_enum(1, [1, 2, 3], "/test")
    end

    test "passes when enum is not a list" do
      assert :ok = Validators.validate_enum("anything", nil, "/test")
      assert :ok = Validators.validate_enum("anything", "not_a_list", "/test")
      assert :ok = Validators.validate_enum(123, %{}, "/test")
    end

    test "fails when value is not in enum list" do
      assert {:error, "/test must be one of (a|b|c)"} =
               Validators.validate_enum("d", ["a", "b", "c"], "/test")

      assert {:error, "/test must be one of (1|2|3)"} =
               Validators.validate_enum(4, [1, 2, 3], "/test")
    end

    test "handles empty enum list" do
      assert {:error, "/test must be one of ()"} =
               Validators.validate_enum("anything", [], "/test")
    end
  end

  describe "get_default/2" do
    test "returns string default when type matches" do
      assert "test" = Validators.get_default("string", "test")
      assert "" = Validators.get_default("string", "")
    end

    test "returns integer default when type matches" do
      assert 42 = Validators.get_default("integer", 42)
      assert 0 = Validators.get_default("integer", 0)
      assert -1 = Validators.get_default("integer", -1)
    end

    test "returns boolean default when type matches" do
      assert true == Validators.get_default("boolean", true)
      assert false == Validators.get_default("boolean", false)
    end

    test "returns nil when type does not match" do
      assert nil == Validators.get_default("string", 123)
      assert nil == Validators.get_default("string", true)
      assert nil == Validators.get_default("integer", "123")
      assert nil == Validators.get_default("integer", true)
      assert nil == Validators.get_default("boolean", "true")
      assert nil == Validators.get_default("boolean", 1)
    end

    test "returns nil for unknown types" do
      assert nil == Validators.get_default("unknown", "value")
      assert nil == Validators.get_default("array", [1, 2, 3])
      assert nil == Validators.get_default("object", %{})
    end

    test "returns nil when default is nil" do
      assert nil == Validators.get_default("string", nil)
      assert nil == Validators.get_default("integer", nil)
      assert nil == Validators.get_default("boolean", nil)
    end
  end
end
