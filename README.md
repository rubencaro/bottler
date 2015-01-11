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
are using [Harakiri](http://github.com/elpulgardelpanda/harakiri).

You should have public key ssh access to all servers you intend to work with.
Erlang runtime should be installed there too. Everything else, including Elixir
itself, is included in the release.

By now it's not able to deal with all the hot code swap bolts, screws and nuts.
Maybe someday will be.

## Use

Add to your `deps` like this:

```elixir
    {:bottler, github: "elpulgardelpanda/bottler"}
```

On your config:

```elixir
    config :bottler, :servers, [server1: [user: "myuser", ip: "1.1.1.1"],
                                server2: [user: "myuser", ip: "1.1.1.2"]]

    config :bottler, :mixfile, Myapp.Mixfile
```

Then you can use the tasks like `mix release`. Take a look at the
docs for each task with `mix help <task>`.

## Release

Build a release file. Use like `mix release`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix release` to force it to `other_env`.

## Ship

## Install

## Restart

## Deploy

Build a release file, ship it to remote servers, install it, and restart
the app. No hot code swap for now.

Use like `mix deploy`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix deploy` to force it to `other_env`.

## TODOs

* Fix loading the production config by default
* Include own iex app
* At least some minimal testing
* Get it stable on production
* Individual tasks for each step
* Complete README
* Add to hex
* Add to travis
* Optionally include `erts` (now we can ship openssl too see [here](http://www.erlang.org/download/otp_src_17.4.readme))
* Use scalable middleplace to ship releases
* Allow hot code swap?
* Support for hooks
* Add tools for docker deploys
