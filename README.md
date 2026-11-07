## Snake reinforcement learning with Deep Q-Networks (DQN), written in Nim.

### Game Core
- **Relative Direction Space**: The only actions the snake can take are going straight (`dirStraight`), turning right (`dirRight`), or turning left (`dirLeft`). This makes 180° self-reversal physically impossible.
- **Sensory Inputs (11 Boolean Features)**:
  - Immediate Dangers: `[Straight, Right, Left]`
  - Current Heading: `[Up, Down, Left, Right]`
  - Relative Food Location: `[Ahead, Right, Left, Behind]`

### Features & Web Interface
- **HTML5 Canvas Visualizer**:
  - Snake Head: Darker Green (`#15803d`) with directional eyes.
  - Snake Body: Vibrant Green (`#4ade80`).
  - Food: Pulsing Red (`#ef4444`).
- **Two Game Modes**:
  - **Manual Mode**: Steer the snake manually using Arrow Keys / WASD (absolute direction) or A / D (relative steer).
  - **Agent Mode**: Autonomous Deep Q-Learning agent playing and learning in real-time.
- **Live Q-Value Telemetry Dashboard**:
  - Displays real-time predicted values for `Q(Straight)`, `Q(Right)`, `Q(Left)` and highlights the selected action.
  - Live statistics: Score, High Score, Episodes (Games), and Epsilon ($\epsilon$) exploration rate.
  - Speed slider (from 2 FPS to 60 FPS) and game pause/reset controls.

### How to Run
```bash
nim r src/main.nim
```
Open **[http://localhost:8080](http://localhost:8080)** in your browser.
