defmodule Bottler.Helpers.GCE do

  @moduledoc """
    Interface helpers with GCE `gcloud` executable
  """

  def instances(config) do
    "gcloud compute instances list"
    |> exec(config)
    |> String.replace("PREEMPTIBLE", "")  # why that extra column?
    |> String.replace(~r/[ ]+/, " ")
    |> String.split("\n")
    |> List.delete_at(-1)
    |> CSV.decode(separator: ?\s, headers: true)
    |> Enum.to_list
  end

  def instance_ips(config) do
    config |> instances |> Enum.map( &(&1["EXTERNAL_IP"]) )
  end

  def instance(name, config) do
    config |> instances |> Enum.find( &(&1["NAME"] == name) )
  end

  defp exec(command, config) do
    "#{command} --project=#{config[:servers][:gce_project]}"
    |> to_char_list
    |> :os.cmd
    |> to_string
  end

end
