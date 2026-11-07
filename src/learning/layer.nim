import std/strformat
import ./neuron

type
  Layer* = seq[Neuron]

proc newLayer*(neuronCount, inputCount: int, activation: ActivationKind = actSigmoid, randomWeights: bool = true): Layer =
  ## Creates a layer of `neuronCount` neurons, each expecting `inputCount` inputs.
  result = newSeq[Neuron](neuronCount)
  for i in 0 ..< neuronCount:
    result[i] = newNeuron(inputCount, activation, randomWeights)

proc forward*(layer: Layer, inputs: openArray[float]): seq[float] =
  ## Feeds `inputs` through each neuron in the layer and returns their outputs.
  for neuron in layer:
    result.add(neuron.forward(inputs))

proc mutate*(layer: Layer, mutationRate: float = 0.1, mutationAmount: float = 0.2) =
  ## Mutates each neuron in the layer.
  for neuron in layer:
    neuron.mutate(mutationRate, mutationAmount)

proc clone*(layer: Layer): Layer =
  ## Returns a deep copy of the layer.
  for neuron in layer:
    result.add(neuron.clone())

proc `$`*(layer: Layer): string =
  &"Layer({layer.len} neurons)"

proc print*(layer: Layer) =
  echo $layer
