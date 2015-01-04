require Bottler.Helpers, as: H

defmodule ReleaseTest do
  use ExUnit.Case, async: false

  test "release gets generated" do
    # generate release
    :ok = Bottler.Release.release

    # check everything looks ok
    {:ok,_} = H.read_terms "rel/bottler.rel"
    {:ok,_} = H.read_terms "rel/bottler.script"
    {:ok,_} = H.read_terms "rel/sys.config"
  end
end
