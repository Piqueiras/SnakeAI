import std/[random, sequtils, strutils]

type
  Orientation* = enum
    oriUp, oriDown, oriLeft, oriRight

  Direction* = enum
    dirStraight, dirRight, dirLeft

  Tile* = tuple[x: int, y: int]
  Snake* = seq[Tile]

  Game* = ref object
    height*, width*: int
    snake*: Snake
    food*: Tile
    orientation*: Orientation
    finished*: bool

func head*(s: Snake): Tile = s[0]

# Opposite turn: turning right is opposite of turning left
proc `-`*(dir: Direction): Direction =
  case dir
  of dirStraight: dirStraight
  of dirRight: dirLeft
  of dirLeft: dirRight

proc reverse*(dir: Direction): Direction = -dir
proc opposite*(dir: Direction): Direction = -dir

# Computing when two tiles are the same with '=='
proc `==`*(a, b: Tile): bool =
  a.x == b.x and a.y == b.y

func isValidCoordinate*(game: Game, tile: Tile): bool =
  tile.x >= 0 and tile.x < game.width and
  tile.y >= 0 and tile.y < game.height

proc isDanger*(game: Game, tile: Tile): bool =
  not game.isValidCoordinate(tile) or (tile in game.snake)

# Rotates an orientation given a relative direction (Straight, Right, Left)
func applyDirection*(ori: Orientation, dir: Direction): Orientation =
  case dir
  of dirStraight:
    ori
  of dirRight:
    case ori
    of oriUp: oriRight
    of oriRight: oriDown
    of oriDown: oriLeft
    of oriLeft: oriUp
  of dirLeft:
    case ori
    of oriUp: oriLeft
    of oriLeft: oriDown
    of oriDown: oriRight
    of oriRight: oriUp

# Computes a step forward in an orientation
func stepIn*(tile: Tile, ori: Orientation): Tile =
  case ori
  of oriUp: (x: tile.x, y: tile.y - 1)
  of oriDown: (x: tile.x, y: tile.y + 1)
  of oriLeft: (x: tile.x - 1, y: tile.y)
  of oriRight: (x: tile.x + 1, y: tile.y)

proc spawnFood*(game: Game) =
  ## Places food at a random unoccupied tile on the board.
  if game.width <= 0 or game.height <= 0:
    return
  var emptyTiles: seq[Tile] = @[]
  for y in 0 ..< game.height:
    for x in 0 ..< game.width:
      let tile: Tile = (x: x, y: y)
      if tile notin game.snake:
        emptyTiles.add(tile)
  if emptyTiles.len > 0:
    game.food = sample(emptyTiles)
  else:
    game.finished = true

proc newGame*(width: int = 20, height: int = 20): Game =
  result = Game(
    width: width,
    height: height,
    snake: @[(x: width div 2, y: height div 2)], # Middle of the board
    food: (x: 0, y: 0),
    orientation: oriRight,
    finished: false
  )
  result.spawnFood()

# Moves the snake in the relative direction: dirStraight, dirRight, or dirLeft
proc move*(game: Game, dir: Direction) =
  let newOri = game.orientation.applyDirection(dir)
  game.orientation = newOri
  let newHead = game.snake.head.stepIn(newOri)

  if not game.isValidCoordinate(newHead):
    # Head crashed with wall
    game.finished = true
    return
  if newHead in game.snake:
    # Head crashed with body
    game.finished = true
    return
  if newHead == game.food:
    # Head ate food. Don't remove tail, insert new head and spawn new food.
    game.snake.insert(newHead, 0)
    game.spawnFood()
  else:
    # Normal move. Remove tail and insert new head.
    discard game.snake.pop()
    game.snake.insert(newHead, 0)

# All 3 relative directions are always valid (reversing into itself is impossible)
proc actions*(game: Game): seq[Direction] =
  @[dirStraight, dirRight, dirLeft]

func score*(game: Game): int = game.snake.len - 1

func isFinished*(game: Game): bool = game.finished

proc advance*(game: Game, dir: Direction = dirStraight) =
  if game.isFinished():
    raise newException(ValueError, "Game is already finished.")
  game.move(dir)

# Gold Standard 11-boolean sensory inputs (egocentric view):
# [0..2] Danger: Straight, Right, Left
# [3..6] Current Orientation: Up, Down, Left, Right
# [7..10] Relative Food Location: Straight (Ahead), Right, Left, Behind
proc getSensoryInputs*(game: Game): seq[float] =
  result = newSeq[float](11)
  if game.snake.len == 0:
    return

  let head = game.snake[0]
  let ori = game.orientation

  # 1. Immediate Dangers (Straight, Right, Left)
  let straightTile = head.stepIn(ori.applyDirection(dirStraight))
  let rightTile = head.stepIn(ori.applyDirection(dirRight))
  let leftTile = head.stepIn(ori.applyDirection(dirLeft))

  result[0] = (if game.isDanger(straightTile): 1.0 else: 0.0)
  result[1] = (if game.isDanger(rightTile): 1.0 else: 0.0)
  result[2] = (if game.isDanger(leftTile): 1.0 else: 0.0)

  # 2. Current Orientation (One-Hot)
  result[3] = (if ori == oriUp: 1.0 else: 0.0)
  result[4] = (if ori == oriDown: 1.0 else: 0.0)
  result[5] = (if ori == oriLeft: 1.0 else: 0.0)
  result[6] = (if ori == oriRight: 1.0 else: 0.0)

  # 3. Relative Food Position
  let dx = game.food.x - head.x
  let dy = game.food.y - head.y

  var foodAhead, foodRight, foodLeft, foodBehind = false
  case ori
  of oriUp:
    foodAhead = dy < 0
    foodBehind = dy > 0
    foodRight = dx > 0
    foodLeft = dx < 0
  of oriDown:
    foodAhead = dy > 0
    foodBehind = dy < 0
    foodRight = dx < 0
    foodLeft = dx > 0
  of oriRight:
    foodAhead = dx > 0
    foodBehind = dx < 0
    foodRight = dy > 0
    foodLeft = dy < 0
  of oriLeft:
    foodAhead = dx < 0
    foodBehind = dx > 0
    foodRight = dy < 0
    foodLeft = dy > 0

  result[7] = (if foodAhead: 1.0 else: 0.0)
  result[8] = (if foodRight: 1.0 else: 0.0)
  result[9] = (if foodLeft: 1.0 else: 0.0)
  result[10] = (if foodBehind: 1.0 else: 0.0)

# Print functions for Game
proc `$`*(game: Game): string =
  result = ""
  result.add("+" & repeat('-', game.width) & "+\n")
  for y in 0 ..< game.height:
    result.add("|")
    for x in 0 ..< game.width:
      let tile: Tile = (x: x, y: y)
      if game.snake.len > 0 and tile == game.snake[0]:
        case game.orientation
        of oriUp: result.add("^")
        of oriDown: result.add("v")
        of oriLeft: result.add("<")
        of oriRight: result.add(">")
      elif tile in game.snake:
        result.add("o")
      elif tile == game.food:
        result.add("*")
      else:
        result.add(" ")
    result.add("|\n")
  result.add("+" & repeat('-', game.width) & "+\n")
  result.add("Score: " & $game.score() & " | Ori: " & $game.orientation & " | Status: " & (if game.finished: "Game Over" else: "Alive"))

proc print*(game: Game) =
  echo $game
