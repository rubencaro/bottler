require Bottler.Helpers, as: H

defmodule Bottler.Helpers.GCE do

  @moduledoc """
    Interface helpers with GCE `gcloud` executable
  """

  def instances(config) do
    "gcloud compute instances list --format=json"
    |> exec(config)
    |> Poison.decode!
    |> match(config[:servers][:match])
  end

  def instance_ips(config) do
    config
    |> instances
    |> Enum.map(&H.get_nested(&1, ["networkInterfaces", 0, "accessConfigs", 0, "natIP"]))
  end

  def instance(config, name) do
    config |> instances |> Enum.find(&(&1["name"] == name))
  end

  def match(list, nil), do: list
  def match(list, regexstr) do
    r = Regex.compile!(regexstr)
    list |> Enum.filter(&Regex.match?(r, &1["name"]))
  end

  defp exec(command, config) do
    "#{command} --project=#{config[:servers][:gce_project]}"
    |> to_charlist
    |> :os.cmd
    |> to_string
  end

end
