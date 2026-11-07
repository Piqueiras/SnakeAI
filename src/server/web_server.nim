import std/[asynchttpserver, asyncdispatch, json, strutils, os]
import ../model/board
import ../learning/[neuron, network, qlearning]

type
  ServerState = ref object
    game: Game
    agent: QAgent
    mode: string
    highScore: int
    lastAction: Direction
    lastQValues: seq[float]
    pendingManualDir: Direction
    hasPendingManualDir: bool
    stepsWithoutFood: int
    staticDir: string

proc keyToRelativeDirection(key: string, ori: Orientation): (bool, Direction) =
  case key
  of "a", "A":
    return (true, dirLeft)
  of "d", "D":
    return (true, dirRight)
  of "w", "W":
    return (true, dirStraight)
  of "ArrowUp":
    case ori
    of oriUp: return (true, dirStraight)
    of oriRight: return (true, dirLeft)
    of oriLeft: return (true, dirRight)
    of oriDown: return (false, dirStraight) # Ignore opposite
  of "ArrowDown":
    case ori
    of oriDown: return (true, dirStraight)
    of oriRight: return (true, dirRight)
    of oriLeft: return (true, dirLeft)
    of oriUp: return (false, dirStraight)
  of "ArrowLeft":
    case ori
    of oriLeft: return (true, dirStraight)
    of oriUp: return (true, dirLeft)
    of oriDown: return (true, dirRight)
    of oriRight: return (false, dirStraight)
  of "ArrowRight":
    case ori
    of oriRight: return (true, dirStraight)
    of oriUp: return (true, dirRight)
    of oriDown: return (true, dirLeft)
    of oriLeft: return (false, dirStraight)
  else:
    return (false, dirStraight)

proc serializeState(s: ServerState): JsonNode =
  var snakeNodes: seq[JsonNode] = @[]
  for tile in s.game.snake:
    snakeNodes.add(%*{"x": tile.x, "y": tile.y})

  result = %*{
    "width": s.game.width,
    "height": s.game.height,
    "score": s.game.score(),
    "highScore": s.highScore,
    "orientation": $s.game.orientation,
    "finished": s.game.finished,
    "mode": s.mode,
    "episode": s.agent.episode,
    "epsilon": s.agent.epsilon,
    "snake": snakeNodes,
    "food": {"x": s.game.food.x, "y": s.game.food.y},
    "qValues": s.lastQValues,
    "lastAction": $s.lastAction
  }

proc stepSimulation(s: ServerState) =
  if s.mode == "agent":
    if s.game.isFinished():
      s.agent.onGameEnd(s.game.score())
      s.game = newGame(20, 20)
      s.stepsWithoutFood = 0

    let state = s.game.getSensoryInputs()
    let (action, qVals) = s.agent.selectAction(state, explore = true)
    s.lastAction = action
    s.lastQValues = qVals

    let prevScore = s.game.score()
    inc s.stepsWithoutFood

    # Execute step
    s.game.advance(action)

    var reward = 0.0
    var done = false

    if s.game.isFinished():
      reward = -10.0 # Collision penalty
      done = true
    elif s.stepsWithoutFood >= 150: # Starvation / loop timeout
      reward = -10.0
      s.game.finished = true
      done = true
    elif s.game.score() > prevScore:
      reward = 10.0 # Food eaten reward!
      s.stepsWithoutFood = 0
      if s.game.score() > s.highScore:
        s.highScore = s.game.score()
    else:
      reward = -0.05 # Small step penalty

    let nextState = s.game.getSensoryInputs()
    s.agent.remember(state, action, reward, nextState, done)
    s.agent.trainShortMemory(state, action, reward, nextState, done)

    if done:
      s.agent.onGameEnd(s.game.score())

  elif s.mode == "manual":
    if s.game.isFinished():
      return

    var act = dirStraight
    if s.hasPendingManualDir:
      act = s.pendingManualDir
      s.hasPendingManualDir = false

    s.lastAction = act
    # Also evaluate network Q-values in manual mode so user can see what the agent would predict!
    let state = s.game.getSensoryInputs()
    let (_, qVals) = s.agent.selectAction(state, explore = false)
    s.lastQValues = qVals

    s.game.advance(act)
    if s.game.score() > s.highScore:
      s.highScore = s.game.score()

