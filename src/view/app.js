// Snake IA - HTML5 Canvas & Q-Learning Telemetry Frontend

const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');

const progressCanvas = document.getElementById('progressCanvas');
const pCtx = progressCanvas ? progressCanvas.getContext('2d') : null;

let gameState = null;
let isPaused = false;
let targetFps = 15;
let lastStepTime = 0;
let currentMode = 'agent';

// DOM Elements
const currentScoreEl = document.getElementById('currentScore');
const highScoreEl = document.getElementById('highScore');
const episodeCountEl = document.getElementById('episodeCount');
const epsilonValueEl = document.getElementById('epsilonValue');

const currentLossVal = document.getElementById('currentLossVal');
const currentScoreGraphVal = document.getElementById('currentScoreGraphVal');
const chartEpisodeCount = document.getElementById('chartEpisodeCount');

const valStraight = document.getElementById('valStraight');
const valRight = document.getElementById('valRight');
const valLeft = document.getElementById('valLeft');

const barStraight = document.getElementById('barStraight');
const barRight = document.getElementById('barRight');
const barLeft = document.getElementById('barLeft');

const tagStraight = document.getElementById('tagStraight');
const tagRight = document.getElementById('tagRight');
const tagLeft = document.getElementById('tagLeft');

const modeToggleBtn = document.getElementById('modeToggleBtn');
const modeBadge = document.getElementById('modeBadge');
const modeDot = document.getElementById('modeDot');
const modeText = document.getElementById('modeText');
const manualHelp = document.getElementById('manualHelp');
const pauseBtn = document.getElementById('pauseBtn');
const resetBtn = document.getElementById('resetBtn');
const speedSlider = document.getElementById('speedSlider');
const speedValue = document.getElementById('speedValue');

// --- Networking ---

async function fetchState() {
  try {
    const res = await fetch('/api/state');
    if (res.ok) {
      gameState = await res.json();
      updateDashboard(gameState);
    }
  } catch (err) {
    console.error('Error fetching state:', err);
  }
}

async function stepSimulation() {
  if (isPaused) return;
  try {
    const res = await fetch('/api/step', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
    });
    if (res.ok) {
      gameState = await res.json();
      updateDashboard(gameState);
    }
  } catch (err) {
    console.error('Error stepping simulation:', err);
  }
}

async function sendManualAction(key) {
  try {
    const res = await fetch('/api/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key })
    });
    if (res.ok) {
      gameState = await res.json();
      updateDashboard(gameState);
    }
  } catch (err) {
    console.error('Error sending action:', err);
  }
}

async function toggleMode() {
  const newMode = currentMode === 'agent' ? 'manual' : 'agent';
  try {
    const res = await fetch('/api/mode', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ mode: newMode })
    });
    if (res.ok) {
      const data = await res.json();
      currentMode = data.mode;
      applyModeUI(currentMode);
    }
  } catch (err) {
    console.error('Error toggling mode:', err);
  }
}

async function resetGame() {
  try {
    const res = await fetch('/api/reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
    });
    if (res.ok) {
      gameState = await res.json();
      updateDashboard(gameState);
    }
  } catch (err) {
    console.error('Error resetting game:', err);
  }
}

// --- Dashboard UI Updates ---

function applyModeUI(mode) {
  if (mode === 'agent') {
    modeText.textContent = 'Mode: Agent (DQN)';
    modeDot.style.background = '#22c55e';
    modeDot.style.boxShadow = '0 0 8px #22c55e';
    modeToggleBtn.innerHTML = '<span>🎮 Switch to Manual</span>';
    modeToggleBtn.className = 'btn-active-mode';
    manualHelp.style.display = 'none';
  } else {
    modeText.textContent = 'Mode: Manual (Player)';
    modeDot.style.background = '#38bdf8';
    modeDot.style.boxShadow = '0 0 8px #38bdf8';
    modeToggleBtn.innerHTML = '<span>🤖 Switch to Agent</span>';
    modeToggleBtn.className = 'btn-primary';
    manualHelp.style.display = 'block';
  }
}

