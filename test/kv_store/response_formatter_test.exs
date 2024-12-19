defmodule KvStoreWeb.ResponseFormatterTest do
  use ExUnit.Case, async: true
  alias KvStoreWeb.ResponseFormatter

  describe "format_success/1" do
    test "formats SET command response with nil old value" do
      response = %{old_value: nil, new_value: 42}
      assert ResponseFormatter.format_success(response) == "NIL 42"
    end

    test "formats SET command response with existing old value" do
      response = %{old_value: 42, new_value: 100}
      assert ResponseFormatter.format_success(response) == "42 100"
    end

    test "formats SET command response with string values" do
      response = %{old_value: "hello", new_value: "world"}
      assert ResponseFormatter.format_success(response) == "hello world"
    end

    test "formats SET command response with quoted values" do
      response = %{old_value: "hello world", new_value: "new value"}
      assert ResponseFormatter.format_success(response) == ~s("hello world" "new value")
    end

    test "formats transaction command responses" do
      assert ResponseFormatter.format_success("OK") == "OK"
    end

    test "formats GET command response for integer" do
      assert ResponseFormatter.format_success(42) == "42"
    end

    test "formats GET command response for string" do
      assert ResponseFormatter.format_success("hello") == "hello"
    end

    test "formats GET command response for nil" do
      assert ResponseFormatter.format_success(nil) == "NIL"
    end

    test "formats GET command response for boolean" do
      assert ResponseFormatter.format_success(true) == "TRUE"
      assert ResponseFormatter.format_success(false) == "FALSE"
    end
  end

  describe "format_error/1" do
    test "formats simple error message" do
      assert ResponseFormatter.format_error("Not found") == ~s(ERR "Not found")
    end

    test "formats error message with quotes" do
      assert ResponseFormatter.format_error("Invalid \"key\"") == ~s(ERR "Invalid \\"key\\"")
    end
  end

  describe "format_value/1" do
    test "formats nil value" do
      assert ResponseFormatter.format_value(nil) == "NIL"
    end

    test "formats boolean values" do
      assert ResponseFormatter.format_value(true) == "TRUE"
      assert ResponseFormatter.format_value(false) == "FALSE"
    end

    test "formats integer values" do
      assert ResponseFormatter.format_value(42) == "42"
      assert ResponseFormatter.format_value(0) == "0"
      assert ResponseFormatter.format_value(-10) == "-10"
    end

    test "formats simple string values" do
      assert ResponseFormatter.format_value("hello") == "hello"
      assert ResponseFormatter.format_value("test123") == "test123"
    end

    test "formats strings with spaces" do
      assert ResponseFormatter.format_value("hello world") == ~s("hello world")
      assert ResponseFormatter.format_value("  spaces  ") == ~s("  spaces  ")
    end

    test "formats strings that look like numbers" do
      assert ResponseFormatter.format_value("123") == ~s("123")
      assert ResponseFormatter.format_value("00042") == ~s("00042")
    end

    test "formats strings containing special values" do
      assert ResponseFormatter.format_value("TRUE") == ~s("TRUE")
      assert ResponseFormatter.format_value("FALSE") == ~s("FALSE")
      assert ResponseFormatter.format_value("NIL") == ~s("NIL")
    end

    test "formats strings containing quotes" do
      assert ResponseFormatter.format_value("hello\"world") == ~s("hello\\"world")
      assert ResponseFormatter.format_value("\"quoted\"") == ~s("\\"quoted\\"")
    end

    test "formats mixed special case strings" do
      assert ResponseFormatter.format_value("TRUE with space") == ~s("TRUE with space")
      assert ResponseFormatter.format_value("42 is the answer") == ~s("42 is the answer")
      assert ResponseFormatter.format_value("NIL value") == ~s("NIL value")
    end
  end
end
