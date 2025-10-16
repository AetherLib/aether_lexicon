defmodule AetherLexicon.Validation.XrpcTest do
  use ExUnit.Case, async: true

  alias AetherLexicon.Validation

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

      assert {:ok, %{"username" => "alice"}} = Validation.validate_input(schema, "main", input_data)
    end

    test "validates query input by default with validate/3", %{schema: schema} do
      input_data = %{"username" => "bob"}

      assert {:ok, %{"username" => "bob"}} = Validation.validate(schema, "main", input_data)
    end

    test "rejects invalid query input", %{schema: schema} do
      input_data = %{"username" => String.duplicate("a", 51)}

      assert {:error, error} = Validation.validate_input(schema, "main", input_data)
      assert error =~ "must not be longer than 50"
    end

    test "rejects missing required field in query input", %{schema: schema} do
      input_data = %{}

      assert {:error, error} = Validation.validate_input(schema, "main", input_data)
      assert error =~ "must have the property \"username\""
    end

    test "validates query output using validate_output/3", %{schema: schema} do
      output_data = %{
        "user" => %{
          "did" => "did:plc:abc123",
          "handle" => "alice.example.com"
        }
      }

      assert {:ok, result} = Validation.validate_output(schema, "main", output_data)
      assert result["user"]["did"] == "did:plc:abc123"
    end

    test "rejects invalid query output", %{schema: schema} do
      output_data = %{
        "user" => %{
          "did" => "did:plc:abc123"
          # Missing required "handle"
        }
      }

      assert {:error, error} = Validation.validate_output(schema, "main", output_data)
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

      assert {:ok, result} = Validation.validate_input(schema, "main", input_data)
      assert result["text"] == "Hello, world!"
    end

    test "validates procedure input by default with validate/3", %{schema: schema} do
      input_data = %{"text" => "Hello!"}

      assert {:ok, result} = Validation.validate(schema, "main", input_data)
      assert result["text"] == "Hello!"
    end

    test "rejects procedure input exceeding max length", %{schema: schema} do
      input_data = %{"text" => String.duplicate("a", 301)}

      assert {:error, error} = Validation.validate_input(schema, "main", input_data)
      assert error =~ "must not be longer than 300"
    end

    test "validates procedure output using validate_output/3", %{schema: schema} do
      output_data = %{
        "uri" => "at://did:plc:abc/app.bsky.feed.post/123",
        "cid" => "bafyreiabc123"
      }

      assert {:ok, result} = Validation.validate_output(schema, "main", output_data)
      assert result["uri"] =~ "at://"
    end

    test "rejects incomplete procedure output", %{schema: schema} do
      output_data = %{
        "uri" => "at://did:plc:abc/app.bsky.feed.post/123"
        # Missing required "cid"
      }

      assert {:error, error} = Validation.validate_output(schema, "main", output_data)
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

      result = Validation.validate_message(schema, "main", message_data)
      assert {:ok, _} = result
    end

    test "allows subscription without input/output schemas", %{schema: schema} do
      # Subscriptions might not have traditional input/output
      data = %{"seq" => 1}

      result = Validation.validate(schema, "main", data)
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
      assert {:ok, _} = Validation.validate(schema, "main", %{"anything" => "goes"})
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

      assert {:ok, %{"action" => "delete"}} = Validation.validate(schema, "main", input_data)

      # Output validation with no schema should succeed
      output_data = %{"$xrpc" => "output", "anything" => "works"}
      assert {:ok, _} = Validation.validate(schema, "main", output_data)
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

      assert {:ok, result} = Validation.validate_parameters(schema, "main", params)
      assert result["q"] == "test search"
    end

    test "applies default values to parameters", %{schema: schema} do
      params = %{"q" => "test"}

      assert {:ok, result} = Validation.validate_parameters(schema, "main", params)
      # Default should be applied
      assert result["limit"] == 25
    end

    test "validates parameter constraints", %{schema: schema} do
      params = %{
        "q" => "test",
        "limit" => 150
      }

      assert {:error, error} = Validation.validate_parameters(schema, "main", params)
      assert error =~ "can not be greater than 100"
    end

    test "rejects missing required parameters", %{schema: schema} do
      params = %{"limit" => 10}

      assert {:error, error} = Validation.validate_parameters(schema, "main", params)
      assert error =~ "must have the parameter \"q\""
    end

    test "validates optional parameters", %{schema: schema} do
      params = %{
        "q" => "test",
        "cursor" => "abc123"
      }

      assert {:ok, result} = Validation.validate_parameters(schema, "main", params)
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

      assert {:ok, result} = Validation.validate_error(schema, "main", "InvalidCredentials", error_data)
      assert result["message"] == "Incorrect username or password"
    end

    test "rejects invalid error data", %{schema: schema} do
      error_data = %{}  # Missing required "message"

      assert {:error, error} = Validation.validate_error(schema, "main", "InvalidCredentials", error_data)
      assert error =~ "must have the property \"message\""
    end

    test "validates error without schema", %{schema: schema} do
      error_data = %{"anything" => "works"}

      # Should succeed - error has no schema
      assert {:ok, _} = Validation.validate_error(schema, "main", "AccountLocked", error_data)
    end

    test "rejects unknown error name", %{schema: schema} do
      error_data = %{}

      assert {:error, error} = Validation.validate_error(schema, "main", "UnknownError", error_data)
      assert error =~ "unknown error 'UnknownError'"
      assert error =~ "InvalidCredentials, AccountLocked, RateLimited"
    end

    test "validates error with optional fields", %{schema: schema} do
      error_data = %{"retryAfter" => 60}

      assert {:ok, result} = Validation.validate_error(schema, "main", "RateLimited", error_data)
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

      assert {:ok, result} = Validation.validate_message(schema, "main", message)
      assert result["seq"] == 12345
    end

    test "rejects invalid subscription message", %{schema: schema} do
      message = %{
        "$type" => "#commit",
        "seq" => 12345
        # Missing required "repo"
      }

      assert {:error, error} = Validation.validate_message(schema, "main", message)
      assert error =~ "must have the property \"repo\""
    end

    test "validates different message types", %{schema: schema} do
      identity_message = %{
        "$type" => "#identity",
        "seq" => 67890,
        "did" => "did:plc:xyz789"
      }

      assert {:ok, result} = Validation.validate_message(schema, "main", identity_message)
      assert result["did"] == "did:plc:xyz789"
    end
  end
end
