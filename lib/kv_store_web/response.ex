defmodule KvStore.Interface.Http.Response do
  @moduledoc """
  Handles HTTP response formatting and status codes
  """

  defstruct [:status, :body]

  def ok(body) do
    %__MODULE__{
      status: 200,
      body: body
    }
  end

  def error(reason) do
    %__MODULE__{
      status: 400,
      body: "ERR \"#{reason}\""
    }
  end

  def not_found(reason \\ "Not found") do
    %__MODULE__{
      status: 404,
      body: reason
    }
  end
end
