# Bottler (BETA)

Bottler is a collection of tools that aims to help you generate releases, ship
them to your servers, install them there, and get them live on production.

## What

Four main tools, that can be used separately:

* __release__: generate `tar.gz` files with your app and its dependencies (not
including the whole `erts` by now).
* __ship__: ship your generated `tar.gz` via `scp` to every server you configure.
* __install__: properly install your shipped release on each of those servers.
* __restart__: fire a quick restart to apply the newly installed release if you
are using [Harakiri](http://github.com/admanmedia/harakiri).

You should have public key ssh access to all servers you intend to work with.
Erlang runtime should be installed there too. Everything else, including Elixir
itself, is included in the release.

By now it's not able to deal with all the how code swap bolts, screws and nuts.
Maybe someday will be.

## Use

Add to your `deps` like this:

```elixir
    {:bottler, github: "elpulgardelpanda/bottler"}
```

On your config:

```elixir
    config :bottler, :servers, [server1: [public_ip: "123.123.123.123"],
                                server2: [public_ip: "123.123.123.123"]]
```

Then you can use the tasks like `MIX_ENV=prod mix release`. Take a look at the
docs for each task with `mix help <task>`.

## Release

## Ship

## Install

## Restart

## TODOs

* Some minimal testing
* Get it stable on production
* Complete README
* Add to hex
* Add to travis
* Optionally include `erts`
* Use scalable middleplace to ship releases
* Allow hot code swap?
* Support for hooks
* Add tools for docker deploys
