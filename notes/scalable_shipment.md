# Scalable shipment

The goal is to avoid the bottleneck that development machine's connection supposes when shipping the release over to every single target server.

## Straight inter-server network

Ship one copy of the release to one server, and ship it in parallel to every other server from there. That leaves all the transfer load to the network between servers.

## Distributed shipment

Use inter-server network to ship the release in an intelligent way, keeping transfer rate low enough not to affect other processes and not to suffocate any single machine.

Maybe just ship one copy of the release to one server with the list of other targets. Then recursively do this:

* Split it in two, and for each half:
  * Pop one server
  * Send a copy of the release and the list of remaining servers to the popped server
* Use scalable middleplace to ship releases [*](notes/scalable_shipment.md)

## Use S3

From the development machine upload the release to S3, then download it from every target server.

## Use github

From the development machine, push the release to a github repo, then clone it from every target server.
