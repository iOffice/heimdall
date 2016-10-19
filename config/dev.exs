use Mix.Config

config :heimdall, marathon_url: "http://localhost:8080",
  default_forward_url: "http://localhost:8081",
  register_marathon: true,
  require_marathon: true,
  port: 4000
