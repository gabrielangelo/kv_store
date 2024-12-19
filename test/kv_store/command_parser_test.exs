defmodule KvStore.Domain.CommandParserTest do
  use ExUnit.Case, async: true
  alias KvStore.Domain.CommandParser

  setup do
    File.rm("storage.dat")
    File.rm_rf("transactions")

    client_id = "test_#{System.unique_integer([:positive])}"
    {:ok, %{client: client_id}}
  end

  describe "command validation" do
    test "validates key format", %{client: client} do
      assert {:error, "Value 123 is not valid as key"} =
               CommandParser.parse_and_execute("SET 123 value", client)

      assert {:error, "Value TRUE is not valid as key"} =
               CommandParser.parse_and_execute("SET TRUE value", client)

      assert {:error, "Value FALSE is not valid as key"} =
               CommandParser.parse_and_execute("SET FALSE value", client)

      assert {:error, "Value NIL is not valid as key"} =
               CommandParser.parse_and_execute("SET NIL value", client)

      assert {:error, "Value 10 is not valid as key"} =
               CommandParser.parse_and_execute("GET 10", client)
    end

    test "validates value format", %{client: client} do
      assert {:error, "Cannot SET key to NIL"} =
               CommandParser.parse_and_execute("SET test_key NIL", client)

      assert {:ok, %{old_value: nil, new_value: true}} =
               CommandParser.parse_and_execute("SET bool_key TRUE", client)

      assert {:ok, %{old_value: nil, new_value: false}} =
               CommandParser.parse_and_execute("SET bool_key2 FALSE", client)
    end

    test "handles quoted strings", %{client: client} do
      assert {:ok, %{old_value: nil, new_value: "hello world"}} =
               CommandParser.parse_and_execute("SET key \"hello world\"", client)

      assert {:ok, %{old_value: nil, new_value: "hello \"world\""}} =
               CommandParser.parse_and_execute(~s(SET key2 "hello \\"world\\""), client)
    end
  end

  describe "file-based transactions" do
    test "handles transaction lifecycle", %{client: client} do
      assert {:ok, "OK"} = CommandParser.parse_and_execute("BEGIN", client)

      assert {:ok, %{old_value: nil, new_value: "value1"}} =
               CommandParser.parse_and_execute("SET tx_key value1", client)

      assert {:ok, "value1"} = CommandParser.parse_and_execute("GET tx_key", client)

      assert {:ok, "OK"} = CommandParser.parse_and_execute("COMMIT", client)

      assert {:ok, "value1"} = CommandParser.parse_and_execute("GET tx_key", client)
    end

    test "handles rollback", %{client: client} do
      assert {:ok, "OK"} = CommandParser.parse_and_execute("BEGIN", client)

      assert {:ok, %{old_value: nil, new_value: "temp"}} =
               CommandParser.parse_and_execute("SET rollback_key temp", client)

      assert {:ok, "OK"} = CommandParser.parse_and_execute("ROLLBACK", client)

      assert {:ok, nil} = CommandParser.parse_and_execute("GET rollback_key", client)
    end

    test "prevents nested transactions", %{client: client} do
      assert {:ok, "OK"} = CommandParser.parse_and_execute("BEGIN", client)
      assert {:error, "Already in transaction"} = CommandParser.parse_and_execute("BEGIN", client)
    end
  end
end
