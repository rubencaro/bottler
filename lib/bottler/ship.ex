require Logger, as: L
require Bottler.Helpers, as: H
alias Keyword, as: K

defmodule Bottler.Ship do

  @moduledoc """
    Code to place a release file on remote servers. No more, no less.
  """

  @doc """
    Copy local release file to remote servers
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def ship(config) do
    ship_config = config[:ship] |> H.defaults(timeout: 60_000, method: :scp)
    publish_config = config[:publish] |> H.defaults(timeout: 60_000, method: :scp)
    servers = config[:servers] |> H.prepare_servers

    case ship_config[:method] do
      :scp -> scp_shipment(config, servers, ship_config)
      :remote_scp -> remote_scp_shipment(config, servers, ship_config)
      :release_script -> release_script_shipment(config, servers, ship_config, publish_config)
    end
  end

  defp scp_shipment(config, servers, ship_config) do
    L.info "Shipping to #{servers |> Enum.map(&(&1[:id])) |> Enum.join(",")} using straight SCP..."

    task_opts = [expected: [], to_s: true, timeout: ship_config[:timeout]]

    common = [remote_user: config[:remote_user],
              app: Mix.Project.get!.project[:app]]


    servers |> H.in_tasks( &(&1 |> K.merge(common) |> run_scp), task_opts)
  end

  defp remote_scp_shipment(config, servers, ship_config) do
    L.info "Shipping to #{servers |> Enum.map(&(&1[:id])) |> Enum.join(",")} using remote SCP..."

    task_opts = [expected: [], to_s: true, timeout: ship_config[:timeout]]

    common = [remote_user: config[:remote_user],
              app: Mix.Project.get!.project[:app]]

    [first | rest] = servers

    # straight scp to first remote
    L.info "Uploading release to #{first[:id]}..."
    [first] |> H.in_tasks( &(&1 |> K.merge(common) |> run_scp),  task_opts)

    # scp from there to the rest
    L.info "Distributing release from #{first[:id]} to #{Enum.map_join(rest, ",", &(&1[:id]))}..."
    common_rest = common |> K.merge(src_ip: first[:ip],
                                    srcpath: "/tmp/#{common[:app]}.tar.gz",
                                    method: :remote_scp)
    rest |> H.in_tasks( &(&1 |> K.merge(common_rest) |> run_scp), task_opts)
  end

  defp release_script_shipment(config, servers, ship_config, publish_config) do
    L.info "Shipping to #{servers |> Enum.map(&(&1[:id])) |> Enum.join(",")} using release_script.."

    task_opts = [timeout: ship_config[:timeout]]

    common = [remote_user: config[:remote_user],
              app: Mix.Project.get!.project[:app],
              publish_user: publish_config[:remote_user],
              publish_host: publish_config[:server],
              publish_folder: publish_config[:folder],
              release_ship_script: ship_config[:release_ship_script]]

    servers |> H.in_tasks( &(&1 |> K.merge(common) |> invoke_download_latest_release), task_opts)
  end

  defp get_release_script_args(args) do
    ssh_opts = ["-oStrictHostKeyChecking=no", "-oUserKnownHostsFile=/dev/null", "-oLogLevel=ERROR"]
    ["-A"] ++ ssh_opts ++ ["#{args[:remote_user]}@#{args[:ip]}", args[:release_download_script]]
  end

  defp invoke_download_latest_release(args) do
    release_script_args = get_release_script_args(args)

    L.info "Invoking release_script on #{args[:ip]}..."

    result = System.cmd "ssh", release_script_args

    case result do
      {_, 0} -> :ok
      {_error, _} -> :error
    end
  end

  defp get_scp_template(method) do
    scp_opts = "-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR"
    case method do
      :scp -> "scp #{scp_opts} <%= srcpath %> <%= remote_user %>@<%= ip %>:<%= dstpath %>"
      :remote_scp -> "ssh -A #{scp_opts} <%= remote_user %>@<%= src_ip %> scp #{scp_opts} <%= srcpath %> <%= remote_user %>@<%= ip %>:<%= dstpath %>"
    end
  end

  defp run_scp(args) do
    args = args |> H.defaults(srcpath: "rel/#{args[:app]}.tar.gz",
                              dstpath: "/tmp/",
                              method: :scp)

    args[:method]
    |> get_scp_template
    |> EEx.eval_string(args)
    |> to_charlist
    |> :os.cmd
  end

end