function updateDashboard(state) {
  if (!state) return;

  currentScoreEl.textContent = state.score;
  highScoreEl.textContent = state.highScore;
  episodeCountEl.textContent = state.episode;
  epsilonValueEl.textContent = state.epsilon.toFixed(2);

  if (currentLossVal) {
    const lossDisplay = state.lastEpisodeLoss > 0 ? state.lastEpisodeLoss : state.currentLoss;
    currentLossVal.textContent = lossDisplay.toFixed(4);
  }
  if (currentScoreGraphVal) {
    currentScoreGraphVal.textContent = state.score;
  }
  if (chartEpisodeCount) {
    chartEpisodeCount.textContent = state.episode;
  }

  if (state.mode !== currentMode) {
    currentMode = state.mode;
    applyModeUI(currentMode);
  }

  // Update Q-value telemetry
  if (state.qValues && state.qValues.length === 3) {
    const [qS, qR, qL] = state.qValues;
    valStraight.textContent = qS.toFixed(3);
    valRight.textContent = qR.toFixed(3);
    valLeft.textContent = qL.toFixed(3);

    // Map Q-values to percentage bars
    const minQ = Math.min(qS, qR, qL, 0);
    const maxQ = Math.max(qS, qR, qL, 1);
    const range = Math.max(maxQ - minQ, 0.001);

    const pctS = Math.max(5, Math.min(100, ((qS - minQ) / range) * 100));
    const pctR = Math.max(5, Math.min(100, ((qR - minQ) / range) * 100));
    const pctL = Math.max(5, Math.min(100, ((qL - minQ) / range) * 100));

    barStraight.style.width = pctS + '%';
    barRight.style.width = pctR + '%';
    barLeft.style.width = pctL + '%';

    // Highlight chosen action
    tagStraight.style.display = state.lastAction === 'dirStraight' ? 'inline' : 'none';
    tagRight.style.display = state.lastAction === 'dirRight' ? 'inline' : 'none';
    tagLeft.style.display = state.lastAction === 'dirLeft' ? 'inline' : 'none';

    barStraight.className = 'q-bar-fill' + (state.lastAction === 'dirStraight' ? ' q-bar-selected' : '');
    barRight.className = 'q-bar-fill' + (state.lastAction === 'dirRight' ? ' q-bar-selected' : '');
    barLeft.className = 'q-bar-fill' + (state.lastAction === 'dirLeft' ? ' q-bar-selected' : '');
  }

  // Update Dual Progress Chart
  if (pCtx && state.lossHistory && state.scoreHistory) {
    renderProgressChart(state.lossHistory, state.scoreHistory);
  }
}

// --- Dual Progress Chart Rendering (All episodes from the start) ---

