# Bottler (BETA)

[![Build Status](https://travis-ci.org/rubencaro/bottler.svg?branch=master)](https://travis-ci.org/rubencaro/bottler)
[![Hex Version](http://img.shields.io/hexpm/v/bottler.svg?style=flat)](https://hex.pm/packages/bottler)
[![Hex Version](http://img.shields.io/hexpm/dt/bottler.svg?style=flat)](https://hex.pm/packages/bottler)

Bottler is a collection of tools that aims to help you generate releases, ship
them to your servers, install them there, and get them live on production.

## What

Several tools that can be used separately:

* __release__: generate `tar.gz` files with your app and its dependencies (not
including the whole `erts` by now).
* __ship__: ship your generated `tar.gz` via `scp` to every server you configure.
* __install__: properly install your shipped release on each of those servers.
* __restart__: fire a quick restart to apply the newly installed release if you
are using [Harakiri](http://github.com/rubencaro/harakiri).
* __deploy__: _release_, _ship_, _install_ and then _restart_.
* __rollback__: quick _restart_ on a previous release.
* __helper_scripts__: generate some helper scripts based on project config.

You should have public key ssh access to all servers you intend to work with.
Erlang runtime should be installed there too. Everything else, including Elixir
itself, is included in the release.

By now it's not able to deal with all the hot code swap bolts, screws and nuts.
Someday will be.

## Alternative to...

Initially it was an alternative to [exrm](https://github.com/bitwalker/exrm), due to its lack of some features I love.

Recently, after creating and using bottler on several projects for some months, I discovered [edeliver](https://github.com/boldpoker/edeliver) and it looks great! When I have time I will read carefully its code and play differences with bottler, maybe borrow some ideas.

## Use

Add to your `deps` like this:

```elixir
    {:bottler, " >= 0.5.0"}
```

Or if you want to take a walk on the wild side:

```elixir
    {:bottler, github: "rubencaro/bottler"}
```

On your config:

```elixir
    config :bottler, :params, [servers: [server1: [ip: "1.1.1.1"],
                                         server2: [ip: "1.1.1.2"]],
                               remote_user: "produser" ]
```

Then you can use the tasks like `mix bottler.release`. Take a look at the docs for each task with `mix help <task>`.

`prod` environment is used by default. Use like `MIX_ENV=other_env mix bottler.taskname` to force it to `other_env`.

You may also want to add `<project>/rel` and `<project>/.bottler` to your `.gitignore` if you don't want every generated file, including release `.tar.gz`, get into your repo.

## Release

Build a release file. Use like `mix bottler.release`.

## Ship

Ship a release file to configured remote servers.
Use like `mix bottler.ship`.

## Install

Install a shipped file on configured remote servers.
Use like `mix bottler.install`.

## Restart

Touch `tmp/restart` on configured remote servers.
That expects to have `Harakiri` or similar software reacting to that.
Use like `mix bottler.restart`.

## Deploy

Build a release file, ship it to remote servers, install it, and restart
the app. No hot code swap for now.

Use like `mix deploy`.

## Rollback

Simply move the _current_ link to the previous release and restart to
apply. It's also possible to deploy a previous release, but this is
quite faster.

Be careful because the _previous release_ may be different on each server.
It's up to you to keep all your servers rollback-able (yeah).

Use like `mix bottler.rollback`.

## Helper Scripts

This generates some helper scripts using project's current config information, such as target servers. You can run this task repeatedly to force regeneration of these scripts to reflect config changes.

Generated scripts are located under `<project>/.bottler/scripts` (configurable via `scripts_folder`). It will also generate links to those scripts on a configurable folder to add them to your system PATH. The configuration param is `into_path_folder`. Its default value is `~/local/bin`.

Use like `mix bottler.helper_scripts`.

The generated scripts' list is short by now:

* A `<project>_<server>` script for each target server configured. That script will open an SSH session with this server. When you want to access one of your production servers, the one that is called `daisy42`, for the project called `motion`, then you can invoke `motion_daisy42` on any terminal and it will open up an SSH shell for you.

## TODOs

* Add more testing
* Separate section for documenting every configuration option
* Get it stable on production
* Options to filter target servers from command line
* Wait until _current_ release is seen running.
* Complete README
* Rollback to _any_ previous version
* Optionally include `erts` (now we can ship openssl too see [here](http://www.erlang.org/download/otp_src_17.4.readme))
* Use scalable middleplace to ship releases [*](notes/scalable_shipment.md)
* Allow hot code swap (just follow [this](http://erlang.org/doc/design_principles/release_handling.html) to prepare the release, and then provide an example of [Harakiri](http://github.com/rubencaro/harakiri) action that actually performs the upgrade)
* Support for hooks
* Add tools for docker deploys
* Add support for deploy to AWS instances [*](https://github.com/gleber/erlcloud)[*](notes/aws.md)
* Add support for deploy to GCE instances

## Changelog

### master

* Use SSHEx 2.0.0

### 0.5.0

* Use new SSHEx 1.1.0

### 0.4.1

* Fix `:ssh` sometimes not started on install.

### 0.4.0

* Use [SSHEx](https://github.com/elpulgardelpanda/sshex)
* Add __helper_scripts__

### 0.3.0

* Individual tasks for each step
* Add connect script
* Add fast rollback
* Few README improvements

### 0.2.0

* First package released
