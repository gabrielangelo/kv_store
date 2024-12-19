defmodule KvStoreWeb.ResponseFormatter do
  @moduledoc """
  Formats responses according to the key-value store protocol specification.
  """

  @doc """
  Formats successful responses
  """
  def format_success(data)

  def format_success(%{old_value: old_value, new_value: new_value}) do
    "#{format_value(old_value)} #{format_value(new_value)}"
  end

  def format_success("OK"), do: "OK"

  def format_success(value), do: format_value(value)

  @doc """
  Formats error messages by prefixing with ERR and adding quotes
  """
  def format_error(message) when is_atom(message) do
    format_error(Atom.to_string(message))
  end

  def format_error(message) when is_binary(message) do
    ~s(ERR "#{String.replace(message, "\"", "\\\"")}")
  end

  @doc """
  Formats a single value according to the protocol rules
  """
  def format_value(nil), do: "NIL"
  def format_value(true), do: "TRUE"
  def format_value(false), do: "FALSE"
  def format_value(value) when is_integer(value), do: to_string(value)

  def format_value(value) when is_binary(value) do
    cond do
      String.contains?(value, " ") -> quote_string(value)
      String.match?(value, ~r/^\d+$/) -> quote_string(value)
      value in ["TRUE", "FALSE", "NIL"] -> quote_string(value)
      String.contains?(value, "\"") -> quote_string(value)
      true -> value
    end
  end

  defp quote_string(value) do
    escaped = String.replace(value, "\"", "\\\"")
    ~s("#{escaped}")
  end
end
