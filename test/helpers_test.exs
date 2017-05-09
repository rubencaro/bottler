alias Bottler.Helpers, as: H

defmodule Bottler.HelpersTest do
  use ExUnit.Case, async: true

  describe "in_tasks" do
    test "sign works" do
      assert {:error, [{1, {:ok, 1}}, {2, {:ok, 2}}, {3, {:ok, 3}}]} = H.in_tasks([1, 2, 3], &(&1))
      assert {:ok, [{1, {:ok, :ok}}, {2, {:ok, :ok}}, {3, {:ok, :ok}}]} = H.in_tasks([1, 2, 3], fn(_) -> :ok end)
      res = H.in_tasks([1, 2], fn(_) -> :surprise end, expected: :surprise)
      assert {:ok, [{1, {:ok, :surprise}}, {2, {:ok, :surprise}}]} = res
    end

    test "timeout gets caught" do
      res = H.in_tasks([100, 200], fn(s) -> Process.sleep(s); :ok end, timeout: 150)
      assert {:error, [{100, {:ok, :ok}}, {200, {:error, "Timeout"}}]} = res
    end

    test "raise gets caught" do
      res = H.in_tasks([1, 0], &(if &1 > 0, do: raise "Explode!"))
      assert {:error, [{1, {:error, %RuntimeError{message: "Explode!"}}},
                       {0, {:ok, nil}}]} = res
    end
  end
end
