defmodule KvStoreWeb.Plugs.ClientIdentifier do
  @moduledoc """
  Plug to handle client identification from request headers
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-client-name") do
      [client_id | _] -> assign(conn, :client_id, client_id)
      [] -> assign(conn, :client_id, generate_client_id())
    end
  end

  defp generate_client_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> String.downcase()
  end
end
