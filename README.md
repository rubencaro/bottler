# Bottler (BETA)

[![Build Status](https://travis-ci.org/elpulgardelpanda/bottler.svg?branch=master)](https://travis-ci.org/elpulgardelpanda/bottler)
[![Hex Version](http://img.shields.io/hexpm/v/bottler.svg?style=flat)](https://hex.pm/packages/bottler)

Bottler is a collection of tools that aims to help you generate releases, ship
them to your servers, install them there, and get them live on production.

## What

Several tools that can be used separately:

* __release__: generate `tar.gz` files with your app and its dependencies (not
including the whole `erts` by now).
* __ship__: ship your generated `tar.gz` via `scp` to every server you configure.
* __install__: properly install your shipped release on each of those servers.
* __restart__: fire a quick restart to apply the newly installed release if you
are using [Harakiri](http://github.com/elpulgardelpanda/harakiri).
* __deploy__: _release_, _ship_, _install_ and then _restart_.
* __rollback__: quick _restart_ on a previous release.

You should have public key ssh access to all servers you intend to work with.
Erlang runtime should be installed there too. Everything else, including Elixir
itself, is included in the release.

By now it's not able to deal with all the hot code swap bolts, screws and nuts.
Someday will be.

## Use

Add to your `deps` like this:

```elixir
    {:bottler, " >= 0.2.0"}
```

Or if you want to take a walk on the wild side:

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

Build a release file. Use like `mix bottler.release`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix bottler.release` to force it to `other_env`.

## Ship

Ship a release file to configured remote servers.
Use like `mix bottler.ship`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix bottler.ship` to force it to `other_env`.

## Install

Install a shipped file on configured remote servers.
Use like `mix bottler.install`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix bottler.install` to force it to `other_env`.

## Restart

Touch `tmp/restart` on configured remote servers.
That expects to have `Harakiri` or similar software reacting to that.
Use like `mix bottler.restart`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix bottler.restart` to force it to `other_env`.

## Deploy

Build a release file, ship it to remote servers, install it, and restart
the app. No hot code swap for now.

Use like `mix deploy`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix deploy` to force it to `other_env`.

## Rollback

Simply move the _current_ link to the previous release and restart to
apply. It's also possible to deploy a previous release, but this is
quite faster.

Be careful because the _previous release_ may be different on each server.
It's up to you to keep all your servers rollback-able (yeah).

Use like `mix bottler.rollback`.

`prod` environment is used by default. Use like
`MIX_ENV=other_env mix bottler.rollback` to force it to `other_env`.

## TODOs

* Add more testing
* Get it stable on production
* Options to filter target servers from command line
* Wait until _current_ release is seen running.
* Complete README
* Rollback to _any_ previous version
* Optionally include `erts` (now we can ship openssl too see [here](http://www.erlang.org/download/otp_src_17.4.readme))
* Use scalable middleplace to ship releases
* Allow hot code swap
* Support for hooks
* Add tools for docker deploys

## Changelog

### 0.3.0

* Individual tasks for each step
* Add connect script
* Add fast rollback
* Few README improvements

### 0.2.0

* First package released
