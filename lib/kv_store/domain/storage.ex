defmodule KvStore.Domain.Storage do
  @moduledoc """
  Persistent key-value storage implementation with file-based durability.

  This module provides the core storage functionality with:
  - File-based persistence
  - Atomic operations through file locking
  - Concurrent access protection
  - Basic key-value operations (get/set)

  The storage uses two files:
  - storage.dat: Contains the serialized key-value data
  - storage.lock: Used for implementing file-based locking

  All operations are atomic and thread-safe through a file-based
  locking mechanism that prevents concurrent access to the storage file.
  """

  @storage_file "storage.dat"
  @lock_file "storage.lock"

  @type key :: String.t()
  @type value :: any()
  @type set_result :: {value | nil, value}

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
  @spec set(key, value) :: set_result
  def set(key, value) do
    with_lock(fn state ->
      old_value = Map.get(state, key)
      new_state = Map.put(state, key, value)
      persist_state(new_state)
      {old_value, value}
    end)
  end

  @doc """
  Retrieves a value from storage by key.

  ## Parameters
    - key: The key to look up

  ## Returns
    - The value associated with the key
    - nil if the key doesn't exist
  """
  @spec get(key) :: value | nil
  def get(key) do
    with_lock(fn state ->
      Map.get(state, key)
    end)
  end

  defp with_lock(fun) do
    File.mkdir_p!(Path.dirname(@storage_file))

    case File.open(@lock_file, [:write, :exclusive]) do
      {:ok, lock} ->
        try do
          state = read_state()
          result = fun.(state)
          result
        after
          File.close(lock)
          File.rm(@lock_file)
        end

      {:error, :eexist} ->
        Process.sleep(10)
        with_lock(fun)
    end
  end

  defp read_state do
    case File.read(@storage_file) do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      {:error, :enoent} -> %{}
    end
  end

  defp persist_state(state) do
    File.write!(@storage_file, :erlang.term_to_binary(state))
  end
end
