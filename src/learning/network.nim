import std/strformat
import ./layer, ./neuron
export layer, neuron

type
  Network* = seq[Layer]

proc newNetwork*(
    topology: openArray[int],
    activation: ActivationKind = actSigmoid,
    randomWeights: bool = true
): Network =
  ## Creates a network where layers connect the given topology sizes.
  ## Example: `newNetwork([4, 8, 3])` returns a Network with 2 layers (4->8, 8->3).
  if topology.len < 2:
    return @[]
  result = newSeq[Layer](topology.len - 1)
  for i in 0 ..< topology.len - 1:
    result[i] = newLayer(topology[i + 1], topology[i], activation, randomWeights)

proc forward*(net: Network, inputs: openArray[float]): seq[float] =
  ## Feeds `inputs` sequentially through each layer in the network.
  var current: seq[float] = @inputs
  for layer in net:
    current = layer.forward(current)
  return current

proc mutate*(net: Network, mutationRate: float = 0.1, mutationAmount: float = 0.2) =
  ## Mutates each layer in the network.
  for layer in net:
    layer.mutate(mutationRate, mutationAmount)

proc clone*(net: Network): Network =
  ## Returns a deep copy of the network.
  result = newSeq[Layer](net.len)
  for i in 0 ..< net.len:
    result[i] = net[i].clone()

proc `$`*(net: Network): string =
  result = &"Network ({net.len} layers):\n"
  for i, layer in net:
    let inCount = if layer.len > 0: layer[0].weights.len else: 0
    let act = if layer.len > 0: $layer[0].activation else: "none"
    result.add &"  Layer {i + 1}: {inCount} inputs -> {layer.len} neurons [{act}]\n"

proc print*(net: Network) =
  echo $net
