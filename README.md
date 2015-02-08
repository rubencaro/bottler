# Bottler (BETA)

[![Build Status](https://travis-ci.org/elpulgardelpanda/bottler.svg?branch=master)](https://travis-ci.org/elpulgardelpanda/bottler)
[![Hex Version](http://img.shields.io/hexpm/v/bottler.svg?style=flat)](https://hex.pm/packages/bottler)

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
    config :bottler, :params, [servers: [server1: [ip: "1.1.1.1"],
                                         server2: [ip: "1.1.1.2"]],
                               remote_user: "produser" ]
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

* Add more testing
* Get it stable on production
* Add fast rollback (to any of previous versions)
* Options to filter target servers from command line
* Wait until _current_ release is seen running.
* Complete README
* Optionally include `erts` (now we can ship openssl too see [here](http://www.erlang.org/download/otp_src_17.4.readme))
* Use scalable middleplace to ship releases
* Allow hot code swap?
* Support for hooks
* Add tools for docker deploys

## Changelog

### 0.3.0

* Individual tasks for each step
* Add connect script

### 0.2.0

* First package released
