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
): float =
  ## Trains the network on a single sample using backpropagation and gradient descent.
  ## Returns the Mean Squared Error (MSE) loss.
  if net.len == 0:
    return 0.0

  # 1. Forward pass while keeping track of inputs to each layer
  var layerInputs = newSeq[seq[float]](net.len)
  var current: seq[float] = @inputs

  for i in 0 ..< net.len:
    layerInputs[i] = current
    current = net[i].forward(current)

  let lastIdx = net.high

  # 2. Compute deltas and MSE loss for the output layer
  var totalLoss = 0.0
  for k in 0 ..< net[lastIdx].len:
    let n = net[lastIdx][k]
    let err = targets[k] - n.output
    totalLoss += err * err
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

  return totalLoss / float(net[lastIdx].len)

proc trainStep*(
    net: Network,
    state: openArray[float],
    actionIdx: int,
    targetValue: float,
    learningRate: float = 0.01
): float =
  ## Updates the network weights specifically for the chosen action's Q-value target.
  ## Returns the squared error (MSE) loss for this step.
  var currentQ = net.forward(state)
  let err = targetValue - currentQ[actionIdx]
  currentQ[actionIdx] = targetValue
  discard net.backprop(state, currentQ, learningRate)
  return err * err

proc `$`*(net: Network): string =
  result = &"Network ({net.len} layers):\n"
  for i, layer in net:
    let inCount = if layer.len > 0: layer[0].weights.len else: 0
    let act = if layer.len > 0: $layer[0].activation else: "none"
    result.add &"  Layer {i + 1}: {inCount} inputs -> {layer.len} neurons [{act}]\n"

proc print*(net: Network) =
  echo $net
