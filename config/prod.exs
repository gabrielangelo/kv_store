# config/prod.exs
import Config

config :kv_store, KvStoreWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "localhost")],
  http: [
    port: String.to_integer(System.get_env("PORT", "4444"))
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

# Runtime config
config :logger, level: :info
