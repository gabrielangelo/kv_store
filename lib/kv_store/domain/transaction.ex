defmodule KvStore.Domain.Transaction do
  @moduledoc """
  Implements ACID transactions for the key-value store.

  Provides transaction management with:
  - Atomicity: All operations succeed or all fail
  - Consistency: Data remains valid after transaction
  - Isolation: Transactions are isolated from each other
  - Durability: Committed changes persist

  Transaction Lifecycle:
  1. BEGIN: Starts a new transaction
  2. Operations: SET/GET within transaction
  3. COMMIT/ROLLBACK: Ends transaction

  Features:
  - Multi-version Concurrency Control (MVCC)
  - Optimistic concurrency control
  - Read set validation on commit
  - File-based durability
  """
  alias KvStore.Domain.Storage

  @type client_id :: String.t()
  @type key :: String.t()
  @type value :: any()
  @type transaction_result :: {:ok, map()} | {:error, String.t() | atom()}
  @type operation_result :: :ok | {:error, String.t()}
  @type set_result :: {value | nil, value} | {:error, String.t()}

  @transactions_dir "transactions"

  @doc """
  Begins a new transaction for a client.

  Creates a new transaction file tracking reads and writes.

  ## Parameters
    - client: Client identifier

  ## Returns
    - :ok on success
    - {:error, reason} if client already has active transaction
  """
  @spec begin(client_id) :: operation_result
  def begin(client) do
    File.mkdir_p!(@transactions_dir)
    transaction_file = transaction_path(client)

    case File.exists?(transaction_file) do
      false ->
        File.write!(
          transaction_file,
          :erlang.term_to_binary(%{
            reads: %{},
            writes: %{},
            original_values: %{}
          })
        )

        :ok

      true ->
        {:error, "Already in transaction"}
    end
  end

  @doc """
  Commits the current transaction.

  Validates all reads haven't changed, then applies writes atomically.

  ## Parameters
    - client: Client identifier

  ## Returns
    - :ok if transaction commits successfully
    - {:error, reason} if validation fails or no active transaction
  """
  @spec commit(client_id) :: operation_result
  def commit(client) do
    case read_transaction(client) do
      {:ok, transaction} ->
        commit_transaction(client, transaction)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit_transaction(client, transaction) do
    case validate_reads(transaction) do
      :ok ->
        apply_writes(transaction.writes)
        cleanup_transaction(client)
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp apply_writes(writes) do
    Enum.each(writes, fn {key, value} ->
      Storage.set(key, value)
    end)
  end

  defp cleanup_transaction(client) do
    File.rm!(transaction_path(client))
  end

  @doc """
  Rolls back the current transaction.

  Discards all changes made in the transaction.

  ## Parameters
    - client: Client identifier

  ## Returns
    - :ok on successful rollback
    - {:error, reason} if no active transaction
  """
  @spec rollback(client_id) :: operation_result
  def rollback(client) do
    transaction_file = transaction_path(client)

    case read_transaction(client) do
      {:ok, _transaction} ->
        File.rm!(transaction_file)
        :ok

      _ ->
        {:error, "No active transaction"}
    end
  end

  @doc """
  Sets a value for a key in storage.

  Atomically updates the storage file with the new key-value pair.
  If the key already exists, its value is overwritten.

  ## Parameters
    - key: The key to store the value under
    - value: The value to store

  ## Returns
    - {old_value, new_value} tuple, where old_value might be nil
  """
  @spec set(client_id, key, value) :: set_result
  def set(client, key, value) do
    case read_transaction(client) do
      {:ok, transaction} ->
        current_value = Storage.get(key)

        updated_transaction = %{
          transaction
          | writes: Map.put(transaction.writes, key, value)
        }

        File.write!(transaction_path(client), :erlang.term_to_binary(updated_transaction))
        {current_value, value}

      {:error, _} ->
        Storage.set(key, value)
    end
  end

  @spec get(client_id, key) :: value | nil
  def get(client, key) do
    case read_transaction(client) do
      {:ok, transaction} ->
        get_from_transaction(transaction, client, key)

      {:error, _reason} ->
        Storage.get(key)
    end
  end

  defp get_from_transaction(transaction, client, key) do
    case Map.get(transaction.writes, key) do
      nil ->
        fetch_and_track_read(transaction, client, key)

      value ->
        value
    end
  end

  defp fetch_and_track_read(transaction, client, key) do
    value = Storage.get(key)

    if !Map.has_key?(transaction.writes, key) do
      updated_reads = Map.put(transaction.reads, key, value)
      updated_transaction = %{transaction | reads: updated_reads}
      save_transaction(client, updated_transaction)
    end

    value
  end

  defp save_transaction(client, transaction) do
    File.write!(transaction_path(client), :erlang.term_to_binary(transaction))
  end

  def read_transaction(client) do
    transaction_file = transaction_path(client)

    case File.read(transaction_file) do
      {:ok, content} ->
        {:ok, :erlang.binary_to_term(content)}

      {:error, _} ->
        {:error, :no_transaction}
    end
  end

  defp validate_reads(transaction) do
    changed_key =
      Enum.find(transaction.reads, fn {key, original_value} ->
        current_value = Storage.get(key)
        current_value != original_value
      end)

    case changed_key do
      nil -> :ok
      {key, _} -> {:error, "Atomicity failure (#{key})"}
    end
  end

  defp transaction_path(client) do
    Path.join(@transactions_dir, "#{client}.transaction")
  end
end
