require Logger, as: L
#require Bottler.Helpers, as: H

defmodule Bottler.Publish do
  @moduledoc """
    Code to place a release file on a remote publish server.
  """

  @doc """
    Copy local release file to remote publish
    Returns `{:ok, details}` when done, `{:error, details}` if anything fails.
  """
  def publish(config) do
    publish_config = config[:publish]
    if publish_config do
      L.info "Publishing to #{publish_config[:server]}"

      project = Mix.Project.get!.project

      result = {:ok, %{config: publish_config,
                       src_release: ~s(#{project[:app]}.tar.gz),
                       dst_release: ~s(#{project[:app]}-#{project[:version]}.tar.gz)}}
        |> upload
        |> mark_as_latest

      case result do
        {:ok, _} ->
          :ok

        {:error, reason, _} ->
          Logger.error "Publish failed: #{reason}"
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

  defp mark_as_latest({:ok, state}) do
    result = System.cmd "ssh", mark_as_latest_args(state)

    case result do
      {_, 0} -> {:ok, state}
      {error, _} -> {:error, error, state}
    end
  end
  defp mark_as_latest(x), do: x

  defp mark_as_latest_args(%{config: config, dst_release: dst_release}) do
    remote_cmd = ~s(ln -sf #{config[:folder]}/#{dst_release} #{config[:folder]}/latest)
    ~w(#{config[:remote_user]}@#{config[:server]} #{remote_cmd})
  end
end
