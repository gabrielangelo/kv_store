defmodule KvStore.Domain.ValueParser do
  @moduledoc """
  Handles parsing and validation of keys and values for the key-value store.

  Supports multiple value types:
  - Strings: Plain text or quoted text with escapes
  - Integers: Numeric values
  - Booleans: TRUE/FALSE constants
  - NIL: Special value (cannot be stored)

  Features:
  - Type inference from string input
  - Quoted string handling with escape sequences
  - Key validation rules
  - Special value handling (TRUE, FALSE, NIL)
  """

  @doc """
  Parses and validates a value string into its appropriate type.

  ## Parameters
    - value: String to parse

  ## Returns
    - {:ok, parsed_value} on success
    - {:error, reason} on validation failure

  ## Examples
      iex> ValueParser.parse("42")
      {:ok, 42}

      iex> ValueParser.parse("\"hello world\"")
      {:ok, "hello world"}

      iex> ValueParser.parse("TRUE")
      {:ok, true}
  """

  def parse(value) when is_binary(value) do
    cond do
      value == "NIL" ->
        {:error, "Cannot SET key to NIL"}

      value == "TRUE" ->
        {:ok, true}

      value == "FALSE" ->
        {:ok, false}

      String.match?(value, ~r/^\d+$/) ->
        {:ok, String.to_integer(value)}

      String.starts_with?(value, "\"") ->
        if String.ends_with?(value, "\"") do
          <<"\"", content::binary-size(byte_size(value) - 2), "\"">> = value
          {:ok, String.replace(content, "\\\"", "\"")}
        else
          {:error, "Unclosed string"}
        end

      true ->
        {:ok, value}
    end
  end

  def parse(value) when is_boolean(value), do: {:ok, value}
  def parse(value) when is_integer(value), do: {:ok, value}
  def parse(_), do: {:error, "Invalid value format"}

  @doc """
  Validates a key string according to store rules.

  Keys cannot be:
  - Numeric strings
  - Reserved words (TRUE, FALSE, NIL)

  ## Parameters
    - key: String to validate as key

  ## Returns
    - {:ok, key} if valid
    - {:error, reason} if invalid

  ## Examples
      iex> ValueParser.parse_key("mykey")
      {:ok, "mykey"}

      iex> ValueParser.parse_key("123")
      {:error, "Value 123 is not valid as key"}
  """
  def parse_key(key) when is_binary(key) do
    cond do
      String.match?(key, ~r/^\d+$/) ->
        {:error, "Value #{key} is not valid as key"}

      key in ["TRUE", "FALSE", "NIL"] ->
        {:error, "Value #{key} is not valid as key"}

      true ->
        {:ok, key}
    end
  end

  def parse_key(key), do: {:error, "Value #{inspect(key)} is not valid as key"}
end
