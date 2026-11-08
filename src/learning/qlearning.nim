import std/[math, random]
import ../model/board
import ./neuron, ./network

type
  Transition* = object
    state*: seq[float]
    action*: Direction
    reward*: float
    nextState*: seq[float]
    done*: bool

  QAgent* = ref object
    brain*: Network
    epsilon*: float
    epsilonDecay*: float
    epsilonMin*: float
    gamma*: float
    learningRate*: float
    memory*: seq[Transition]
    maxMemory*: int
    episode*: int
    lastQValues*: seq[float]
    highScore*: int
    # Loss tracking
    currentLoss*: float
    lastEpisodeLoss*: float
    lossHistory*: seq[float]
    scoreHistory*: seq[int]
    episodeLossSum: float
    episodeStepCount: int

proc newQAgent*(
    learningRate: float = 0.01,
    gamma: float = 0.9,
    epsilon: float = 1.0,
    maxMemory: int = 10000
): QAgent =
  randomize()
  # Topology: 11 inputs -> 32 hidden (actReLU) -> 3 outputs (actLinear)
  let net = newNetwork([11, 32, 3], hiddenActivation = actReLU, outputActivation = actLinear)
  result = QAgent(
    brain: net,
    epsilon: epsilon,
    epsilonDecay: 0.995,
    epsilonMin: 0.01,
    gamma: gamma,
    learningRate: learningRate,
    memory: @[],
    maxMemory: maxMemory,
    episode: 0,
    lastQValues: @[0.0, 0.0, 0.0],
    highScore: 0,
    currentLoss: 0.0,
    lastEpisodeLoss: 0.0,
    lossHistory: @[],
    scoreHistory: @[],
    episodeLossSum: 0.0,
    episodeStepCount: 0
  )

proc selectAction*(agent: QAgent, state: openArray[float], explore: bool = true): (Direction, seq[float]) =
  ## Predicts Q-values and selects an action using an epsilon-greedy policy.
  let qValues = agent.brain.forward(state)
  agent.lastQValues = qValues

  if explore and rand(1.0) < agent.epsilon:
    # Exploration: random action
    let randomAct = sample([dirStraight, dirRight, dirLeft])
    return (randomAct, qValues)

  # Exploitation: argmax Q
  var bestIdx = 0
  var bestVal = qValues[0]
  for i in 1 ..< qValues.len:
    if qValues[i] > bestVal:
      bestVal = qValues[i]
      bestIdx = i
  return (Direction(bestIdx), qValues)

proc remember*(
    agent: QAgent,
    state: seq[float],
    action: Direction,
    reward: float,
    nextState: seq[float],
    done: bool
) =
  ## Adds an experience transition to replay memory.
  if agent.memory.len >= agent.maxMemory:
    agent.memory.delete(0)
  agent.memory.add(Transition(
    state: state,
    action: action,
    reward: reward,
    nextState: nextState,
    done: done
  ))

proc trainShortMemory*(
    agent: QAgent,
    state: openArray[float],
    action: Direction,
    reward: float,
    nextState: openArray[float],
    done: bool
): float =
  ## Updates network weights for a single step transition using the Bellman target.
  ## Returns the step loss.
  var target = reward
  if not done:
    let nextQ = agent.brain.forward(nextState)
    var maxNextQ = nextQ[0]
    for v in nextQ:
      if v > maxNextQ:
        maxNextQ = v
    target = reward + agent.gamma * maxNextQ

  let stepLoss = agent.brain.trainStep(state, ord(action), target, agent.learningRate)
  agent.currentLoss = stepLoss
  agent.episodeLossSum += stepLoss
  inc agent.episodeStepCount
  return stepLoss

proc trainReplay*(agent: QAgent, batchSize: int = 32) =
  ## Samples a random mini-batch from memory and trains the network.
  if agent.memory.len < batchSize:
    return
  for _ in 0 ..< batchSize:
    let tr = sample(agent.memory)
    discard agent.trainShortMemory(tr.state, tr.action, tr.reward, tr.nextState, tr.done)

proc onGameEnd*(agent: QAgent, score: int) =
  ## Called when a game concludes: records metrics, decays epsilon, and updates history.
  inc agent.episode
  if score > agent.highScore:
    agent.highScore = score

  # Calculate average loss for this episode
  let avgLoss = if agent.episodeStepCount > 0:
    agent.episodeLossSum / float(agent.episodeStepCount)
  else:
    0.0

  agent.lastEpisodeLoss = avgLoss
  agent.lossHistory.add(avgLoss)
  agent.scoreHistory.add(score)

  # Reset episode accumulators
  agent.episodeLossSum = 0.0
  agent.episodeStepCount = 0

  # Decay epsilon exploration
  if agent.epsilon > agent.epsilonMin:
    agent.epsilon = max(agent.epsilonMin, agent.epsilon * agent.epsilonDecay)

  # Simple textbook mini-batch replay
  agent.trainReplay(32)
