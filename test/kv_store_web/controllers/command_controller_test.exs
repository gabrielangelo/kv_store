defmodule KvStoreWeb.CommandControllerTest do
  use KvStoreWeb.ConnCase
  @moduletag :capture_log

  @storage_file "storage.dat"
  @transactions_dir "transactions"

  setup do
    File.rm(@storage_file)
    File.rm_rf(@transactions_dir)

    client_id = "test_#{System.unique_integer([:positive])}"

    conn =
      build_conn()
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("x-client-name", client_id)

    on_exit(fn ->
      File.rm(@storage_file)
      File.rm_rf(@transactions_dir)
    end)

    {:ok, %{conn: conn, client_id: client_id}}
  end

  describe "POST / - Basic Operations" do
    test "handles SET command with different value types", %{conn: conn} do
      assert "NIL 42" =
               conn
               |> post("/", "SET number_key 42")
               |> response(200)

      assert "NIL simple_string" =
               conn
               |> post("/", "SET string_key simple_string")
               |> response(200)

      assert ~s(NIL "hello world") =
               conn
               |> post("/", ~s(SET quoted_key "hello world"))
               |> response(200)

      assert "NIL TRUE" =
               conn
               |> post("/", "SET bool_key TRUE")
               |> response(200)

      assert "TRUE FALSE" =
               conn
               |> post("/", "SET bool_key FALSE")
               |> response(200)
    end

    test "handles GET command", %{conn: conn} do
      assert "NIL" =
               conn
               |> post("/", "GET nonexistent")
               |> response(200)

      assert "NIL test_value" =
               conn
               |> post("/", "SET test_key test_value")
               |> response(200)

      assert "test_value" =
               conn
               |> post("/", "GET test_key")
               |> response(200)
    end

    test "handles value updates", %{conn: conn} do
      assert "NIL initial" =
               conn
               |> post("/", "SET update_key initial")
               |> response(200)

      assert "initial updated" =
               conn
               |> post("/", "SET update_key updated")
               |> response(200)

      assert "updated" =
               conn
               |> post("/", "GET update_key")
               |> response(200)
    end
  end

  describe "POST / - Transaction Operations" do
    test "handles successful transaction flow", %{conn: conn} do
      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "NIL tx_value" =
               conn
               |> post("/", "SET tx_key tx_value")
               |> response(200)

      assert "OK" =
               conn
               |> post("/", "COMMIT")
               |> response(200)

      assert "tx_value" =
               conn
               |> post("/", "GET tx_key")
               |> response(200)
    end

    test "handles transaction rollback", %{conn: conn} do
      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "NIL rollback_value" =
               conn
               |> post("/", "SET rollback_key rollback_value")
               |> response(200)

      assert "OK" =
               conn
               |> post("/", "ROLLBACK")
               |> response(200)

      assert "NIL" =
               conn
               |> post("/", "GET rollback_key")
               |> response(200)
    end

    test "handles transaction isolation", %{conn: conn, client_id: client_id} do
      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "NIL isolated_value" =
               conn
               |> post("/", "SET isolated_key isolated_value")
               |> response(200)

      other_conn =
        build_conn()
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("x-client-name", "other_#{client_id}")

      assert "NIL" =
               other_conn
               |> post("/", "GET isolated_key")
               |> response(200)
    end
  end

  describe "POST / - Error Handling" do
    test "handles invalid commands", %{conn: conn} do
      assert "ERR \"Invalid command\"" =
               conn
               |> post("/", "INVALID_COMMAND")
               |> response(400)

      assert "ERR \"Invalid command\"" =
               conn
               |> post("/", "")
               |> response(400)
    end

    test "handles invalid keys", %{conn: conn} do
      assert "ERR \"Value 123 is not valid as key\"" =
               conn
               |> post("/", "SET 123 value")
               |> response(400)

      assert "ERR \"Value TRUE is not valid as key\"" =
               conn
               |> post("/", "SET TRUE value")
               |> response(400)
    end

    test "handles invalid values", %{conn: conn} do
      assert "ERR \"Cannot SET key to NIL\"" =
               conn
               |> post("/", "SET test_key NIL")
               |> response(400)
    end

    test "handles transaction errors", %{conn: conn} do
      assert "ERR \"no_transaction\"" =
               conn
               |> post("/", "COMMIT")
               |> response(400)

      assert "ERR \"No active transaction\"" =
               conn
               |> post("/", "ROLLBACK")
               |> response(400)

      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "ERR \"Already in transaction\"" =
               conn
               |> post("/", "BEGIN")
               |> response(400)
    end
  end

  describe "POST / - Client Identification" do
    test "uses client header for identification", %{conn: conn} do
      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "OK" =
               build_conn()
               |> put_req_header("content-type", "text/plain")
               |> post("/", "BEGIN")
               |> response(200)
    end

    test "maintains isolation between clients", %{conn: conn, client_id: client_id} do
      assert "OK" =
               conn
               |> post("/", "BEGIN")
               |> response(200)

      assert "NIL client_value" =
               conn
               |> post("/", "SET client_key client_value")
               |> response(200)

      other_conn =
        build_conn()
        |> put_req_header("content-type", "text/plain")
        |> put_req_header("x-client-name", "other_#{client_id}")

      assert "NIL" =
               other_conn
               |> post("/", "GET client_key")
               |> response(200)

      assert "OK" =
               other_conn
               |> post("/", "BEGIN")
               |> response(200)
    end
  end

  test "enforces transaction atomicity", %{conn: conn} do
    assert response(post(conn, "/", "SET atomic_key initial"), 200) == "NIL initial"
    assert response(post(conn, "/", "BEGIN"), 200) == "OK"
    assert response(post(conn, "/", "GET atomic_key"), 200) == "initial"

    other_conn =
      build_conn()
      |> put_req_header("content-type", "text/plain")
      |> put_req_header("x-client-name", "other_client")

    assert response(post(other_conn, "/", "SET atomic_key modified"), 200) == "initial modified"
    assert response(post(conn, "/", "COMMIT"), 400) == "ERR \"Atomicity failure (atomic_key)\""
  end
end
