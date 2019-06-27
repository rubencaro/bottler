require Logger, as: L
require Bottler.Helpers, as: H

defmodule Bottler.Stable do
  @moduledoc """
    Code to place a release file on a remote stable server.
  """

  @doc """
    Copy local release file to remote stable
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def stable(config) do
    H.spit "::::::::::::::::::::::::::::::::::::::: entra en stable :::::::::::::::::::::::::::::::::::::::"
    stable_config = config[:stable]
    if stable_config do
      L.info "Publishing stable to #{stable_config[:server]}"

      project = Mix.Project.get!.project

      result = {:ok, %{config: stable_config,
                       src_release: ~s(#{project[:app]}.tar.gz),
                       dst_release: ~s(#{project[:app]}-#{project[:version]}.tar.gz)}}
        |> upload
        |> mark_as_stable

      case result do
        {:ok, _} ->
          :ok

        {:error, reason, _} ->
          Logger.error "Stable failed: #{reason}"
          :error
      end
    else
      :ok
    end
  end

  defp upload({:ok, state}) do
    result = System.cmd "scp", upload_args(state)

    case result do
      {_, 0} -> {:ok, state}
      {error, _} -> {:error, error, state}
    end
  end
  defp upload(x), do: x

  defp upload_args(%{config: config, src_release: src_release, dst_release: dst_release}) do
    scp_opts = ~w(-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR)
    src_release_file = "rel/#{src_release}"
    scp_opts ++ ~w(#{src_release_file} #{config[:remote_user]}@#{config[:server]}:#{config[:folder]}/#{dst_release})
  end

  defp mark_as_stable({:ok, state}) do
    result = System.cmd "ssh", mark_as_stable_args(state)

    case result do
      {_, 0} -> {:ok, state}
      {error, _} -> {:error, error, state}
    end
  end
  defp mark_as_stable(x), do: x

  defp mark_as_stable_args(%{config: config, dst_release: dst_release}) do
    H.spit "mark_as_stable_args #{config}"
    remote_cmd = ~s(ln -sf #{config[:folder]}/#{dst_release} #{config[:folder]}/stable)
    ~w(#{config[:remote_user]}@#{config[:server]} #{remote_cmd})
  end
end
