defmodule KvStore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = get_children()

    opts = [strategy: :one_for_one, name: KvStore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    KvStoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp get_children do
    base_children = [
      KvStoreWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:kv_store, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KvStore.PubSub},
      {Finch, name: KvStore.Finch},
      KvStoreWeb.Endpoint
    ]

    case Mix.env() do
      :test -> base_children
      _ -> base_children
    end
  end
end
