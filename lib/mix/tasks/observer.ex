require Bottler.Helpers, as: H
require Logger, as: L

defmodule Mix.Tasks.Observer do
  use Mix.Task

  def run(args) do
    name = args |> List.first |> String.to_atom

    H.set_prod_environment
    c = H.read_and_validate_config |> H.inline_resolve_servers

    if not name in Keyword.keys(c[:servers]),
      do: raise "Server not found by that name"

    ip = c[:servers][name][:ip]
    L.info "Target IP: #{ip}"
    L.info "Server name: #{name}"

    port = get_port(c, name, ip)

    # auto closing tunnel
    :os.cmd('killall epmd') # free distributed erlang port
    cmd = "ssh -L 4369:localhost:4369 -L #{port}:localhost:#{port} #{c[:remote_user]}@#{ip}" |> to_charlist
    IO.puts "Opening tunnel... \n#{cmd}"
    spawn fn -> :os.cmd(cmd) |> to_string |> IO.puts end
    :timer.sleep 1000
    node_name = erlang_node_name(name)

    # observer
    IO.puts "Starting observer..."
    cmd = "elixir --name observerunique@127.0.0.1 --cookie monikako --no-halt #{__DIR__}/../../../lib/mix/scripts/observer.exs #{node_name}" |> to_charlist
    IO.puts cmd
    :os.cmd(cmd) |> to_string |> IO.puts

    IO.puts "Done"
  end

  defp get_port(c, server_name, ip) do
    cmd = "ssh #{c[:remote_user]}@#{ip} \"source /home/#{c[:remote_user]}/.bash_profile && epmd -names\" | grep #{server_name} | cut -d \" \" -f 5"
    :os.cmd(cmd |> to_charlist) |> to_string |> String.strip(?\n)
  end

  defp erlang_node_name(server_name) do
    app = server_name |> to_string |> String.split("-") |> hd
    "#{app}_at_#{server_name}@127.0.0.1" |> String.to_atom
  end
end
