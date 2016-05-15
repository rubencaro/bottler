
System.argv()
|> inspect |> IO.puts

defmodule ObserverWrapper do

  def wait_for_observer_to_end do
    IO.puts "."
    try do
      :observer_wx.get_attrib({:font, :fixed})
      :timer.sleep 2_000
      wait_for_observer_to_end
    rescue
      x in [ErlangError] -> x |> inspect |> IO.puts
    end
  end

end
# port = System.argv |> Enum.at(1)
# ip = System.argv |> Enum.at(2)
#
# # auto closing tunnel
# cmd = "ssh -f -L 4369:localhost:4369 -L #{port}:localhost:#{port} epdp@#{ip} sleep 30;" |> to_char_list
# IO.puts cmd
# :os.cmd(cmd)

:ok = :observer.start

# cmd = "erl -name observer@127.0.0.1 -setcookie monikako -run observer -nohalt &" |> to_char_list
# :os.cmd(cmd)

:timer.sleep 5_000

observer_pid = :os.cmd('pgrep -f observerunique')
ObserverWrapper.wait_for_observer_to_end
IO.puts "Now kill observer pid #{observer_pid}"
:os.cmd("kill #{observer_pid}" |> to_char_list)

:ok