function renderProgressChart(losses, scores) {
  if (!pCtx) return;
  const w = progressCanvas.width;
  const h = progressCanvas.height;

  pCtx.clearRect(0, 0, w, h);

  const padLeft = 35;
  const padRight = 15;
  const padTop = 15;
  const padBottom = 20;
  const plotW = w - padLeft - padRight;
  const plotH = h - padTop - padBottom;

  // Background grid lines
  pCtx.strokeStyle = '#151d30';
  pCtx.lineWidth = 1;
  for (let y = 0; y <= 4; y++) {
    const py = padTop + (plotH / 4) * y;
    pCtx.beginPath();
    pCtx.moveTo(padLeft, py);
    pCtx.lineTo(w - padRight, py);
    pCtx.stroke();
  }

  if (losses.length < 1) {
    pCtx.fillStyle = '#64748b';
    pCtx.font = '12px sans-serif';
    pCtx.textAlign = 'center';
    pCtx.fillText('Awaiting first episode completion to plot training curves...', w / 2, h / 2);
    return;
  }

  const n = losses.length;

  // Find max values for normalization
  let maxLoss = 0.001;
  let maxScore = 1;
  for (let i = 0; i < n; i++) {
    if (losses[i] > maxLoss) maxLoss = losses[i];
    if (scores[i] > maxScore) maxScore = scores[i];
  }

  // Draw X/Y axes
  pCtx.strokeStyle = '#2a375a';
  pCtx.lineWidth = 1.5;
  pCtx.beginPath();
  pCtx.moveTo(padLeft, padTop);
  pCtx.lineTo(padLeft, h - padBottom);
  pCtx.lineTo(w - padRight, h - padBottom);
  pCtx.stroke();

  // Y-axis labels
  pCtx.fillStyle = '#64748b';
  pCtx.font = '10px monospace';
  pCtx.textAlign = 'right';
  pCtx.fillText(maxLoss.toFixed(1), padLeft - 4, padTop + 8);
  pCtx.fillText('0', padLeft - 4, h - padBottom);

  // Helper to get coordinates
  function getX(i) {
    if (n === 1) return padLeft + plotW / 2;
    return padLeft + (i / (n - 1)) * plotW;
  }

  // 1. Plot Loss curve (Red #f87171)
  pCtx.strokeStyle = '#f87171';
  pCtx.lineWidth = 2;
  pCtx.beginPath();
  for (let i = 0; i < n; i++) {
    const x = getX(i);
    const y = (h - padBottom) - (losses[i] / maxLoss) * plotH;
    if (i === 0) pCtx.moveTo(x, y);
    else pCtx.lineTo(x, y);
  }
  pCtx.stroke();

  // 2. Plot Score curve (Cyan #38bdf8)
  pCtx.strokeStyle = '#38bdf8';
  pCtx.lineWidth = 2;
  pCtx.beginPath();
  for (let i = 0; i < n; i++) {
    const x = getX(i);
    const y = (h - padBottom) - (scores[i] / maxScore) * plotH;
    if (i === 0) pCtx.moveTo(x, y);
    else pCtx.lineTo(x, y);
  }
  pCtx.stroke();

  // Draw dot on latest points
  const lastX = getX(n - 1);
  const lastLossY = (h - padBottom) - (losses[n - 1] / maxLoss) * plotH;
  const lastScoreY = (h - padBottom) - (scores[n - 1] / maxScore) * plotH;

  pCtx.fillStyle = '#f87171';
  pCtx.beginPath();
  pCtx.arc(lastX, lastLossY, 4, 0, Math.PI * 2);
  pCtx.fill();

  pCtx.fillStyle = '#38bdf8';
  pCtx.beginPath();
  pCtx.arc(lastX, lastScoreY, 4, 0, Math.PI * 2);
  pCtx.fill();
}

// --- Canvas Rendering ---

let foodPulse = 0;

