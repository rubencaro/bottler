use Mix.Config

config :bottler, :params, [servers: [server1: [ip: "1.1.1.1"],
                                     server2: [ip: "1.1.1.2"]],
                           hooks: [pre_release: %{command: "pwd", continue_on_fail: true}],
                           remote_user: "testuser",
                           cookie: "abc",
                           additional_folders: ["extras"]]
