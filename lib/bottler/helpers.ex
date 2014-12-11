defmodule Bottler.Helpers do

  @doc """
    Run given function in different Tasks.
    One `Task` for each entry on given list.
    Each entry on list will be given as args for the function.
    Explodes if `timeout` is reached waiting for any particular task to end.

    Returns a list with the results got from each `Task`.
  """
  def in_tasks(list, fun, timeout \\ 60_000) do
    tasks = for args <- list, into: [], do: Task.async(fn -> fun.(args) end)
    for t <- tasks, into: [], do: Task.await(t, timeout)
  end

end
