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

    case ship_config[:method] do
      :scp -> scp_shipment(config, ship_config)
      :remote_scp -> remote_scp_shipment(config, ship_config)
    end
  end

  defp scp_shipment(config, ship_config) do
    L.info "Shipping to #{config[:servers] |> K.keys |> Enum.join(",")} using straight SCP..."

    task_opts = [expected: [], to_s: true, timeout: ship_config[:timeout]]

    common = [remote_user: config[:remote_user],
              app: Mix.Project.get!.project[:app]]

    config[:servers] |> K.values
    |> H.in_tasks( &(&1 |> K.merge(common) |> run_scp), task_opts)
  end

  defp remote_scp_shipment(config, ship_config) do
    L.info "Shipping to #{config[:servers] |> K.keys |> Enum.join(",")} using remote SCP..."

    task_opts = [expected: [], to_s: true, timeout: ship_config[:timeout]]

    common = [remote_user: config[:remote_user],
              app: Mix.Project.get!.project[:app]]

    [first | rest] = config[:servers] |> K.values

    # straight scp to first remote
    L.info "Uploading release to #{first[:ip]}..."
    [first] |> H.in_tasks( &(&1 |> K.merge(common) |> run_scp),  task_opts)

    # scp from there to the rest
    L.info "Distributing release from #{first[:ip]} to #{Enum.map_join(rest, ",", &(&1[:ip]))}..."
    common_rest = common |> K.merge(src_ip: first[:ip],
                                    srcpath: "/tmp/#{common[:app]}.tar.gz",
                                    method: :remote_scp)
    rest |> H.in_tasks( &(&1 |> K.merge(common_rest) |> run_scp), task_opts)
  end

  defp get_scp_template(method) do
    case method do
      :scp -> "scp -oStrictHostKeyChecking=no <%= srcpath %> <%= remote_user %>@<%= ip %>:<%= dstpath %>"
      :remote_scp -> "ssh -A -oStrictHostKeyChecking=no <%= remote_user %>@<%= src_ip %> scp -oStrictHostKeyChecking=no <%= srcpath %> <%= remote_user %>@<%= ip %>:<%= dstpath %>"
    end
  end

  defp run_scp(args) do
    args = args |> H.defaults(srcpath: "rel/#{args[:app]}.tar.gz",
                              dstpath: "/tmp/",
                              method: :scp)

    args[:method]
    |> get_scp_template
    |> EEx.eval_string(args)
    |> to_char_list
    |> :os.cmd
  end

end
