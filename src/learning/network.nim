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

proc newNetwork*(
    topology: openArray[int],
    hiddenActivation: ActivationKind,
    outputActivation: ActivationKind,
    randomWeights: bool = true
): Network =
  ## Creates a network with custom activations for hidden layers and output layer.
  if topology.len < 2:
    return @[]
  let layerCount = topology.len - 1
  result = newSeq[Layer](layerCount)
  for i in 0 ..< layerCount:
    let act = if i == layerCount - 1: outputActivation else: hiddenActivation
    result[i] = newLayer(topology[i + 1], topology[i], act, randomWeights)

proc forward*(net: Network, inputs: openArray[float]): seq[float] =
  ## Feeds `inputs` sequentially through each layer in the network.
  var current: seq[float] = @inputs
  for layer in net:
    current = layer.forward(current)
  return current

proc backprop*(
    net: Network,
    inputs: openArray[float],
    targets: openArray[float],
    learningRate: float = 0.01
) =
  ## Trains the network on a single sample using backpropagation and gradient descent.
  if net.len == 0:
    return

  # 1. Forward pass while keeping track of inputs to each layer
  var layerInputs = newSeq[seq[float]](net.len)
  var current: seq[float] = @inputs

  for i in 0 ..< net.len:
    layerInputs[i] = current
    current = net[i].forward(current)

  let lastIdx = net.high

  # 2. Compute deltas for the output layer
  for k in 0 ..< net[lastIdx].len:
    let n = net[lastIdx][k]
    let err = targets[k] - n.output
    n.delta = err * applyDerivative(n.activation, n.output)

  # 3. Backpropagate deltas through hidden layers (from lastIdx - 1 down to 0)
  for l in countdown(lastIdx - 1, 0):
    for j in 0 ..< net[l].len:
      var sum = 0.0
      for k in 0 ..< net[l + 1].len:
        let nextNeuron = net[l + 1][k]
        sum += nextNeuron.delta * nextNeuron.weights[j]
      let n = net[l][j]
      n.delta = sum * applyDerivative(n.activation, n.output)

  # 4. Update weights and biases for all layers
  for l in 0 .. net.high:
    let inVals = layerInputs[l]
    for n in net[l]:
      for i in 0 ..< inVals.len:
        n.weights[i] += learningRate * n.delta * inVals[i]
      n.bias += learningRate * n.delta

proc trainStep*(
    net: Network,
    state: openArray[float],
    actionIdx: int,
    targetValue: float,
    learningRate: float = 0.01
) =
  ## Updates the network weights specifically for the chosen action's Q-value target.
  var currentQ = net.forward(state)
  currentQ[actionIdx] = targetValue
  net.backprop(state, currentQ, learningRate)

proc `$`*(net: Network): string =
  result = &"Network ({net.len} layers):\n"
  for i, layer in net:
    let inCount = if layer.len > 0: layer[0].weights.len else: 0
    let act = if layer.len > 0: $layer[0].activation else: "none"
    result.add &"  Layer {i + 1}: {inCount} inputs -> {layer.len} neurons [{act}]\n"

proc print*(net: Network) =
  echo $net
