defmodule KvStore.ValueParserTest do
  use ExUnit.Case, async: true
  alias KvStore.Domain.ValueParser

  describe "parse/1" do
    test "parses valid strings" do
      assert {:ok, "hello"} = ValueParser.parse("hello")
      assert {:ok, "hello world"} = ValueParser.parse("\"hello world\"")
      assert {:ok, "hello\"world"} = ValueParser.parse("\"hello\\\"world\"")
    end

    test "parses numbers" do
      assert {:ok, 42} = ValueParser.parse("42")
      assert {:ok, 1_234_567_890} = ValueParser.parse("1234567890")
    end

    test "parses booleans" do
      assert {:ok, true} = ValueParser.parse("TRUE")
      assert {:ok, false} = ValueParser.parse("FALSE")
    end

    test "handles special cases" do
      assert {:error, "Cannot SET key to NIL"} = ValueParser.parse("NIL")
      assert {:error, "Unclosed string"} = ValueParser.parse("\"unclosed")
    end
  end

  describe "parse_key/1" do
    test "accepts valid keys" do
      assert {:ok, "valid_key"} = ValueParser.parse_key("valid_key")
      assert {:ok, "valid-key"} = ValueParser.parse_key("valid-key")
      assert {:ok, "validKey123"} = ValueParser.parse_key("validKey123")
    end

    test "rejects invalid keys" do
      assert {:error, _} = ValueParser.parse_key("123")
      assert {:error, _} = ValueParser.parse_key("TRUE")
      assert {:error, _} = ValueParser.parse_key("FALSE")
      assert {:error, _} = ValueParser.parse_key("NIL")
    end
  end
end
