defmodule KvStoreWeb.Router do
  use KvStoreWeb, :router

  pipeline :command_api do
    plug(KvStoreWeb.Plugs.ClientIdentifier)
    plug(:accepts, ["text"])
    plug(KvStoreWeb.Plugs.PlainTextBodyReader)
  end

  scope "/", KvStoreWeb do
    pipe_through(:command_api)
    post("/", CommandController, :execute)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:kv_store, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: KvStoreWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
