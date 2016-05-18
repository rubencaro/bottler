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

    port = get_port(c, ip)

    # auto closing tunnel
    :os.cmd('killall epmd') # free distributed erlang port
    cmd = "ssh -f -L 4369:localhost:4369 -L #{port}:localhost:#{port} #{c[:remote_user]}@#{ip} sleep 30;" |> to_char_list
    IO.puts "Opening tunnel... \n#{cmd}"
    :os.cmd(cmd) |> to_string |> IO.puts

    # observer
    IO.puts "Starting observer..."
    cmd = "elixir --name observerunique@127.0.0.1 --cookie monikako --no-halt #{__DIR__}/../../../lib/mix/scripts/observer.exs" |> to_char_list
    IO.puts cmd
    :os.cmd(cmd) |> to_string |> IO.puts

    IO.puts "Done"
  end

  defp get_port(c, ip) do
    cmd = "ssh #{c[:remote_user]}@#{ip} \"source /home/#{c[:remote_user]}/.bash_profile && epmd -names\" | grep dean | cut -d \" \" -f 5"
    :os.cmd(cmd |> to_char_list) |> to_string |> String.strip(?\n)
  end
end
