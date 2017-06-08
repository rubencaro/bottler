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
* __green_flag__: wait for the deployed application to signal it's working.
* __deploy__: _release_, _ship_, _install_, _restart_, and then wait for _green_flag_.
* __rollback__: quick _restart_ on a previous release.
* __observer__: opens an observer window connected to given server.
* __exec__: runs given command on every server, showing their outputs.
* __goto__: opens an SSH session with a server on a new terminal window.

You should have public key ssh access to all servers you intend to work with.
Erlang runtime should be installed there too. Everything else, including Elixir
itself, is included in the release.

By now it's not able to deal with all the hot code swap bolts, screws and nuts.
Someday will be.

## Alternative to...

Initially it was an alternative to [exrm](https://github.com/bitwalker/exrm), due to its lack of some features I love.

Recently, after creating and using bottler on several projects for some months, I discovered [edeliver](https://github.com/boldpoker/edeliver) and it looks great! When I have time I will read carefully its code and play differences with bottler, maybe borrow some ideas.

Looking forward to [distillery](https://github.com/bitwalker/distillery) too. The plan is to use it to generate the releases.

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
                               remote_user: "produser",
                               rsa_pass_phrase: "passphrase",
                               cookie: "secretcookie",
                               max_processes: 262144,
                               additional_folders: ["docs"],
                               ship: [timeout: 60_000,
                                      method: :scp],
                               green_flag: [timeout: 30_000],
                               goto: [terminal: "terminator -T '<%= title %>' -e '<%= command %>'"]
                               forced_branch: "master" ]
```

* `servers` - list of servers to deploy on.
* `remote_user` - user name to log in.
* `rsa_pass_phrase` - pass phrase for your SSH keys (We recommend not to put it on plain text here. `System.get_env("RSA_PASS_PHRASE")` would do.).
* `cookie` - distributed Erlang cookie.
* `max_processes` - maximum number of processes allowed on ErlangVM ([see here](http://erlang.org/doc/man/erl.html#max_processes)). Defaults to `262144`.
* `additional_folders` - additional folders to include in the release under
   the `lib` folder.
* `ship` - options for the `ship` task
  * `timeout` - timeout millis for shipment through scp, defaults to 60_000
  * `method` - method of shipment, one of (`:scp`, `:remote_scp`, etc..)
* `green_flag` - options for the `green_flag` task
  * `timeout` - timeout millis waiting for green flags, defaults to 30_000
* `goto` - options for the `goto` task
  * `terminal` - template for the actual terminal command
* `forced_branch` - only allow executing _dangerous_ tasks when local git is on given branch

Then you can use the tasks like `mix bottler.release`. Take a look at the docs for each task with `mix help <task>`.

`prod` environment is used by default. Use like `MIX_ENV=other_env mix bottler.taskname` to force it to `other_env`.

You may also want to add `<project>/rel` and `<project>/.bottler` to your `.gitignore` if you don't want every generated file, including release `.tar.gz`, get into your repo.

## Release

Build a release file. Use like `mix bottler.release`.

Any script (or `EEx` template) on a `lib/scripts folder` will be included into the release package. The `install` task also links that folder directly from the current release, so you can see your scripts on production inside `$HOME/<project>/current/scripts`. The contents of the folder will be merged with the own `bottler` `lib/scripts` folder. Take a look at it for examples ( https://github.com/rubencaro/bottler/tree/master/lib/scripts ).

## Ship

Ship a release file to configured remote servers.
Use like `mix bottler.ship`.

You can configure some things about it, under the _ship_ section:
* __timeout__: The timeout that applies to the upload process.
* __method__: One of:
  * __scp__: Straight _scp_ from the local machine to every target server.
  * __remote_scp__: Upload the release only once from your local machine to the first configured server, and then _scp_ remotely to every other target.

## Install

Install a shipped file on configured remote servers.
Use like `mix bottler.install`.

## Restart

Touch `tmp/restart` on configured remote servers.
That expects to have `Harakiri` or similar software reacting to that.
Use like `mix bottler.restart`.

## Alive Loop

Tipically implemented on production like this:

```elixir
@doc """
Tell the world outside we are alive
"""
def alive_loop(opts \\ []) do
  # register the name if asked
  if opts[:name], do: Process.register(self,opts[:name])

  :timer.sleep 5_000
  tmp_path = Application.get_env(:myapp, :tmp_path) |> Path.expand
  {_, _, version} = Application.started_applications |> Enum.find(&(match?({:myapp, _, _}, &1)))
  :os.cmd 'echo \'#{version}\' > #{tmp_path}/alive'
  alive_loop
end
```

And run by a `Task` on the supervision tree like this:

```elixir
worker(Task, [MyApp, :alive_loop, [[name: MyApp.AliveLoop]]])
```

It touches the `tmp/alive` file every ~5 seconds, so anyone outside of the ErlangVM can tell if the app is actually running.

### Watchdog script for crontab

Among the generated scripts, put by the _deploy_ task inside `$HOME/<project>/current/scripts`, there's a `watchdog.sh` meant to be run by `cron`.

That script checks the _mtime_ of the `tmp/alive` file to ensure that it's younger than 60 seconds. If it's not, then it starts the application. If the application is running, the watchdog script will not even try to start it again.

### Green Flag Test

A task to wait until the contents of `tmp/alive` file matches the version of the `current` release, or the given timeout is reached.

Use like `mix bottler.green_flag`.

If you have special needs with the start of your application, such as to wait for some cache to fill or some connections to be made, then you just have to control the actual value that is written on the `alive` file. __It has to match the new version only when everything is ready to work.__ You can use an `Agent` like:

```elixir
@doc """
Tell the world outside we are alive
"""
def alive_loop(opts \\ []) do
  #...
  version = Agent.get(:version_holder, &(&1))
  #...
end
```

## Deploy

Build a release file, ship it to remote servers, install it, and restart
the app. Then it waits for the green flag test. No hot code swap for now.

Use like `mix deploy`.

## Rollback

Simply move the _current_ link to the previous release and restart to
apply. It's also possible to deploy a previous release, but this is
quite faster.

Be careful because the _previous release_ may be different on each server.
It's up to you to keep all your servers rollback-able (yeah).

Use like `mix bottler.rollback`.

## Observer

Use like `mix observer server1`

It takes the ip of the given server from configuration, then opens a double SSH tunnel with its epmd service and its application node. Then executes an elixir script which spawns an observer window locally, connected with the tunnelled node. You just need to select the remote node from the _Nodes_ menu.

## Exec

Use like `mix bottler.exec 'ls -alt some/path'`

It runs the given command through parallel SSH connections with all the configured servers. It accepts an optional _--timeout_ parameter.

## Goto

Use like `mix goto server1`

It opens an SSH session on a new terminal window on the server with given name. The actual `terminal` command can be configured as a template.

## GCE support

Whenever you can use Google's `gcloud` from your computer (i.e. authenticate and see if it works), you can configure `bottler` to use it too to get your instances IP addresses. Instead of:

```elixir
    servers: [server1: [ip: "1.1.1.1"],
              server2: [ip: "1.1.1.2"]]
```

You just do:
```elixir
    servers: [gce_project: "project-id", match: "regexstr"]
```
When you perform an operation on a server, its ip will be obtained using `gcloud` command. You don't need to reserve more static IP addresses for your instances.

Optionally you can give a `match` regex string to default filter server names given by gcloud. Just the same you would give to the `--servers` switch of the tasks. This filter will be added to the one given at the commandline switch. I.e. if you configure `match` and then pass `--servers`, then only servers with a name that matches both regexes will pass.

## TODOs

* Use [distillery](https://github.com/bitwalker/distillery)
* Add more testing
* Separate section for documenting every configuration option
* Get it stable on production
* Get it decent enough to be published
* Complete README
* Rollback to _any_ previous version
* Support for hot code upgrades, and other non basic features of `distillery`
* Support for hooks
* Add support for deploy to AWS instances [*](https://github.com/gleber/erlcloud)[*](notes/aws.md)
* Maybe get it to 1.0, remove `BETA` tag, and actually support other users.

## Changelog

### master

### 0.8.0

* Add coverage analysis and `credo`
* Better `in_tasks`
* Remove 1.4 warnings
* Configurable `max_processes`
* Log using server names
* Fix some `scp` glitches when shipping between servers
* Support for `Regex` on server names
* Green flag support.
* Support for forced release branch
* Log guessed server ips
* Options to filter target servers from command line
* Resolve server ips only once
* Add support for deploy to GCE instances
* remove `helper_scripts` task
* `goto` task
* Use SSHEx 2.1.0
* Cookie support
* configurable shipment timeout
* `erl_connect` (no Elixir needed on target)
* `observer` task
* `bottler.exec` task
* `remote_scp` shipment support
* log erts versions on both sides

### 0.5.0

* Use new SSHEx 1.1.0

### 0.4.1

* Fix `:ssh` sometimes not started on install.

### 0.4.0

* Use [SSHEx](https://github.com/rubencaro/sshex)
* Add __helper_scripts__

### 0.3.0

* Individual tasks for each step
* Add connect script
* Add fast rollback
* Few README improvements

### 0.2.0

* First package released
