defmodule KvStore.Domain.StorageTest do
  use ExUnit.Case, async: false
  alias KvStore.Domain.Storage

  @storage_file "storage.dat"
  @lock_file "storage.lock"

  setup do
    File.rm(@storage_file)
    File.rm(@lock_file)
    :ok
  end

  describe "file-based storage" do
    test "basic set and get operations" do
      assert {nil, "value1"} = Storage.set("key1", "value1")
      assert "value1" = Storage.get("key1")
    end

    test "handles file persistence" do
      Storage.set("persist_key", "persist_value")

      assert File.exists?(@storage_file)

      {:ok, contents} = File.read(@storage_file)
      data = :erlang.binary_to_term(contents)
      assert Map.get(data, "persist_key") == "persist_value"
    end

    test "handles concurrent access" do
      parent = self()

      processes =
        for i <- 1..5 do
          spawn_link(fn ->
            result = Storage.set("concurrent_key", "value_#{i}")
            send(parent, {:done, i, result})
          end)
        end

      results =
        for _ <- processes do
          receive do
            {:done, i, result} -> {i, result}
          after
            1000 -> flunk("Timeout waiting for process")
          end
        end

      assert length(results) == 5
      refute File.exists?(@lock_file)
    end
  end

  describe "error handling" do
    test "handles missing storage file" do
      assert nil == Storage.get("nonexistent_key")
    end

    test "maintains lock file cleanup" do
      Storage.set("test_key", "test_value")
      refute File.exists?(@lock_file)
    end
  end
end
