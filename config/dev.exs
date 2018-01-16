use Mix.Config

config :bottler, :params, [servers: [server1: [ip: "1.1.1.1"],
                                     server2: [ip: "1.1.1.2"]],
                           hooks: [pre_release: %{command: "pwd", continue_on_fail: false}],
                           remote_user: "devuser",
                           # rsa_pass_phrase: "bogus",
                           cookie: "abc" ]
