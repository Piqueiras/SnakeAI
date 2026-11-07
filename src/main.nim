import std/strformat
import ./learning/network as netModule, ./model/board

# Gold Standard 11-Feature Vector:
# - [0..2] Danger: Straight, Right, Left
# - [3..6] Current Direction (One-Hot): Up, Down, Left, Right
# - [7..10] Food Direction: Up, Down, Left, Right
# Network outputs: 4 neurons for direction confidence (dirUp, dirDown, dirLeft, dirRight)

var network = newNetwork(topology = [11, 16, 4], activation = actSigmoid, randomWeights = true)

echo "=== NEURAL NETWORK ==="
print(network)

var game = newGame(width = 10, height = 10)
echo "=== INITIAL GAME STATE ==="
print(game)
echo ""

# Extract 11 sensory inputs
let inputs = game.getSensoryInputs()

echo "=== SENSORY INPUTS (11 boolean features) ==="
echo &"  Danger (Straight, Right, Left):        {inputs[0..2]}"
echo &"  Current Direction (Up, Down, Left, Right): {inputs[3..6]}"
echo &"  Food Direction (Up, Down, Left, Right):    {inputs[7..10]}"
echo ""

# Feedforward through the network
let outputs = network.forward(inputs)

echo "=== NETWORK OUTPUTS (4 directions) ==="
const dirNames = ["dirUp", "dirDown", "dirLeft", "dirRight"]
for i in 0 ..< outputs.len:
  echo &"  {dirNames[i]}: {outputs[i]:.4f}"
echo ""

# Pick best valid direction based on network confidence
let validActions = game.actions()
var bestDir = validActions[0]
var bestConf = -1.0

for dir in validActions:
  let conf = outputs[ord(dir)]
  if conf > bestConf:
    bestConf = conf
    bestDir = dir

echo &"Selected move: {bestDir} (confidence: {bestConf:.4f})"
game.advance(bestDir)

echo "\n=== GAME STATE AFTER MOVE ==="
print(game)
