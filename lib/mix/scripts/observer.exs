
System.argv()
|> inspect |> IO.puts

defmodule ObserverWrapper do

  def wait_for_observer_to_end do
    try do
      :observer_wx.get_attrib({:font, :fixed})
      :timer.sleep 2_000
      wait_for_observer_to_end
    rescue
      x in [ErlangError] -> x
    end
  end

end

:net_adm.ping(System.argv |> hd |> String.to_atom)

:ok = :observer.start

:timer.sleep 5_000

observer_pid = :os.cmd('pgrep -f observerunique')
ObserverWrapper.wait_for_observer_to_end
IO.puts "Killing observer with pid #{observer_pid}"
:os.cmd("kill #{observer_pid}" |> to_charlist)

:ok
