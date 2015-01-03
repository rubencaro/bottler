use Mix.Config

config :bottler, :servers, [server1: [user: "myuser", ip: "1.1.1.1"],
                            server2: [user: "myuser", ip: "1.1.1.2"]]

config :bottler, :mixfile, Bottler.Mixfile
