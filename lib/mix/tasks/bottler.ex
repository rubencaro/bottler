require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Deploy do

  @moduledoc """
    Build a release file, ship it to remote servers, install it, and restart
    the app. No hot code swap for now.

    Use like `mix deploy`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix deploy` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    :ok = B.release c
    {:ok, _} = B.ship c
    {:ok, _} = B.install c
    {:ok, _} = B.restart c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Release do

  @moduledoc """
    Build a release file. Use like `mix bottler.release`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.release` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    :ok = B.release c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Ship do

  @moduledoc """
    Ship a release file to configured remote servers.
    Use like `mix bottler.ship`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.ship` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.ship c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Install do

  @moduledoc """
    Install a shipped file on configured remote servers.
    Use like `mix bottler.install`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.install` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.install c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Restart do

  @moduledoc """
    Touch `tmp/restart` on configured remote servers.
    That expects to have `Harakiri` or similar software reacting to that.
    Use like `mix bottler.restart`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.restart` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.restart c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Rollback do

  @moduledoc """
    Simply move the _current_ link to the previous release and restart to
    apply. It's quite faster than to deploy a previous release, that is
    also possible.

    Be careful because the _previous release_ may be different on each server.
    It's up to you to keep all your servers rollback-able (yeah).

    Use like `mix bottler.rollback`.

    `prod` environment is used by default. Use like
    `MIX_ENV=other_env mix bottler.rollback` to force it to `other_env`.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    {:ok, _} = B.rollback c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.HelperScripts do

  @moduledoc """
  This generates some helper scripts using project's current config
  information, such as target servers. You can run this task repeatedly to
  force regeneration of these scripts to reflect config changes.

  Generated scripts are located under `<project>/.bottler/scripts` (configurable
  via `scripts_folder`). It will also generate links to those scripts on a
  configurable folder to add them to your system PATH. The configuration param
  is `script_links_folder`. Its default value is `~/local/bin`.

  Use like `mix bottler.helper_scripts`.

  The generated scripts' list is short by now:

  * A `<project>_<server>` script for each target server configured. That script
  will open an SSH session with this server. When you want to access one of your
  production servers, the one that is called `daisy42`, for the project called
  `motion`, then you can invoke `motion_daisy42` on any terminal and it will
  open up an SSH shell for you.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    :ok = B.helper_scripts c
    :ok
  end

end

defmodule Mix.Tasks.Bottler.Observer do
  use Mix.Task

  def run(args) do
    args |> inspect |> IO.puts

    H.set_prod_environment
    c = H.read_and_validate_config
    c |> inspect |> IO.puts
    port = get_port(c, args)
    IO.puts port

    ip = args |> List.first

    # auto closing tunnel
    :os.cmd('killall epmd') # free distributed erlang port
    cmd = "ssh -f -L 4369:localhost:4369 -L #{port}:localhost:#{port} epdp@#{ip} sleep 30;" |> to_char_list
    IO.puts cmd
    :os.cmd(cmd)

    # observer
    # cmd = "erl -name observerunique@127.0.0.1 -setcookie monikako -run observer -nohalt &" |> to_char_list
    cmd = "elixir --name observerunique@127.0.0.1 --cookie monikako --no-halt lib/mix/scripts/observer.exs" |> to_char_list
    :os.cmd(cmd)
    # observer_pid = :os.cmd('pgrep -f observerunique')
    # port = :erlang.open_port({:spawn, cmd}, [])
    # port = :erlang.open_port({:spawn_executable, 'erl'}, [{:args, ['-name', 'observer@127.0.0.1', '-setcookie', 'monikako', '-run', 'observer', '-nohalt']}])
    # observer_pid = :erlang.port_info(port)[:os_pid]

    # :timer.sleep 5_000

    # t = Task.async(fn-> wait_for_observer_to_end() end) |> Task.await
    # IO.puts "Now kill observer pid #{observer_pid}"
    # :os.cmd("kill #{observer_pid}" |> to_char_list)

    #
    # Mix.Task.run "run", ["lib/mix/scripts/observer.exs", "--no-halt", port] ++ args
    #
    # cmd = "ssh -f -L 4369:localhost:4369 -L #{port}:localhost:#{port} epdp@#{args |> List.first} sleep 30"
    # IO.puts cmd
    # :os.cmd('erl -name observer@127.0.0.1 -setcookie monikako -run observer')

    # {:ok, _} = Task.start_link(fn->
    #   tunnel_cmd = 'wc /dev/zero'
    #   IO.puts "Opening tunnel with '#{tunnel_cmd}'"
    #   port = :erlang.open_port({:spawn, tunnel_cmd}, [])
    #   pid = :erlang.port_info(port)[:os_pid]
    #   IO.puts "Opened tunnel has pid: #{pid}"
    #   System.at_exit(fn(_)->
    #     IO.puts "Killing pid: #{pid}"
    #     cmd = "kill #{pid}" |> to_char_list
    #     :os.cmd(cmd)
    #   end)
    # end)
    # IO.puts "Waiting for tunnel logic..."
    IO.puts "Done"
  end

  defp wait_for_observer_to_end do
    IO.puts "."
    try do
      :observer_wx.get_attrib({:font, :fixed})
      :timer.sleep 2_000
      wait_for_observer_to_end
    rescue
      x in [ErlangError] -> x |> inspect |> IO.puts
    end
  end

  defp get_port(c, args) do
    # cmd = "ssh #{c[:remote_user]}@#{args |> List.first} \"source /home/#{c[:remote_user]}/.bash_profile && epmd -names\" | grep dean | cut -d \" \" -f 5"
    cmd = "ssh epdp@#{args |> List.first} \"source /home/epdp/.bash_profile && epmd -names\" | grep dean | cut -d \" \" -f 5"
    :os.cmd(cmd |> to_char_list) |> to_string |> String.strip(?\n)
  end
end
