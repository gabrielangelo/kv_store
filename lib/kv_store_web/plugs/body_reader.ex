defmodule KvStoreWeb.Plugs.PlainTextBodyReader do
  @moduledoc """
  A plug that reads the raw request body and adds it to the connection.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, conn} = read_body(conn)
    assigns = %{raw_body: body}
    new_assigns = Map.merge(conn.assigns, assigns)
    %{conn | assigns: new_assigns}
  end
end
