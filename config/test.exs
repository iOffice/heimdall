use Mix.Config

config :heimdall,
  marathon_url: "http://localhost:8889",
  default_forward_url: "http://localhost:8082",
  register_marathon: false,
  require_marathon: false,
  port: 4000
