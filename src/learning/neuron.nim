import std/[math, random, strformat]

type
  ActivationKind* = enum
    actSigmoid, actReLU, actTanh, actLinear

  Neuron* = ref object
    weights*: seq[float]
    bias*: float
    activation*: ActivationKind
    output*: float
    delta*: float

# --- Activation functions & derivatives ---

func sigmoid*(x: float): float = 1.0 / (1.0 + exp(-x))
func dSigmoid*(output: float): float = output * (1.0 - output)

func relu*(x: float): float = max(0.0, x)
func dRelu*(output: float): float = (if output > 0.0: 1.0 else: 0.0)

func tanhAct*(x: float): float = tanh(x)
func dTanh*(output: float): float = 1.0 - (output * output)

func linear*(x: float): float = x
func dLinear*(output: float): float = 1.0

func applyActivation*(kind: ActivationKind, x: float): float =
  case kind
  of actSigmoid: sigmoid(x)
  of actReLU: relu(x)
  of actTanh: tanhAct(x)
  of actLinear: linear(x)

func applyDerivative*(kind: ActivationKind, x: float): float =
  case kind
  of actSigmoid: dSigmoid(x)
  of actReLU: dRelu(x)
  of actTanh: dTanh(x)
  of actLinear: dLinear(x)

# --- Constructors ---

proc newNeuron*(inputCount: int, activation: ActivationKind = actSigmoid, randomWeights: bool = true): Neuron =
  ## Initializes a new neuron with `inputCount` inputs.
  ## If `randomWeights` is true, weights and bias are initialized with random values in [-1.0, 1.0].
  result = Neuron(
    weights: newSeq[float](inputCount),
    bias: if randomWeights: rand(-1.0 .. 1.0) else: 0.0,
    activation: activation,
    output: 0.0,
    delta: 0.0
  )
  for i in 0 ..< inputCount:
    result.weights[i] = if randomWeights: rand(-1.0 .. 1.0) else: 0.0

proc newNeuron*(weights: seq[float], bias: float, activation: ActivationKind = actSigmoid): Neuron =
  ## Initializes a neuron with specific weights and bias.
  Neuron(
    weights: weights,
    bias: bias,
    activation: activation,
    output: 0.0,
    delta: 0.0
  )

proc initNeuron*(inputCount: int, activation: ActivationKind = actSigmoid, randomWeights: bool = true): Neuron =
  newNeuron(inputCount, activation, randomWeights)

# --- Forward Pass ---

proc forward*(neuron: Neuron, inputs: openArray[float]): float =
  ## Computes the weighted sum of inputs plus bias and applies the activation function.
  if inputs.len != neuron.weights.len:
    raise newException(ValueError, "Input length does not match neuron weights length.")

  var sum = neuron.bias
  for i in 0 ..< inputs.len:
    sum += inputs[i] * neuron.weights[i]

  neuron.output = applyActivation(neuron.activation, sum)
  return neuron.output

# --- Neuroevolution / Genetic helpers ---

proc mutate*(neuron: Neuron, mutationRate: float = 0.1, mutationAmount: float = 0.2) =
  ## Randomly mutates weights and bias based on `mutationRate` and `mutationAmount`.
  for i in 0 ..< neuron.weights.len:
    if rand(1.0) < mutationRate:
      neuron.weights[i] += rand(-mutationAmount .. mutationAmount)
  if rand(1.0) < mutationRate:
    neuron.bias += rand(-mutationAmount .. mutationAmount)

proc clone*(neuron: Neuron): Neuron =
  ## Returns a deep copy of the neuron.
  Neuron(
    weights: neuron.weights,
    bias: neuron.bias,
    activation: neuron.activation,
    output: neuron.output,
    delta: neuron.delta
  )

proc `$`*(neuron: Neuron): string =
  &"Neuron(weights: {neuron.weights}, bias: {neuron.bias:.4f}, activation: {neuron.activation}, output: {neuron.output:.4f})"
