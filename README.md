# Heimdall

Heimdall is an API Gateway for Mesos and Marathon. It routes requests through
routes and filters dynamically loaded from Marathon before forwarding them
to their intended services.

## Usage

When the application starts, it will attempt to register itself as a 
Marathon subscriber. Once registered as a callback, Heimdall will start 
listening for change events from Marathon, reloading its dynamic 
routing config on each change.

Dynamic routing configuration is done through marathon labels. There are 4 
labels used to decide how a request gets routed for an app:
 * `heimdall.host` (required) - routes a request only if its host matches this
 * `heimdall.path` (required) - path prefix the request must match (the prefix is stripped from the forwarded request)
 * `heimdall.filters` - a JSON list of plugs to filter the request through before sending it back off
 * `heimdall.opts` - a JSON object of options that gets passed into each plug

Filters can be view as a pipeline of plugs (simple functions that take a 
request and return a changed request or a response), 
with the final plug forwarding the request to the place it actually needs
 to go. The pipeline is built in the order that the plugs are listed in the
config. In other words, if `heimdal.filters` is:
`["Plugs.First", "Plugs.Second"]`
 the pipeline would look like:
`Request -> Plugs.First -> Plugs.Second -> Heimdall.Plug.ForwardRequest -> Microservice`

Ideally, Heimdall should forward request to a load balancer that knows how to
send the request to an actual instance of the microservice it's trying to get
to. Some recommend solutions for this are [traefik](https://github.com/containous/traefik), [Minuteman](https://github.com/dcos/minuteman), or your own
custom nginx config. The default forward url (ie the location of the load
balancer) is an OTP application setting, `:default_forward_url`. If you
wish to set the forward location on a per service basis, you can set 
`forward_url` in `heimdall.opts` (this gets passed to `Heimdall.Plug.ForwardRequest`

## Installation

The package can be installed and used as an OTP application in your project:

  1. Add `heimdall` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:heimdall, "~> 0.1.0"}]
    end
    ```

  2. Ensure `heimdall` is started before your application:

    ```elixir
    def application do
      [applications: [:heimdall]]
    end
    ```

  3. Create a plug to filter request through

    ```elixir
    defmodule Heimdall.Plug.AddApplicationHeader do
      import Plug.Conn

      def init(opts), do: opts

      def call(conn, _opts) do
        conn
        |> put_req_header("some-header", "a header value")
      end
    end
    ```

  4. Add heimdall labels to your marathon app config

    ``` json
    {
      "id": "/test-app",
      "cmd": null,
      "cpus": 1,
      ...
      "labels": {
        "heimdall.path": "/test",
        "heimdall.options": "{\"forward_url\": \"http://localhost:8081/test\"}",
        "heimdall.host": "localhost",
        "heimdall.filters": "[\"Plug.Test1\", \"Plug.Test2\"]",
      },
      ...
    }
    ```

  5. Start your server with `mix server`
    **NOTE:** Marathon must be available, and Heimdall must be configured to
    reach it before you can start your server. See `config/dev.exs` for a 
    list of configurations.
