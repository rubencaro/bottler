use Mix.Config

config :bottler, :params, [servers: [server1: [ip: "1.1.1.1"],
                                     server2: [ip: "1.1.1.2"]],
                           remote_user: "testuser",
                           cookie: "abc" ]
