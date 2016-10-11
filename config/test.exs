use Mix.Config

config :heimdall, marathon_url: "http://localhost:8889"
config :heimdall, forward_url: "http://localhost:8082"
config :heimdall, register_marathon: false
config :heimdall, require_marathon: false
config :heimdall, port: 4000
