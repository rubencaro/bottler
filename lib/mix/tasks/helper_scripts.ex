require Bottler.Helpers, as: H
alias Bottler, as: B

defmodule Mix.Tasks.Bottler.HelperScripts do

  @moduledoc """
  This generates some helper scripts using project's current config
  information, such as target servers. You can run this task repeatedly to
  force regeneration of these scripts to reflect config changes.

  Generated scripts are located under `<project>/.bottler/scripts` (configurable
  via `scripts_folder`). It will also generate links to those scripts on a
  configurable folder to add them to your system PATH. The configuration param
  is `script_links_folder`. Its default value is `~/local/bin`.

  Use like `mix bottler.helper_scripts`.

  The generated scripts' list is short by now:

  * A `<project>_<server>` script for each target server configured. That script
  will open an SSH session with this server. When you want to access one of your
  production servers, the one that is called `daisy42`, for the project called
  `motion`, then you can invoke `motion_daisy42` on any terminal and it will
  open up an SSH shell for you.
  """

  use Mix.Task

  def run(_args) do
    H.set_prod_environment
    c = H.read_and_validate_config
    :ok = B.helper_scripts c
    :ok
  end

end
