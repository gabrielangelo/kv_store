defmodule KvStoreWeb.CommandController do
  use KvStoreWeb, :controller

  alias KvStore.Domain.CommandParser
  alias KvStoreWeb.ResponseFormatter

  def execute(conn, _params) do
    client = conn.assigns.client_id
    command = conn.body_params

    case CommandParser.parse_and_execute(command, client) do
      {:ok, response} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, ResponseFormatter.format_success(response))

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, ResponseFormatter.format_error(reason))
    end
  end
end
