import std/strformat
import ./learning/network as netModule, ./model/board

# Gold Standard 11-Feature Vector (Egocentric):
# - [0..2] Danger: Straight, Right, Left
# - [3..6] Current Orientation: Up, Down, Left, Right
# - [7..10] Relative Food Location: Straight (Ahead), Right, Left, Behind
#
# Network outputs: 3 neurons for relative direction (dirStraight, dirRight, dirLeft)

var network = newNetwork(topology = [11, 16, 3], activation = actSigmoid, randomWeights = true)

echo "=== NEURAL NETWORK ==="
print(network)

var game = newGame(width = 10, height = 10)
echo "=== INITIAL GAME STATE ==="
print(game)
echo ""

# Extract 11 sensory inputs
let inputs = game.getSensoryInputs()

echo "=== SENSORY INPUTS (11 egocentric boolean features) ==="
echo &"  Danger (Straight, Right, Left):                 {inputs[0..2]}"
echo &"  Orientation (Up, Down, Left, Right):            {inputs[3..6]}"
echo &"  Relative Food (Straight, Right, Left, Behind):  {inputs[7..10]}"
echo ""

# Feedforward through the network
let outputs = network.forward(inputs)

echo "=== NETWORK OUTPUTS (3 relative directions) ==="
const dirNames = ["dirStraight", "dirRight", "dirLeft"]
for i in 0 ..< outputs.len:
  echo &"  {dirNames[i]}: {outputs[i]:.4f}"
echo ""

# Pick best direction based on highest confidence
let validActions = game.actions() # @[dirStraight, dirRight, dirLeft]
var bestDir = dirStraight
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