proc startWebServer*(port: int = 8080, staticDir: string = "") {.async.} =
  let resolvedStaticDir = if staticDir.len > 0: staticDir else: currentSourcePath().parentDir() / "../view"

  var state = ServerState(
    game: newGame(20, 20),
    agent: newQAgent(),
    mode: "agent",
    highScore: 0,
    lastAction: dirStraight,
    lastQValues: @[0.0, 0.0, 0.0],
    pendingManualDir: dirStraight,
    hasPendingManualDir: false,
    stepsWithoutFood: 0,
    staticDir: resolvedStaticDir
  )

  var server = newAsyncHttpServer()

  proc onRequest(req: Request) {.async.} =
    let path = req.url.path

    if req.reqMethod == HttpGet:
      case path
      of "/", "/index.html":
        let htmlPath = state.staticDir / "index.html"
        if fileExists(htmlPath):
          let content = readFile(htmlPath)
          let headers = newHttpHeaders([("Content-Type", "text/html; charset=utf-8")])
          await req.respond(Http200, content, headers)
        else:
          await req.respond(Http404, "index.html not found at " & htmlPath)
      of "/app.js":
        let jsPath = state.staticDir / "app.js"
        if fileExists(jsPath):
          let content = readFile(jsPath)
          let headers = newHttpHeaders([("Content-Type", "application/javascript; charset=utf-8")])
          await req.respond(Http200, content, headers)
        else:
          await req.respond(Http404, "app.js not found")
      of "/api/state":
        let jsonStr = $state.serializeState()
        let headers = newHttpHeaders([
          ("Content-Type", "application/json"),
          ("Access-Control-Allow-Origin", "*")
        ])
        await req.respond(Http200, jsonStr, headers)
      else:
        await req.respond(Http404, "Not Found")

    elif req.reqMethod == HttpPost:
      case path
      of "/api/step":
        state.stepSimulation()
        let jsonStr = $state.serializeState()
        let headers = newHttpHeaders([("Content-Type", "application/json")])
        await req.respond(Http200, jsonStr, headers)

      of "/api/action":
        if req.body.len > 0:
          try:
            let data = parseJson(req.body)
            if data.hasKey("key"):
              let (valid, relDir) = keyToRelativeDirection(data["key"].getStr(), state.game.orientation)
              if valid:
                state.pendingManualDir = relDir
                state.hasPendingManualDir = true
            elif data.hasKey("action"):
              case data["action"].getStr()
              of "dirRight":
                state.pendingManualDir = dirRight
                state.hasPendingManualDir = true
              of "dirLeft":
                state.pendingManualDir = dirLeft
                state.hasPendingManualDir = true
              of "dirStraight":
                state.pendingManualDir = dirStraight
                state.hasPendingManualDir = true
          except Exception as e:
            echo "Error parsing action body: ", e.msg

        # Immediately execute step on manual action for instant responsiveness
        state.stepSimulation()
        let jsonStr = $state.serializeState()
        let headers = newHttpHeaders([("Content-Type", "application/json")])
        await req.respond(Http200, jsonStr, headers)

      of "/api/mode":
        if req.body.len > 0:
          try:
            let data = parseJson(req.body)
            if data.hasKey("mode"):
              state.mode = data["mode"].getStr()
          except Exception as e:
            echo "Error parsing mode: ", e.msg
        let headers = newHttpHeaders([("Content-Type", "application/json")])
        await req.respond(Http200, $(%*{"mode": state.mode}), headers)

      of "/api/reset":
        state.game = newGame(20, 20)
        state.stepsWithoutFood = 0
        state.hasPendingManualDir = false
        let jsonStr = $state.serializeState()
        let headers = newHttpHeaders([("Content-Type", "application/json")])
        await req.respond(Http200, jsonStr, headers)

      else:
        await req.respond(Http404, "Not Found")

    else:
      await req.respond(Http405, "Method Not Allowed")

  echo "=========================================================="
  echo "🚀 Snake IA Web Interface running at: http://localhost:", port
  echo "🎮 Mode: Manual and Agent (DQN Q-Learning)"
  echo "=========================================================="
  server.listen(Port(port))
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(onRequest)
    else:
      await sleepAsync(10)
