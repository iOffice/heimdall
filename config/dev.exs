use Mix.Config

config :heimdall, marathon_url: "http://localhost:8080"
config :heimdall, forward_url: "http://localhost:8081"
config :heimdall, require_marathon: true
config :heimdall, port: 4000
