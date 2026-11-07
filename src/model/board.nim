import std/[random, sequtils, strutils]

type
  Direction* = enum
    dirUp, dirDown, dirLeft, dirRight

  Tile* = tuple[x: int, y: int]
  Snake* = seq[Tile]

  Game* = ref object
    height*, width*: int
    snake*: Snake
    food*: Tile
    direction*: Direction
    finished*: bool

func head*(s: Snake): Tile = s[0]

# Reversing direction like dirUp = -dirDown
proc `-`*(dir: Direction): Direction =
  case dir
  of dirUp: dirDown
  of dirDown: dirUp
  of dirLeft: dirRight
  of dirRight: dirLeft

proc reverse*(dir: Direction): Direction = -dir
proc opposite*(dir: Direction): Direction = -dir

# Relative rotations (egocentric view)
func turnRight*(dir: Direction): Direction =
  case dir
  of dirUp: dirRight
  of dirRight: dirDown
  of dirDown: dirLeft
  of dirLeft: dirUp

func turnLeft*(dir: Direction): Direction =
  case dir
  of dirUp: dirLeft
  of dirLeft: dirDown
  of dirDown: dirRight
  of dirRight: dirUp

# Computing when two tiles are the same with '=='
proc `==`*(a, b: Tile): bool =
  a.x == b.x and a.y == b.y

func isValidCoordinate*(game: Game, tile: Tile): bool =
  tile.x >= 0 and tile.x < game.width and
  tile.y >= 0 and tile.y < game.height

proc isDanger*(game: Game, tile: Tile): bool =
  not game.isValidCoordinate(tile) or (tile in game.snake)

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
    direction: dirRight,
    finished: false
  )
  result.spawnFood()

# Move a tile in a direction, returning the new coordinates
func moved*(head: Tile, dir: Direction): Tile =
  case dir
  of dirUp: (x: head.x, y: head.y - 1)
  of dirDown: (x: head.x, y: head.y + 1)
  of dirLeft: (x: head.x - 1, y: head.y)
  of dirRight: (x: head.x + 1, y: head.y)

# Moves the snake in the given direction
proc move*(game: Game, dir: Direction) =
  game.direction = dir
  let newHead = game.snake.head.moved(dir)
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
    # Normal move. Remove the tail and add the new head.
    discard game.snake.pop()
    game.snake.insert(newHead, 0)

# Returns a sequence of valid directions the snake can move in.
proc actions*(game: Game): seq[Direction] =
  toSeq({dirUp, dirDown, dirLeft, dirRight} - {-game.direction})

func score*(game: Game): int = game.snake.len - 1

func isFinished*(game: Game): bool = game.finished

proc canAdvance*(game: Game, dir: Direction): bool =
  dir != -game.direction

# Change state function
proc advance*(game: Game, dir: Direction) =
  if game.isFinished():
    raise newException(ValueError, "Game is already finished.")
  if dir == -game.direction:
    raise newException(ValueError, "Cannot move in the opposite direction of the current movement.")
  game.move(dir)

# Do nothing, keep going
proc advance*(game: Game) =
  game.advance(game.direction)

# Gold Standard 11-boolean sensory inputs:
# [0..2] Danger: Straight, Right, Left (immediate danger in next tile)
# [3..6] Current Direction: Up, Down, Left, Right
# [7..10] Food Location: Up, Down, Left, Right
proc getSensoryInputs*(game: Game): seq[float] =
  result = newSeq[float](11)
  if game.snake.len == 0:
    return

  let head = game.snake[0]
  let dir = game.direction

  # 1. Immediate Dangers (Straight, Right, Left)
  result[0] = (if game.isDanger(head.moved(dir)): 1.0 else: 0.0)
  result[1] = (if game.isDanger(head.moved(dir.turnRight)): 1.0 else: 0.0)
  result[2] = (if game.isDanger(head.moved(dir.turnLeft)): 1.0 else: 0.0)

  # 2. Current Direction (One-Hot)
  result[3] = (if dir == dirUp: 1.0 else: 0.0)
  result[4] = (if dir == dirDown: 1.0 else: 0.0)
  result[5] = (if dir == dirLeft: 1.0 else: 0.0)
  result[6] = (if dir == dirRight: 1.0 else: 0.0)

  # 3. Food Location relative to head
  result[7] = (if game.food.y < head.y: 1.0 else: 0.0) # Food is Up
  result[8] = (if game.food.y > head.y: 1.0 else: 0.0) # Food is Down
  result[9] = (if game.food.x < head.x: 1.0 else: 0.0) # Food is Left
  result[10] = (if game.food.x > head.x: 1.0 else: 0.0) # Food is Right

# Print functions for Game
proc `$`*(game: Game): string =
  result = ""
  result.add("+" & repeat('-', game.width) & "+\n")
  for y in 0 ..< game.height:
    result.add("|")
    for x in 0 ..< game.width:
      let tile: Tile = (x: x, y: y)
      if game.snake.len > 0 and tile == game.snake[0]:
        result.add("H")
      elif tile in game.snake:
        result.add("o")
      elif tile == game.food:
        result.add("*")
      else:
        result.add(" ")
    result.add("|\n")
  result.add("+" & repeat('-', game.width) & "+\n")
  result.add("Score: " & $game.score() & " | Dir: " & $game.direction & " | Status: " & (if game.finished: "Game Over" else: "Alive"))

proc print*(game: Game) =
  echo $game
