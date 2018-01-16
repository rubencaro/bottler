require Bottler.Helpers, as: H
require Bottler.Helpers.Hook, as: Hook

defmodule HelpersHookTest do
  use ExUnit.Case, async: false

  setup do
    config = H.read_and_validate_config
    |> H.validate_branch
    |> H.inline_resolve_servers([])

    {:ok, config}
  end

  @tag :no_config_entry
  test "returns :ok if no hook configured", config do
    assert :ok == Hook.exec(:release, config)
  end

  @tag :hook_continue_on_fail_true
  test "allways returns :ok if continue_on_fail is true", config do
    assert :ok == Hook.exec(:pre_release, config)
    config = %{config| hooks: [pre_release: %{continue_on_fail: true, command: "unexistent_command"}]}
    assert :ok == Hook.exec(:pre_release, config)
  end

  @tag :hook_happy_path
  test "happy path #2 - returns :ok if continue_on_fail is false and command executed successfully", config do
    config = %{config| hooks: [pre_release: %{continue_on_fail: false, command: "pwd"}]}
    assert :ok == Hook.exec(:pre_release, config)
  end

  @tag :hook_unhappy_path
  test "unhappy path - returns {:error, message if continue_on_fail is false and command fails", config do
    config = %{config| hooks: [pre_release: %{continue_on_fail: false, command: "my_inexistent_command"}]}
    assert {:error, "Release step failed. Please fix any errors and try again."} == Hook.exec(:pre_release, config)
  end

end
