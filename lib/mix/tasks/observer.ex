require Bottler.Helpers, as: H
require Logger, as: L

defmodule Mix.Tasks.Observer do
  @moduledoc """
  Task module for the Observer command
  """
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

    open_tunnel(c, name, ip)

    start_observer(c, name)

    IO.puts "Done"
  end

  defp start_observer(c, name) do
    node_name = erlang_node_name(name)

    IO.puts "Starting observer..."
    cmd = "elixir --name observerunique@127.0.0.1 --cookie #{c[:cookie]} --no-halt #{__DIR__}/../../../lib/mix/scripts/observer.exs #{node_name}" |> to_charlist
    IO.puts cmd
    cmd |> :os.cmd |> to_string |> IO.puts
  end

  defp open_tunnel(c, name, ip) do
    port = get_port(c, name, ip)
    :os.cmd('killall epmd') # free distributed erlang port

    # auto closing tunnel
    tunnel_cmd = "ssh -L 4369:localhost:4369 -L #{port}:localhost:#{port} #{c[:remote_user]}@#{ip}" |> to_charlist

    IO.puts "Opening tunnel... \n#{tunnel_cmd}"
    spawn fn -> tunnel_cmd |> :os.cmd |> to_string |> IO.puts end

    :timer.sleep 1000
  end

  defp get_port(c, server_name, ip) do
    "ssh #{c[:remote_user]}@#{ip} \"source /home/#{c[:remote_user]}/.bash_profile && epmd -names\" | grep #{server_name} | cut -d \" \" -f 5"
    |> to_charlist
    |> :os.cmd |> to_string |> String.strip(?\n)
  end

  defp erlang_node_name(server_name) do
    app = server_name |> to_string |> String.split("-") |> hd
    "#{app}_at_#{server_name}@127.0.0.1" |> String.to_atom
  end
end
