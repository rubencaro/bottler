require Bottler.Helpers, as: H

defmodule HelperScriptsTest do
  use ExUnit.Case, async: false

  test "helper scripts get generated" do
    # test config
    sf = "/tmp/test_scripts_folder"
    ipf = "/tmp/test_into_path_folder"
    H.empty_dirs [sf,ipf]

    # proof that the folder does not get deleted
    [] = :os.cmd 'touch #{ipf}/witness'

    config = [
      scripts_folder: sf,
      into_path_folder: ipf,
      remote_port: 22,
      remote_user: "testuser",
      servers: [ server1: [ip: "1.1.1.1"],
                 server2: [ip: "1.1.1.2"] ]
    ]

    # runs ok
    :ok = Bottler.HelperScripts.helper_scripts config

    # everything looks fine
    names = config[:servers] |> Keyword.keys |> Enum.map &("bottler_#{&1}")
    assert names == sf |> File.ls! |> Enum.sort
    assert names ++ ["witness"] == ipf |> File.ls! |> Enum.sort
    for {s,opts} <- config[:servers],
      do: check_server_file( sf, s, opts[:ip], config[:remote_user],
                             config[:remote_port] )

    # change config
    config = Keyword.merge config, [
      remote_port: 23,
      remote_user: "testuser2",
      servers: [ serverA: [ip: "2.1.1.1"],
                 serverB: [ip: "2.1.1.2"] ]
    ]

    # rerun
    :ok = Bottler.HelperScripts.helper_scripts config

    # everything was cleaned and recreated with new values
    names = config[:servers] |> Keyword.keys |> Enum.map &("bottler_#{&1}")
    assert names == sf |> File.ls! |> Enum.sort
    assert names ++ ["witness"] == ipf |> File.ls! |> Enum.sort
    for {s,opts} <- config[:servers],
      do: check_server_file( sf, s, opts[:ip], config[:remote_user],
                             config[:remote_port] )
  end

  defp check_server_file(path, name, ip, user, port) do
    body = "#{path}/bottler_#{name}" |> File.read!
    assert Regex.match?(~r/#{Regex.escape(ip)}/, body)
    assert Regex.match?(~r/#{user}/, body)
    assert Regex.match?(~r/#{port}/, body)
  end

end
