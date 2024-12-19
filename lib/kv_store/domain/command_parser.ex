defmodule KvStore.Domain.CommandParser do
  @moduledoc """
  Parses and executes commands for the key-value store.

  This module is responsible for:
  - Parsing raw command strings into structured commands
  - Validating command syntax and arguments
  - Routing commands to handlers
  - Coordinating between Storage and Transaction modules

  Supported Commands:
  - SET <key> <value> : Stores a value with the given key
  - GET <key> : Retrieves value for the given key
  - BEGIN : Starts a new transaction
  - COMMIT : Commits current transaction
  - ROLLBACK : Rolls back current transaction

  Value Types:
  - Strings: Regular text or quoted text for spaces ("hello world")
  - Integers: Numeric values (42)
  - Booleans: TRUE or FALSE
  - NIL: Represents absence of value (cannot be stored)
  """

  alias KvStore.Domain.Storage
  alias KvStore.Domain.Transaction

  @doc """
  Parses and executes a command string for a specific client.

  ## Parameters
    - command: String containing the command to execute
    - client: Client identifier for transaction management

  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure

  ## Examples
      iex> CommandParser.parse_and_execute("SET mykey 42", "client1")
      {:ok, %{old_value: nil, new_value: 42}}

      iex> CommandParser.parse_and_execute("GET mykey", "client1")
      {:ok, 42}
  """
  def parse_and_execute(command, client) do
    command
    |> String.trim()
    |> tokenize_command()
    |> execute_command(client)
  end

  defp tokenize_command(command) do
    case parse_command_parts(command) do
      {:ok, parts} -> parts
      {:error, _} = err -> err
    end
  end

  defp parse_command_parts(command) do
    parts = String.split(command, " ", parts: 3)

    case parts do
      [] -> {:error, "Empty command"}
      ["SET", key, value] -> {:ok, ["SET", key, parse_raw_value(value)]}
      other -> {:ok, other}
    end
  end

  defp parse_raw_value(value) do
    trimmed = String.trim(value)

    case trimmed do
      "\"" <> rest ->
        case String.split_at(rest, -1) do
          {content, "\""} ->
            content
            |> String.replace("\\\"", "\"")

          _ ->
            value
        end

      _ ->
        value
    end
  end

  defp execute_command(["SET", key, value], client) do
    with {:ok, parsed_key} <- validate_key(key),
         {:ok, parsed_value} <- validate_value(value) do
      handle_set_operation(client, parsed_key, parsed_value)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(["GET", key], client) do
    case validate_key(key) do
      {:ok, parsed_key} ->
        value =
          if in_transaction?(client) do
            Transaction.get(client, parsed_key)
          else
            Storage.get(parsed_key)
          end

        {:ok, value}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_command(["BEGIN"], client) do
    case Transaction.begin(client) do
      :ok -> {:ok, "OK"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(["COMMIT"], client) do
    case Transaction.commit(client) do
      :ok -> {:ok, "OK"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command(["ROLLBACK"], client) do
    case Transaction.rollback(client) do
      :ok -> {:ok, "OK"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command({:error, reason}, _), do: {:error, reason}
  defp execute_command(_, _), do: {:error, "Invalid command"}

  defp in_transaction?(client) do
    case Transaction.read_transaction(client) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp validate_key(key) do
    cond do
      String.match?(key, ~r/^\d+$/) ->
        {:error, "Value #{key} is not valid as key"}

      key in ["TRUE", "FALSE", "NIL"] ->
        {:error, "Value #{key} is not valid as key"}

      true ->
        {:ok, key}
    end
  end

  defp validate_value("NIL"), do: {:error, "Cannot SET key to NIL"}
  defp validate_value("TRUE"), do: {:ok, true}
  defp validate_value("FALSE"), do: {:ok, false}

  defp validate_value(value) do
    if String.match?(value, ~r/^\d+$/) do
      {:ok, String.to_integer(value)}
    else
      {:ok, value}
    end
  end

  defp handle_set_operation(client, key, value) do
    if in_transaction?(client) do
      handle_transaction_set(client, key, value)
    else
      handle_direct_set(key, value)
    end
  end

  defp handle_transaction_set(client, key, value) do
    case Transaction.set(client, key, value) do
      {:error, reason} -> {:error, reason}
      {old_value, new_value} -> {:ok, %{old_value: old_value, new_value: new_value}}
    end
  end

  defp handle_direct_set(key, value) do
    case Storage.set(key, value) do
      {:error, reason} -> {:error, reason}
      {old_value, new_value} -> {:ok, %{old_value: old_value, new_value: new_value}}
    end
  end
end
