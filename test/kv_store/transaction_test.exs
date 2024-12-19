defmodule KvStore.Domain.TransactionTest do
  use ExUnit.Case, async: false
  alias KvStore.Domain.Transaction

  @transactions_dir "transactions"

  setup do
    File.rm_rf(@transactions_dir)
    client_id = "test_#{System.unique_integer([:positive])}"
    {:ok, %{client: client_id}}
  end

  describe "transaction file management" do
    test "creates and cleans up transaction files", %{client: client} do
      assert :ok = Transaction.begin(client)

      transaction_file = Path.join(@transactions_dir, "#{client}.transaction")
      assert File.exists?(transaction_file)

      assert :ok = Transaction.commit(client)

      refute File.exists?(transaction_file)
    end

    test "handles read set validation", %{client: client} do
      assert :ok = Transaction.begin(client)

      nil = Transaction.get(client, "my_key_1")

      other_client = "other_#{System.unique_integer([:positive])}"
      Transaction.set(other_client, "my_key_1", "modified")

      assert {:error, _} = Transaction.commit(client)
    end
  end
end
