defmodule KvStoreWeb.CommandController do
  use KvStoreWeb, :controller

  alias KvStore.Domain.CommandParser
  alias KvStoreWeb.ResponseFormatter

  @spec execute(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def execute(conn, _params) do
    case CommandParser.parse_and_execute(conn.assigns.raw_body, conn.assigns.client_id) do
      {:ok, result} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, ResponseFormatter.format_success(result))

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, ResponseFormatter.format_error(reason))
    end
  end
end
