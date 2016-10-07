use Mix.Config

config :heimdall, marathon_url: "http://localhost:8080"
config :heimdall, forward_url: "http://localhost:8082"
config :heimdall, require_marathon: false
config :heimdall, port: 4000
