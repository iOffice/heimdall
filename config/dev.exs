use Mix.Config

config :heimdall, marathon_url: "http://mesos:8080",
  default_forward_url: "http://mesos",
  register_marathon: true,
  port: 4000
