## Local libp2p swarm for exercising Logos libp2p UI.
##
## Every generated peer connects directly to the UI node, subscribes to a shared
## GossipSub topic, periodically publishes a message, and pings the UI node.
## This gives the UI inbound peers, stream activity, and GossipSub traffic.

import std/[os, parseopt, strformat, strutils]

import chronos
import results
import stew/byteutils

import libp2p
import libp2p/protocols/ping

type
  Config = object
    peerId: string
    address: string
    nodeCount: int
    topic: string
    publishInterval: Duration
    pingInterval: Duration
    duration: Duration

  SwarmNode = object
    number: int
    switch: Switch
    gossip: GossipSub
    ping: Ping

const
  DefaultNodeCount = 10
  DefaultTopic = "logos-ui-test"
  DefaultPublishInterval = 2.seconds
  DefaultPingInterval = 10.seconds
  DefaultDuration = 0.seconds

proc usage() =
  echo """
Usage:
  ui_swarm --peer-id <UI_PEER_ID> --address <UI_MULTIADDR> [options]

Required:
  --peer-id ID              Peer ID shown in the running UI Overview screen.
  --address MULTIADDR       Listen address shown in the running UI Overview screen.

Options:
  --nodes N                 Number of peers to create (default: 10).
  --topic TOPIC             GossipSub topic (default: logos-ui-test).
  --publish-interval SEC    Seconds between publishes per peer (default: 2).
  --ping-interval SEC       Seconds between pings per peer (default: 10).
  --duration SEC            Stop after this many seconds; 0 runs until Ctrl-C.
  --help                    Show this help.
"""

proc parsePositiveInt(value, option: string; allowZero = false): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, &"{option} must be an integer.")
  if result < 0 or (not allowZero and result == 0):
    let requirement = if allowZero: "zero or greater" else: "greater than zero"
    raise newException(ValueError, &"{option} must be {requirement}.")

proc parseArgs(): Config =
  result = Config(
    nodeCount: DefaultNodeCount,
    topic: DefaultTopic,
    publishInterval: DefaultPublishInterval,
    pingInterval: DefaultPingInterval,
    duration: DefaultDuration,
  )

  var parser = initOptParser(commandLineParams())
  for kind, key, value in parser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "peer-id": result.peerId = value
      of "address": result.address = value
      of "nodes": result.nodeCount = parsePositiveInt(value, "--nodes")
      of "topic": result.topic = value
      of "publish-interval":
        result.publishInterval = parsePositiveInt(value, "--publish-interval").seconds
      of "ping-interval":
        result.pingInterval = parsePositiveInt(value, "--ping-interval").seconds
      of "duration":
        result.duration = parsePositiveInt(value, "--duration", allowZero = true).seconds
      of "help", "h":
        usage()
        quit(0)
      else:
        raise newException(ValueError, &"Unknown option: --{key}")
    of cmdArgument:
      raise newException(ValueError, &"Unexpected argument: {key}")
    of cmdEnd:
      discard

  if result.peerId.len == 0 or result.address.len == 0:
    raise newException(ValueError, "--peer-id and --address are required.")
  if result.topic.len == 0:
    raise newException(ValueError, "--topic cannot be empty.")

proc createNode(number: int; rng: Rng): SwarmNode {.raises: [LPError].} =
  let switch = SwitchBuilder
    .new()
    .withRng(rng)
    .withAddress(MultiAddress.init("/ip4/127.0.0.1/tcp/0").tryGet())
    .withTcpTransport()
    # Logos libp2p's TCP default is Mplex; use it explicitly so the swarm
    # negotiates the same muxer as a default UI node.
    .withMplex()
    .withNoise()
    .build()
  let gossip = GossipSub.init(switch = switch, triggerSelf = false, rng = rng)
  let ping = Ping.new(rng = rng)
  switch.mount(gossip)
  switch.mount(ping)
  SwarmNode(number: number, switch: switch, gossip: gossip, ping: ping)

proc connect(node: SwarmNode; target: PeerId; address: MultiAddress) {.async.} =
  try:
    await node.switch.connect(target, @[address])
    echo &"peer {node.number:>3} connected: {node.switch.peerInfo.peerId}"
  except CatchableError as error:
    echo &"peer {node.number:>3} could not connect: {error.msg}"

proc publishLoop(node: SwarmNode; topic: string; interval: Duration) {.async.} =
  var sequence = 0
  while true:
    await sleepAsync(interval)
    sequence.inc()
    let message = &"ui-swarm peer={node.number} sequence={sequence}"
    try:
      discard await node.gossip.publish(topic, message.toBytes())
    except CatchableError as error:
      echo &"peer {node.number:>3} publish failed: {error.msg}"

proc pingLoop(node: SwarmNode; target: PeerId; interval: Duration) {.async.} =
  while true:
    await sleepAsync(interval)
    try:
      let stream = await node.switch.dial(target, PingCodec)
      discard await node.ping.ping(stream)
      await stream.close()
    except CatchableError as error:
      echo &"peer {node.number:>3} ping failed: {error.msg}"

proc main(config: Config) {.async.} =
  let target = PeerId.init(config.peerId).tryGet()
  let address = MultiAddress.init(config.address).tryGet()
  let rng = newRng()
  var nodes: seq[SwarmNode]

  for number in 1 .. config.nodeCount:
    let node = createNode(number, rng)
    node.gossip.subscribe(config.topic, nil)
    await node.switch.start()
    nodes.add(node)

  echo &"Started {nodes.len} swarm peers. Connecting to {config.peerId} at {config.address}."
  for node in nodes:
    await node.connect(target, address)

  echo &"Swarm is active on GossipSub topic '{config.topic}'."
  echo "In the UI, subscribe to that topic and use Refresh on Peers/Metrics to observe changes."

  var tasks: seq[Future[void]]
  for node in nodes:
    tasks.add(node.publishLoop(config.topic, config.publishInterval))
    tasks.add(node.pingLoop(target, config.pingInterval))

  if config.duration > 0.seconds:
    await sleepAsync(config.duration)
  else:
    while true:
      await sleepAsync(1.hours)

  for task in tasks:
    task.cancel()
  for node in nodes:
    await node.switch.stop()

when isMainModule:
  try:
    waitFor(main(parseArgs()))
  except CatchableError as error:
    stderr.writeLine("ui_swarm: " & error.msg)
    usage()
    quit(1)
