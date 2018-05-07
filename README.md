# Heimdall

![Heimdall gif](http://i.giphy.com/tGdiW9jzL64Cs.gif)

Heimdall is an API Gateway for Mesos and Marathon. It routes requests through
filters dynamically loaded from Marathon before forwarding them
to their intended services.

## Usage

When the application starts, it will attempt to register itself as a 
Marathon subscriber. Once registered Heimdall will start 
listening for change events from Marathon, reloading its dynamic 
routing config on each change.

Dynamic routing configuration is done through Marathon labels. There are several 
labels used to decide how a request gets routed for an app:
 * `heimdall.host` (required) - routes a request only if its host matches this value
 * `heimdall.path` (required) - path prefix the request must match (the prefix is stripped from the forwarded request)
 * `heimdall.filters` - a JSON list of plugs through which to filter the request before sending it back off
 * `heimdall.opts` - a JSON object of options that gets passed into each plug
 * `heimdall.strip_path` - a boolean flag that whether the matched path should be removed when forwarding the request
 * `heimdall.proxy_path` - a path that is appended to the beginning of the forwarded path
 * `heimdall.entrypoints` - a JSON list of objects of several entrypoints described [below](#multiple-entrypoints)

Filters can be viewed as a pipeline of plugs (simple functions that take a 
request and return a changed request or a response), 
with the final plug forwarding the request to the place it actually needs
 to go. The pipeline is built in the order that the plugs are listed in the
config. In other words, if `heimdal.filters` is: `["Plugs.First", "Plugs.Second"]`
 the pipeline would have the following flow:

`Request -> Plugs.First -> Plugs.Second -> Heimdall.Plug.ForwardRequest -> Microservice`

Additionally, if you have a filter that needs to be to run before every request, you can
add it to the OTP application config `:filter_before_all`, which is a list of plugs that
run for every request. This is useful for things that should happen globally, like caching
and monitoring.
Similarly, you can specify a global keyword list of opts to pass into every plug with
`:global_opts`. These values will be overwritten by the service's `heimdall.opts` config.

Ideally, Heimdall should forward requests to a load balancer that knows how to
send each request to an actual instance of the microservice it's trying to get
to. Some recommended solutions for this are [traefik](https://github.com/containous/traefik), 
[Minuteman](https://github.com/dcos/minuteman), or your own
custom nginx config. The default forward url (ie the location of the load
balancer) is an OTP application setting, `:default_forward_url` (see `config/dev.exs`
for an example of the config). If you wish to set the forward location on 
a per service basis, you can set `forward_url` in `heimdall.opts` (this gets passed to 
`Heimdall.Plug.ForwardRequest`)

## Multiple Entrypoints

The `heimdall.entrypoints` config option allows a service to have multiple ways to get to the service.
It's a JSON list of objects, and each object is its own heimdall config. For example:
```
{
  "heimdall.path": "/test",
  "heimdall.options": "{\"forward_url\": \"http://localhost:8081\"}",
  "heimdall.filters": "[]",
  "heimdall.entrypoints": "[{\"heimdall.host\": \"example.com\"}, {\"\heimdall.host": \"test.com\"}]"
}
```
This config specifies two entrypoints, so that requests to both `example.com/test` and `test.com/test`
will get forwared to `http://localhost:8081`. Each entrypoint inherits the top level config and can
override values with its own config.

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

  3. Create a plug through which to filter requests

     ```elixir
     defmodule Plug.TestPlug do
       import Plug.Conn

       def init(opts), do: opts

       def call(conn, _opts) do
         conn
         |> put_req_header("some-header", "a header value")
       end
     end
     ```

  4. Add heimdall labels to your Marathon app config

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
         "heimdall.filters": "[\"Plug.TestPlug\", \"AnotherModule.SomeOtherPlug\"]",
       },
       ...
     }
     ```

  5. Start your server with `mix server`.
    **NOTE:** Marathon must be available, and Heimdall must be configured to
    reach it before you can start your server. See `config/dev.exs` for a 
    list of configurations.

  6. Your app can now be reached at `localhost:4000/test`. This will run any
     Plugs configured in your `heimdall.filters` before forwarding the request
     to your app.