function render() {
  foodPulse += 0.05;

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const gridCols = (gameState && gameState.width) || 20;
  const gridRows = (gameState && gameState.height) || 20;
  const tileW = canvas.width / gridCols;
  const tileH = canvas.height / gridRows;

  // 1. Draw subtle background grid
  ctx.strokeStyle = '#151d30';
  ctx.lineWidth = 1;
  for (let x = 0; x <= gridCols; x++) {
    ctx.beginPath();
    ctx.moveTo(x * tileW, 0);
    ctx.lineTo(x * tileW, canvas.height);
    ctx.stroke();
  }
  for (let y = 0; y <= gridRows; y++) {
    ctx.beginPath();
    ctx.moveTo(0, y * tileH);
    ctx.lineTo(canvas.width, y * tileH);
    ctx.stroke();
  }

  if (!gameState) return;

  // 2. Draw Food with glowing pulse
  if (gameState.food) {
    const fx = gameState.food.x * tileW + tileW / 2;
    const fy = gameState.food.y * tileH + tileH / 2;
    const baseRadius = (tileW / 2) * 0.75;
    const radius = baseRadius + Math.sin(foodPulse) * 1.5;

    ctx.save();
    ctx.shadowColor = '#ef4444';
    ctx.shadowBlur = 12;
    ctx.fillStyle = '#ef4444';
    ctx.beginPath();
    ctx.arc(fx, fy, radius, 0, Math.PI * 2);
    ctx.fill();

    // Specular highlight on food
    ctx.fillStyle = '#fca5a5';
    ctx.beginPath();
    ctx.arc(fx - radius * 0.3, fy - radius * 0.3, radius * 0.35, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // 3. Draw Snake Body (Vibrant Green)
  if (gameState.snake && gameState.snake.length > 0) {
    const padding = 2;

    for (let i = gameState.snake.length - 1; i >= 1; i--) {
      const seg = gameState.snake[i];
      const sx = seg.x * tileW + padding;
      const sy = seg.y * tileH + padding;
      const sw = tileW - padding * 2;
      const sh = tileH - padding * 2;

      ctx.fillStyle = '#4ade80';
      ctx.beginPath();
      ctx.roundRect(sx, sy, sw, sh, 5);
      ctx.fill();
    }

    // 4. Draw Snake Head (Darker Green, as requested)
    const head = gameState.snake[0];
    const hx = head.x * tileW + padding;
    const hy = head.y * tileH + padding;
    const hw = tileW - padding * 2;
    const hh = tileH - padding * 2;

    ctx.save();
    ctx.shadowColor = '#15803d';
    ctx.shadowBlur = 8;
    ctx.fillStyle = '#15803d'; // DARKER GREEN FOR HEAD
    ctx.beginPath();
    ctx.roundRect(hx, hy, hw, hh, 7);
    ctx.fill();
    ctx.restore();

    // 5. Draw Eyes based on Orientation
    const eyeRadius = 2.2;
    const pupilRadius = 1.2;
    let eye1 = { x: 0, y: 0 };
    let eye2 = { x: 0, y: 0 };
    const cx = head.x * tileW + tileW / 2;
    const cy = head.y * tileH + tileH / 2;

    const ori = gameState.orientation || 'oriRight';
    if (ori === 'oriRight') {
      eye1 = { x: cx + tileW * 0.2, y: cy - tileH * 0.22 };
      eye2 = { x: cx + tileW * 0.2, y: cy + tileH * 0.22 };
    } else if (ori === 'oriLeft') {
      eye1 = { x: cx - tileW * 0.2, y: cy - tileH * 0.22 };
      eye2 = { x: cx - tileW * 0.2, y: cy + tileH * 0.22 };
    } else if (ori === 'oriUp') {
      eye1 = { x: cx - tileW * 0.22, y: cy - tileH * 0.2 };
      eye2 = { x: cx + tileW * 0.22, y: cy - tileH * 0.2 };
    } else if (ori === 'oriDown') {
      eye1 = { x: cx - tileW * 0.22, y: cy + tileH * 0.2 };
      eye2 = { x: cx + tileW * 0.22, y: cy + tileH * 0.2 };
    }

    // White eye sclera
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(eye1.x, eye1.y, eyeRadius, 0, Math.PI * 2);
    ctx.arc(eye2.x, eye2.y, eyeRadius, 0, Math.PI * 2);
    ctx.fill();

    // Black pupils
    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.arc(eye1.x, eye1.y, pupilRadius, 0, Math.PI * 2);
    ctx.arc(eye2.x, eye2.y, pupilRadius, 0, Math.PI * 2);
    ctx.fill();
  }

  // 6. Draw Game Over Overlay
  if (gameState.finished) {
    ctx.fillStyle = 'rgba(15, 23, 42, 0.75)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.fillStyle = '#ef4444';
    ctx.font = 'bold 26px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('GAME OVER', canvas.width / 2, canvas.height / 2 - 10);

    ctx.fillStyle = '#94a3b8';
    ctx.font = '14px sans-serif';
    ctx.fillText(currentMode === 'agent' ? 'Restarting next episode...' : 'Press Reset to play again', canvas.width / 2, canvas.height / 2 + 20);
  }
}

// --- Main Animation & Loop ---

function gameLoop(timestamp) {
  const interval = 1000 / targetFps;

  if (timestamp - lastStepTime >= interval) {
    stepSimulation();
    lastStepTime = timestamp;
  }

  render();
  requestAnimationFrame(gameLoop);
}

// --- Event Listeners ---

modeToggleBtn.addEventListener('click', toggleMode);

pauseBtn.addEventListener('click', () => {
  isPaused = !isPaused;
  pauseBtn.innerHTML = isPaused ? '<span>▶️ Resume</span>' : '<span>⏸️ Pause</span>';
});

resetBtn.addEventListener('click', resetGame);

speedSlider.addEventListener('input', (e) => {
  targetFps = parseInt(e.target.value);
  speedValue.textContent = targetFps;
});

// Keyboard controls (Arrow keys, WASD, A/D)
window.addEventListener('keydown', (e) => {
  const key = e.key;
  const validKeys = [
    'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
    'w', 'W', 's', 'S', 'a', 'A', 'd', 'D'
  ];

  if (validKeys.includes(key)) {
    e.preventDefault();
    if (currentMode === 'manual') {
      sendManualAction(key);
    }
  }
});

// Initial load
fetchState().then(() => {
  requestAnimationFrame(gameLoop);
});
