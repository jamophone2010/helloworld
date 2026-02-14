-- raid.lua: "Logician's Lament" - Endgame PCB Motherboard Raid Level
-- Player flies through a motherboard landscape with resistors, capacitors,
-- trace paths, and vias that teleport between PCB layers.
-- Tron Legacy Lightcycles aesthetic: neon cyan/orange on black.

local M = {}
local screen = require("starfox.screen")

-- === PCB LAYER SYSTEM ===
M.currentLayer = 1          -- 1 = top copper, 2 = inner1, 3 = inner2, 4 = bottom copper
M.layerCount = 4
M.layerTransitioning = false
M.layerTransitionTimer = 0
M.layerTransitionDuration = 0.6
M.targetLayer = 1

-- Layer color palettes (Tron Legacy aesthetic)
M.LAYER_PALETTES = {
  -- Layer 1: Top copper - classic Tron cyan
  { trace = {0, 0.9, 1},   glow = {0, 0.6, 0.8},   bg = {0.01, 0.01, 0.04}, name = "TOP COPPER" },
  -- Layer 2: Inner 1 - hot orange (Rinzler/CLU)
  { trace = {1, 0.55, 0},  glow = {0.8, 0.35, 0},   bg = {0.03, 0.01, 0.01}, name = "INNER LAYER 1" },
  -- Layer 3: Inner 2 - violet/magenta (Identity Disc)
  { trace = {0.8, 0.2, 1}, glow = {0.5, 0.1, 0.7},  bg = {0.02, 0.01, 0.03}, name = "INNER LAYER 2" },
  -- Layer 4: Bottom copper - white/gold (Flynn's grid)
  { trace = {1, 0.9, 0.5}, glow = {0.7, 0.6, 0.2},  bg = {0.02, 0.02, 0.01}, name = "BOTTOM COPPER" },
}

-- === PCB COMPONENTS (obstacles) ===
M.components = {}       -- Resistors, capacitors, ICs, designators
M.traces = {}           -- Circuit traces (decorative + collision)
M.vias = {}             -- Layer transition points
M.puzzles = {}          -- Active logic puzzles
M.puzzleGates = {}      -- Gates that block progress until puzzle solved
M.hazards = {}          -- Electrical hazards (arc discharges, etc.)

-- === SCROLLING ===
M.scrollY = 0
M.scrollSpeed = 80      -- Slower than normal - raid is methodical
M.raidTimer = 0
M.raidActive = false
M.bossReached = false
M.cpuApproachTimer = 0

-- === PUZZLE STATE ===
M.activePuzzle = nil
M.puzzleSolvedCount = 0
M.puzzleRequired = 4    -- Must solve 4 puzzles to reach the CPU die
M.puzzleInput = {}
M.puzzleHintTimer = 0

-- === VIA PROMPT ===
M.viaPrompt = nil       -- {via, timer} when player is over a via
M.viaFlashTimer = 0

-- === DESIGNATOR LABELS (floating PCB text like R1, C5, U3) ===
M.designators = {}

-- === TRACE PARTICLES (Tron lightcycle trails) ===
M.traceParticles = {}

function M.reset()
  M.currentLayer = 1
  M.layerTransitioning = false
  M.layerTransitionTimer = 0
  M.targetLayer = 1
  M.components = {}
  M.traces = {}
  M.vias = {}
  M.puzzles = {}
  M.puzzleGates = {}
  M.hazards = {}
  M.scrollY = 0
  M.raidTimer = 0
  M.raidActive = false
  M.bossReached = false
  M.cpuApproachTimer = 0
  M.activePuzzle = nil
  M.puzzleSolvedCount = 0
  M.puzzleInput = {}
  M.puzzleHintTimer = 0
  M.viaPrompt = nil
  M.viaFlashTimer = 0
  M.designators = {}
  M.traceParticles = {}
end

function M.activate()
  M.reset()
  M.raidActive = true
  M.currentLayer = 1
  M.generateInitialLayout()
end

function M.isActive()
  return M.raidActive
end

function M.isBossReached()
  return M.bossReached
end

-- =============================================
-- PROCEDURAL PCB LAYOUT GENERATION
-- =============================================

function M.generateInitialLayout()
  -- Generate the initial visible components
  for i = 1, 8 do
    M.spawnComponentRow(-200 - i * 300)
  end

  -- Spawn initial traces
  for i = 1, 15 do
    M.spawnTrace(-100 - i * 180)
  end

  -- Spawn vias at intervals
  M.spawnVia(screen.WIDTH * 0.25, -600, 1, 2)
  M.spawnVia(screen.WIDTH * 0.75, -1200, 1, 3)
  M.spawnVia(screen.WIDTH * 0.5, -1800, 2, 4)
  M.spawnVia(screen.WIDTH * 0.3, -2400, 3, 1)

  -- Generate designator labels
  M.generateDesignators()

  -- Spawn initial puzzle at t=0 area
  M.spawnPuzzle(-800)
end

function M.spawnComponentRow(y)
  local numComponents = math.random(3, 6)
  local spacing = screen.WIDTH / (numComponents + 1)

  for i = 1, numComponents do
    local x = spacing * i + (math.random() - 0.5) * 40
    local compType = M.randomComponentType()
    table.insert(M.components, {
      x = x,
      y = y,
      type = compType,
      layer = math.random(1, M.layerCount),
      width = compType == "ic" and 80 or (compType == "capacitor" and 20 or 40),
      height = compType == "ic" and 50 or (compType == "capacitor" and 35 or 15),
      health = compType == "ic" and 5 or 2,
      designator = M.makeDesignator(compType),
      glowPhase = math.random() * math.pi * 2,
      destroyed = false,
    })
  end
end

function M.randomComponentType()
  local roll = math.random(100)
  if roll < 30 then return "resistor"
  elseif roll < 50 then return "capacitor"
  elseif roll < 65 then return "ic"
  elseif roll < 80 then return "diode"
  elseif roll < 90 then return "inductor"
  else return "transistor"
  end
end

function M.makeDesignator(compType)
  local prefixes = {
    resistor = "R", capacitor = "C", ic = "U",
    diode = "D", inductor = "L", transistor = "Q"
  }
  return (prefixes[compType] or "X") .. math.random(1, 999)
end

function M.spawnTrace(y)
  local x1 = math.random(50, screen.WIDTH - 50)
  local x2 = math.random(50, screen.WIDTH - 50)
  local segments = math.random(2, 5)
  local points = {}

  for i = 0, segments do
    local t = i / segments
    local px = x1 + (x2 - x1) * t + (math.random() - 0.5) * 100
    local py = y + i * 60
    table.insert(points, {x = px, y = py})
  end

  table.insert(M.traces, {
    points = points,
    layer = math.random(1, M.layerCount),
    width = math.random(2, 4),
    powered = math.random() > 0.5,
    pulseOffset = math.random() * math.pi * 2,
  })
end

function M.spawnVia(x, y, fromLayer, toLayer)
  table.insert(M.vias, {
    x = x,
    y = y,
    fromLayer = fromLayer,
    toLayer = toLayer,
    radius = 22,
    innerRadius = 12,
    rotation = 0,
    active = true,
    pulse = math.random() * math.pi * 2,
  })
end

function M.generateDesignators()
  -- Scatter floating PCB reference designators for atmosphere
  for i = 1, 20 do
    local types = {"R", "C", "U", "D", "L", "Q", "J", "TP", "FB"}
    table.insert(M.designators, {
      x = math.random(30, screen.WIDTH - 30),
      y = math.random(-3000, 0),
      text = types[math.random(#types)] .. math.random(1, 200),
      layer = math.random(1, M.layerCount),
      alpha = 0.15 + math.random() * 0.15,
    })
  end
end

-- =============================================
-- PUZZLE SYSTEM - Logic Gate Puzzles
-- =============================================
-- Puzzles appear as circuit diagrams. Player must shoot correct
-- inputs (AND, OR, XOR, NAND gates) to open the gate blocking path.

function M.spawnPuzzle(y)
  local puzzleType = M.randomPuzzleType()
  local puzzle = {
    x = screen.WIDTH / 2,
    y = y,
    type = puzzleType,
    solved = false,
    inputs = {},
    expectedOutput = false,
    gateWidth = 200,
    gateHeight = 120,
    timer = 0,
    hintShown = false,
    inputHighlight = 0,
    damageOnWrong = 10,
  }

  -- Generate puzzle based on type
  if puzzleType == "and" then
    puzzle.inputs = {
      {x = -60, y = -30, state = false, label = "A"},
      {x = -60, y = 30,  state = false, label = "B"},
    }
    puzzle.expectedOutput = true  -- Both must be true
    puzzle.hint = "BOTH INPUTS MUST BE HIGH"
  elseif puzzleType == "or" then
    puzzle.inputs = {
      {x = -60, y = -30, state = false, label = "A"},
      {x = -60, y = 30,  state = false, label = "B"},
    }
    puzzle.expectedOutput = true  -- At least one true
    puzzle.hint = "AT LEAST ONE INPUT MUST BE HIGH"
  elseif puzzleType == "xor" then
    puzzle.inputs = {
      {x = -60, y = -30, state = true,  label = "A"},
      {x = -60, y = 30,  state = false, label = "B"},
    }
    puzzle.expectedOutput = true  -- Exactly one true
    puzzle.hint = "EXACTLY ONE INPUT MUST BE HIGH"
  elseif puzzleType == "nand" then
    puzzle.inputs = {
      {x = -60, y = -30, state = true,  label = "A"},
      {x = -60, y = 30,  state = true,  label = "B"},
    }
    puzzle.expectedOutput = false  -- NOT(AND)
    puzzle.hint = "NOT BOTH INPUTS CAN BE HIGH"
  elseif puzzleType == "sequence" then
    -- Binary sequence: player must toggle inputs to match target
    local target = math.random(0, 15)  -- 4-bit
    puzzle.inputs = {
      {x = -80, y = -45, state = false, label = "D3"},
      {x = -80, y = -15, state = false, label = "D2"},
      {x = -80, y = 15,  state = false, label = "D1"},
      {x = -80, y = 45,  state = false, label = "D0"},
    }
    puzzle.targetBinary = target
    puzzle.hint = string.format("SET BINARY: %04d", tonumber(M.toBinaryString(target)))
    puzzle.expectedOutput = true
  elseif puzzleType == "resistor_code" then
    -- Read resistor color bands and shoot the matching value
    local values = {100, 220, 330, 470, 1000, 2200, 4700, 10000}
    local targetVal = values[math.random(#values)]
    puzzle.targetValue = targetVal
    puzzle.inputs = {
      {x = -60, y = -20, state = false, label = M.formatResistorValue(targetVal)},
      {x = -60, y = 20,  state = false, label = "WRONG"},
    }
    puzzle.hint = "DECODE THE COLOR BANDS"
    puzzle.expectedOutput = true
  end

  table.insert(M.puzzles, puzzle)

  -- Spawn a gate barrier that blocks until solved
  table.insert(M.puzzleGates, {
    x = screen.WIDTH / 2,
    y = y + 80,
    width = screen.WIDTH - 100,
    height = 20,
    puzzleIndex = #M.puzzles,
    open = false,
    openTimer = 0,
    electricArc = 0,
  })
end

function M.randomPuzzleType()
  local types = {"and", "or", "xor", "nand", "sequence", "resistor_code"}
  return types[math.random(#types)]
end

function M.toBinaryString(n)
  local s = ""
  for i = 3, 0, -1 do
    s = s .. (math.floor(n / (2^i)) % 2 == 1 and "1" or "0")
  end
  return s
end

function M.formatResistorValue(val)
  if val >= 1000000 then return string.format("%.1fMΩ", val / 1000000)
  elseif val >= 1000 then return string.format("%.0fkΩ", val / 1000)
  else return string.format("%.0fΩ", val)
  end
end

-- =============================================
-- UPDATE
-- =============================================

function M.update(dt, playerX, playerY)
  if not M.raidActive then return end

  M.raidTimer = M.raidTimer + dt
  M.scrollY = M.scrollY + M.scrollSpeed * dt
  M.viaFlashTimer = M.viaFlashTimer + dt

  -- Layer transition animation
  if M.layerTransitioning then
    M.layerTransitionTimer = M.layerTransitionTimer - dt
    if M.layerTransitionTimer <= 0 then
      M.currentLayer = M.targetLayer
      M.layerTransitioning = false
    end
  end

  -- Update components (scroll them down)
  for i = #M.components, 1, -1 do
    local comp = M.components[i]
    comp.y = comp.y + M.scrollSpeed * dt
    comp.glowPhase = comp.glowPhase + dt * 3

    if comp.y > screen.HEIGHT + 100 then
      table.remove(M.components, i)
    end
  end

  -- Update traces
  for i = #M.traces, 1, -1 do
    local trace = M.traces[i]
    for _, p in ipairs(trace.points) do
      p.y = p.y + M.scrollSpeed * dt
    end
    if trace.points[1] and trace.points[1].y > screen.HEIGHT + 200 then
      table.remove(M.traces, i)
    end
  end

  -- Update vias
  M.viaPrompt = nil
  for i = #M.vias, 1, -1 do
    local via = M.vias[i]
    via.y = via.y + M.scrollSpeed * dt
    via.rotation = via.rotation + dt * 2
    via.pulse = via.pulse + dt * 4

    -- Check if player is over this via
    if via.active and not M.layerTransitioning then
      local dx = playerX - via.x
      local dy = playerY - via.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist < via.radius + 20 then
        M.viaPrompt = {via = via, timer = M.viaFlashTimer}
      end
    end

    if via.y > screen.HEIGHT + 100 then
      table.remove(M.vias, i)
    end
  end

  -- Update puzzles
  for _, puzzle in ipairs(M.puzzles) do
    puzzle.y = puzzle.y + M.scrollSpeed * dt
    puzzle.timer = puzzle.timer + dt

    if puzzle.timer > 5 and not puzzle.hintShown then
      puzzle.hintShown = true
      M.puzzleHintTimer = 4
    end
  end

  -- Update puzzle gates
  for _, gate in ipairs(M.puzzleGates) do
    gate.y = gate.y + M.scrollSpeed * dt
    gate.electricArc = gate.electricArc + dt * 8

    if gate.open then
      gate.openTimer = gate.openTimer + dt
    end
  end

  -- Update hazards (electrical arcs)
  for i = #M.hazards, 1, -1 do
    local hz = M.hazards[i]
    hz.y = hz.y + M.scrollSpeed * dt
    hz.timer = hz.timer - dt
    hz.arcPhase = hz.arcPhase + dt * 12

    if hz.timer <= 0 or hz.y > screen.HEIGHT + 100 then
      table.remove(M.hazards, i)
    end
  end

  -- Update designators
  for _, des in ipairs(M.designators) do
    des.y = des.y + M.scrollSpeed * dt
  end

  -- Update trace particles (lightcycle trails)
  for i = #M.traceParticles, 1, -1 do
    local tp = M.traceParticles[i]
    tp.x = tp.x + tp.vx * dt
    tp.y = tp.y + tp.vy * dt + M.scrollSpeed * dt
    tp.life = tp.life - dt
    if tp.life <= 0 then
      table.remove(M.traceParticles, i)
    end
  end

  -- Update puzzle hint timer
  if M.puzzleHintTimer > 0 then
    M.puzzleHintTimer = M.puzzleHintTimer - dt
  end

  -- Spawn new content as we scroll
  M.spawnNewContent()

  -- Spawn electrical hazards periodically
  if math.random() < dt * 0.3 then
    M.spawnHazard()
  end

  -- Spawn trace particles along powered traces
  M.spawnTraceParticles(dt)

  -- Check if we've scrolled enough to reach the CPU (after all puzzles solved)
  if M.puzzleSolvedCount >= M.puzzleRequired and not M.bossReached then
    M.cpuApproachTimer = M.cpuApproachTimer + dt
    if M.cpuApproachTimer > 5 then
      M.bossReached = true
      M.scrollSpeed = 0  -- Stop scrolling for boss fight
    end
  end
end

function M.spawnNewContent()
  -- Keep components flowing
  local lowestY = 0
  for _, comp in ipairs(M.components) do
    if comp.y < lowestY then lowestY = comp.y end
  end
  if lowestY > -screen.HEIGHT then
    M.spawnComponentRow(lowestY - 300)
  end

  -- Keep traces flowing
  local lowestTrace = 0
  for _, trace in ipairs(M.traces) do
    for _, p in ipairs(trace.points) do
      if p.y < lowestTrace then lowestTrace = p.y end
    end
  end
  if lowestTrace > -screen.HEIGHT then
    M.spawnTrace(lowestTrace - 200)
  end

  -- Spawn vias every ~600 scroll units
  local lowestVia = 0
  for _, via in ipairs(M.vias) do
    if via.y < lowestVia then lowestVia = via.y end
  end
  if lowestVia > -400 then
    local fromL = M.currentLayer
    local toL = ((M.currentLayer) % M.layerCount) + 1
    M.spawnVia(
      math.random(100, screen.WIDTH - 100),
      lowestVia - 500 - math.random(0, 200),
      fromL, toL
    )
  end

  -- Spawn puzzles if needed
  if M.puzzleSolvedCount < M.puzzleRequired then
    local activePuzzles = 0
    for _, p in ipairs(M.puzzles) do
      if not p.solved and p.y < screen.HEIGHT then
        activePuzzles = activePuzzles + 1
      end
    end
    if activePuzzles == 0 then
      local lowestPuzzle = 0
      for _, p in ipairs(M.puzzles) do
        if p.y < lowestPuzzle then lowestPuzzle = p.y end
      end
      M.spawnPuzzle(lowestPuzzle - 400)
    end
  end
end

function M.spawnHazard()
  table.insert(M.hazards, {
    x = math.random(80, screen.WIDTH - 80),
    y = -50,
    width = math.random(60, 150),
    height = 8,
    timer = 3 + math.random() * 2,
    arcPhase = 0,
    damage = 8,
    layer = M.currentLayer,
  })
end

function M.spawnTraceParticles(dt)
  for _, trace in ipairs(M.traces) do
    if trace.powered and trace.layer == M.currentLayer and math.random() < dt * 2 then
      local segIdx = math.random(1, math.max(1, #trace.points - 1))
      local p1 = trace.points[segIdx]
      local p2 = trace.points[math.min(segIdx + 1, #trace.points)]
      if p1 and p2 then
        local t = math.random()
        local palette = M.LAYER_PALETTES[M.currentLayer]
        table.insert(M.traceParticles, {
          x = p1.x + (p2.x - p1.x) * t,
          y = p1.y + (p2.y - p1.y) * t,
          vx = (math.random() - 0.5) * 30,
          vy = -20 - math.random() * 20,
          life = 0.5 + math.random() * 0.5,
          color = palette.trace,
          size = 1 + math.random() * 2,
        })
      end
    end
  end
end

-- =============================================
-- PLAYER INTERACTION
-- =============================================

-- Called when player presses the via transition key (V key)
function M.tryViaTransition()
  if not M.raidActive or M.layerTransitioning then return false end
  if not M.viaPrompt then return false end

  local via = M.viaPrompt.via
  M.targetLayer = (via.fromLayer == M.currentLayer) and via.toLayer or via.fromLayer
  M.layerTransitioning = true
  M.layerTransitionTimer = M.layerTransitionDuration
  via.active = false

  -- Spawn dramatic transition particles
  for i = 1, 30 do
    local palette = M.LAYER_PALETTES[M.targetLayer]
    table.insert(M.traceParticles, {
      x = via.x + (math.random() - 0.5) * 40,
      y = via.y + (math.random() - 0.5) * 40,
      vx = (math.random() - 0.5) * 200,
      vy = (math.random() - 0.5) * 200,
      life = 0.8 + math.random() * 0.5,
      color = palette.trace,
      size = 2 + math.random() * 3,
    })
  end

  return true
end

-- Toggle puzzle input when shot hits an input node
function M.hitPuzzleInput(puzzleIdx, inputIdx)
  local puzzle = M.puzzles[puzzleIdx]
  if not puzzle or puzzle.solved then return end

  local input = puzzle.inputs[inputIdx]
  if not input then return end

  input.state = not input.state
  puzzle.inputHighlight = 0.3

  -- Check if puzzle is solved
  if M.checkPuzzleSolution(puzzle) then
    puzzle.solved = true
    M.puzzleSolvedCount = M.puzzleSolvedCount + 1

    -- Open corresponding gate
    for _, gate in ipairs(M.puzzleGates) do
      if gate.puzzleIndex == puzzleIdx then
        gate.open = true
      end
    end
  end
end

function M.checkPuzzleSolution(puzzle)
  if puzzle.type == "and" then
    return puzzle.inputs[1].state and puzzle.inputs[2].state
  elseif puzzle.type == "or" then
    return puzzle.inputs[1].state or puzzle.inputs[2].state
  elseif puzzle.type == "xor" then
    return (puzzle.inputs[1].state ~= puzzle.inputs[2].state)
  elseif puzzle.type == "nand" then
    return not (puzzle.inputs[1].state and puzzle.inputs[2].state)
  elseif puzzle.type == "sequence" then
    local val = 0
    for i, inp in ipairs(puzzle.inputs) do
      if inp.state then val = val + 2^(4 - i) end
    end
    return val == puzzle.targetBinary
  elseif puzzle.type == "resistor_code" then
    return puzzle.inputs[1].state and not puzzle.inputs[2].state
  end
  return false
end

-- Check player collision with components on current layer
function M.checkComponentCollision(playerX, playerY, playerRadius)
  if not M.raidActive then return 0 end

  local totalDamage = 0
  for _, comp in ipairs(M.components) do
    if not comp.destroyed and comp.layer == M.currentLayer then
      local dx = playerX - comp.x
      local dy = playerY - comp.y
      if math.abs(dx) < (comp.width/2 + playerRadius) and
         math.abs(dy) < (comp.height/2 + playerRadius) then
        totalDamage = totalDamage + 5
      end
    end
  end

  return totalDamage
end

-- Check player collision with hazards
function M.checkHazardCollision(playerX, playerY, playerRadius)
  if not M.raidActive then return 0 end

  local totalDamage = 0
  for _, hz in ipairs(M.hazards) do
    if hz.layer == M.currentLayer then
      local dx = playerX - hz.x
      local dy = playerY - hz.y
      if math.abs(dx) < (hz.width/2 + playerRadius) and
         math.abs(dy) < (hz.height/2 + playerRadius) then
        totalDamage = totalDamage + hz.damage
      end
    end
  end

  return totalDamage
end

-- Check player collision with closed puzzle gates
function M.checkGateCollision(playerX, playerY, playerRadius)
  if not M.raidActive then return false end

  for _, gate in ipairs(M.puzzleGates) do
    if not gate.open then
      local dx = playerX - gate.x
      local dy = playerY - gate.y
      if math.abs(dx) < (gate.width/2 + playerRadius) and
         math.abs(dy) < (gate.height/2 + playerRadius) then
        return true
      end
    end
  end
  return false
end

-- Check if a laser hits a puzzle input node
function M.checkLaserPuzzleHit(laserX, laserY)
  for pi, puzzle in ipairs(M.puzzles) do
    if not puzzle.solved then
      for ii, input in ipairs(puzzle.inputs) do
        local ix = puzzle.x + input.x
        local iy = puzzle.y + input.y
        local dist = math.sqrt((laserX - ix)^2 + (laserY - iy)^2)
        if dist < 18 then
          M.hitPuzzleInput(pi, ii)
          return true
        end
      end
    end
  end
  return false
end

-- Check if a laser hits a component (destroyable)
function M.checkLaserComponentHit(laserX, laserY, damage)
  for _, comp in ipairs(M.components) do
    if not comp.destroyed and comp.layer == M.currentLayer then
      if math.abs(laserX - comp.x) < comp.width/2 and
         math.abs(laserY - comp.y) < comp.height/2 then
        comp.health = comp.health - damage
        if comp.health <= 0 then
          comp.destroyed = true
        end
        return true, comp.destroyed
      end
    end
  end
  return false, false
end

-- Get current layer palette
function M.getPalette()
  return M.LAYER_PALETTES[M.currentLayer]
end

-- Get transition progress (0 = no transition, 0-1 = transitioning)
function M.getTransitionProgress()
  if not M.layerTransitioning then return 0 end
  return 1 - (M.layerTransitionTimer / M.layerTransitionDuration)
end

-- =============================================
-- DRAWING
-- =============================================

function M.drawBackground()
  if not M.raidActive then return end

  local palette = M.LAYER_PALETTES[M.currentLayer]
  local bg = palette.bg

  -- Background
  love.graphics.setBackgroundColor(bg[1], bg[2], bg[3])

  -- Draw PCB grid (subtle)
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.04)
  local gridSize = 40
  for x = 0, screen.WIDTH, gridSize do
    love.graphics.line(x, 0, x, screen.HEIGHT)
  end
  for y = 0, screen.HEIGHT, gridSize do
    love.graphics.line(0, y, screen.WIDTH, y)
  end

  -- Draw solder mask texture (subtle dots)
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.02)
  local seed = math.floor(M.scrollY / 100)
  for i = 1, 50 do
    local sx = ((i * 137 + seed * 43) % screen.WIDTH)
    local sy = ((i * 211 + seed * 67) % screen.HEIGHT)
    love.graphics.circle("fill", sx, sy, 1)
  end
end

function M.drawTraces()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()

  for _, trace in ipairs(M.traces) do
    if trace.layer == M.currentLayer then
      local alpha = trace.powered and 0.6 or 0.2

      -- Trace glow
      if trace.powered then
        love.graphics.setColor(palette.glow[1], palette.glow[2], palette.glow[3], 0.15 + math.sin(time * 2 + trace.pulseOffset) * 0.1)
        love.graphics.setLineWidth(trace.width + 4)
        for i = 1, #trace.points - 1 do
          local p1 = trace.points[i]
          local p2 = trace.points[i + 1]
          love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
      end

      -- Trace itself
      love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], alpha)
      love.graphics.setLineWidth(trace.width)
      for i = 1, #trace.points - 1 do
        local p1 = trace.points[i]
        local p2 = trace.points[i + 1]
        love.graphics.line(p1.x, p1.y, p2.x, p2.y)
      end
    elseif trace.layer ~= M.currentLayer then
      -- Ghost traces from other layers (very faint)
      love.graphics.setColor(0.3, 0.3, 0.3, 0.05)
      love.graphics.setLineWidth(1)
      for i = 1, #trace.points - 1 do
        local p1 = trace.points[i]
        local p2 = trace.points[i + 1]
        love.graphics.line(p1.x, p1.y, p2.x, p2.y)
      end
    end
  end

  love.graphics.setLineWidth(1)
end

function M.drawComponents()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()

  for _, comp in ipairs(M.components) do
    if comp.destroyed then goto continue end

    local onLayer = comp.layer == M.currentLayer
    local alpha = onLayer and 1 or 0.1

    love.graphics.push()
    love.graphics.translate(comp.x, comp.y)

    if comp.type == "resistor" then
      -- Resistor body (rectangular with color bands)
      love.graphics.setColor(0.15 * alpha, 0.12 * alpha, 0.1 * alpha, alpha)
      love.graphics.rectangle("fill", -comp.width/2, -comp.height/2, comp.width, comp.height)

      -- Lead wires
      love.graphics.setColor(palette.trace[1] * alpha, palette.trace[2] * alpha, palette.trace[3] * alpha, alpha * 0.8)
      love.graphics.line(-comp.width/2 - 10, 0, -comp.width/2, 0)
      love.graphics.line(comp.width/2, 0, comp.width/2 + 10, 0)

      -- Color bands
      local bands = {{1, 0, 0}, {0.5, 0, 1}, {0, 0.6, 0}, {1, 0.8, 0}}
      for i, band in ipairs(bands) do
        local bx = -comp.width/2 + 6 + (i - 1) * 8
        love.graphics.setColor(band[1] * alpha, band[2] * alpha, band[3] * alpha, alpha)
        love.graphics.rectangle("fill", bx, -comp.height/2 + 1, 4, comp.height - 2)
      end

      -- Neon outline (Tron style)
      if onLayer then
        local glow = 0.3 + math.sin(comp.glowPhase) * 0.2
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow)
        love.graphics.rectangle("line", -comp.width/2, -comp.height/2, comp.width, comp.height)
      end

    elseif comp.type == "capacitor" then
      -- Electrolytic capacitor (cylindrical, drawn as rectangle + circle top)
      love.graphics.setColor(0.05 * alpha, 0.05 * alpha, 0.12 * alpha, alpha)
      love.graphics.rectangle("fill", -comp.width/2, -comp.height/2, comp.width, comp.height)

      -- Capacitor marking
      love.graphics.setColor(palette.trace[1] * alpha, palette.trace[2] * alpha, palette.trace[3] * alpha, alpha * 0.5)
      love.graphics.line(-comp.width/2 + 3, -comp.height/2 + 3, -comp.width/2 + 3, comp.height/2 - 3)

      -- Neon glow
      if onLayer then
        local glow = 0.3 + math.sin(comp.glowPhase + 1) * 0.2
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow)
        love.graphics.rectangle("line", -comp.width/2, -comp.height/2, comp.width, comp.height)
      end

    elseif comp.type == "ic" then
      -- Integrated circuit (large rectangular with pins)
      love.graphics.setColor(0.05 * alpha, 0.05 * alpha, 0.05 * alpha, alpha)
      love.graphics.rectangle("fill", -comp.width/2, -comp.height/2, comp.width, comp.height)

      -- IC notch
      love.graphics.setColor(0.15 * alpha, 0.15 * alpha, 0.15 * alpha, alpha)
      love.graphics.arc("fill", -comp.width/2, 0, 6, -math.pi/2, math.pi/2)

      -- Pin rows
      love.graphics.setColor(palette.trace[1] * alpha, palette.trace[2] * alpha, palette.trace[3] * alpha, alpha * 0.6)
      for i = 0, 5 do
        local px = -comp.width/2 + 8 + i * 12
        love.graphics.rectangle("fill", px, -comp.height/2 - 6, 3, 6)
        love.graphics.rectangle("fill", px, comp.height/2, 3, 6)
      end

      -- IC label (Tron grid text effect)
      if onLayer then
        local glow = 0.4 + math.sin(comp.glowPhase + 2) * 0.3
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow)
        love.graphics.rectangle("line", -comp.width/2, -comp.height/2, comp.width, comp.height)

        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow * 0.7)
        love.graphics.setFont(love.graphics.newFont(8))
        love.graphics.printf(comp.designator, -comp.width/2 + 2, -6, comp.width - 4, "center")
      end

    elseif comp.type == "diode" then
      -- Diode (triangle + bar)
      love.graphics.setColor(0.1 * alpha, 0.1 * alpha, 0.1 * alpha, alpha)
      love.graphics.polygon("fill",
        -comp.width/2, -comp.height/2,
        comp.width/2, 0,
        -comp.width/2, comp.height/2)

      -- Cathode bar
      love.graphics.setColor(palette.trace[1] * alpha, palette.trace[2] * alpha, palette.trace[3] * alpha, alpha * 0.6)
      love.graphics.rectangle("fill", comp.width/2, -comp.height/2, 3, comp.height)

      if onLayer then
        local glow = 0.3 + math.sin(comp.glowPhase) * 0.2
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow)
        love.graphics.polygon("line",
          -comp.width/2, -comp.height/2,
          comp.width/2, 0,
          -comp.width/2, comp.height/2)
      end

    else
      -- Generic component
      love.graphics.setColor(0.08 * alpha, 0.08 * alpha, 0.08 * alpha, alpha)
      love.graphics.rectangle("fill", -comp.width/2, -comp.height/2, comp.width, comp.height)

      if onLayer then
        local glow = 0.2 + math.sin(comp.glowPhase) * 0.15
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], glow)
        love.graphics.rectangle("line", -comp.width/2, -comp.height/2, comp.width, comp.height)
      end
    end

    love.graphics.pop()
    ::continue::
  end
end

function M.drawVias()
  if not M.raidActive then return end
  local time = love.timer.getTime()

  for _, via in ipairs(M.vias) do
    local fromPalette = M.LAYER_PALETTES[via.fromLayer]
    local toPalette = M.LAYER_PALETTES[via.toLayer]
    local pulse = 0.5 + math.sin(via.pulse) * 0.3

    -- Outer ring (from-layer color)
    love.graphics.setColor(fromPalette.trace[1], fromPalette.trace[2], fromPalette.trace[3], pulse * 0.5)
    love.graphics.circle("fill", via.x, via.y, via.radius + 5)

    -- Via pad (annular ring)
    love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
    love.graphics.circle("fill", via.x, via.y, via.radius)

    -- Inner drill hole
    love.graphics.setColor(toPalette.trace[1], toPalette.trace[2], toPalette.trace[3], pulse)
    love.graphics.circle("fill", via.x, via.y, via.innerRadius)

    -- Core glow
    love.graphics.setColor(1, 1, 1, pulse * 0.4)
    love.graphics.circle("fill", via.x, via.y, 5)

    -- Rotating cross (drill alignment)
    love.graphics.setColor(fromPalette.trace[1], fromPalette.trace[2], fromPalette.trace[3], pulse * 0.6)
    love.graphics.setLineWidth(2)
    for i = 0, 3 do
      local angle = via.rotation + i * (math.pi / 2)
      local x1 = via.x + math.cos(angle) * via.innerRadius
      local y1 = via.y + math.sin(angle) * via.innerRadius
      local x2 = via.x + math.cos(angle) * via.radius
      local y2 = via.y + math.sin(angle) * via.radius
      love.graphics.line(x1, y1, x2, y2)
    end
    love.graphics.setLineWidth(1)

    -- Layer labels
    if via.active then
      love.graphics.setColor(1, 1, 1, 0.5)
      love.graphics.setFont(love.graphics.newFont(8))
      love.graphics.printf("L" .. via.fromLayer .. "→L" .. via.toLayer, via.x - 30, via.y - via.radius - 14, 60, "center")
    end
  end
end

function M.drawPuzzles()
  if not M.raidActive then return end
  local time = love.timer.getTime()
  local palette = M.LAYER_PALETTES[M.currentLayer]

  for pi, puzzle in ipairs(M.puzzles) do
    if puzzle.y < -200 or puzzle.y > screen.HEIGHT + 200 then goto continue end

    love.graphics.push()
    love.graphics.translate(puzzle.x, puzzle.y)

    -- Gate box background
    local solved = puzzle.solved
    local bgAlpha = solved and 0.1 or 0.3
    love.graphics.setColor(0.05, 0.05, 0.08, bgAlpha)
    love.graphics.rectangle("fill", -puzzle.gateWidth/2, -puzzle.gateHeight/2, puzzle.gateWidth, puzzle.gateHeight)

    -- Gate border
    local borderColor = solved and {0, 1, 0.5} or palette.trace
    local borderPulse = 0.5 + math.sin(time * 3) * 0.3
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderPulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -puzzle.gateWidth/2, -puzzle.gateHeight/2, puzzle.gateWidth, puzzle.gateHeight)

    -- Gate type label
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(love.graphics.newFont(14))
    local gateLabel = string.upper(puzzle.type) .. " GATE"
    if puzzle.type == "sequence" then gateLabel = "BINARY DECODER" end
    if puzzle.type == "resistor_code" then gateLabel = "RESISTANCE ID" end
    love.graphics.printf(gateLabel, -puzzle.gateWidth/2, -puzzle.gateHeight/2 - 22, puzzle.gateWidth, "center")

    -- Draw logic gate symbol
    M.drawGateSymbol(puzzle, palette)

    -- Draw input nodes
    for ii, input in ipairs(puzzle.inputs) do
      local nodeColor = input.state and {0, 1, 0.5} or {1, 0.2, 0.2}
      local nodePulse = 0.6 + math.sin(time * 4 + ii) * 0.3

      -- Input glow
      love.graphics.setColor(nodeColor[1], nodeColor[2], nodeColor[3], nodePulse * 0.3)
      love.graphics.circle("fill", input.x, input.y, 15)

      -- Input circle
      love.graphics.setColor(nodeColor[1], nodeColor[2], nodeColor[3], nodePulse)
      love.graphics.circle("fill", input.x, input.y, 10)

      -- State label
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf(input.label .. ":" .. (input.state and "1" or "0"),
        input.x - 25, input.y - 5, 50, "center")
    end

    -- Output indicator
    local outputX = 70
    local outputY = 0
    local outputState = M.checkPuzzleSolution(puzzle)
    local outColor = outputState and {0, 1, 0.5} or {0.4, 0.4, 0.4}
    love.graphics.setColor(outColor[1], outColor[2], outColor[3], 0.8)
    love.graphics.circle("fill", outputX, outputY, 8)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.printf(outputState and "1" or "0", outputX - 10, outputY - 5, 20, "center")

    -- Solved indicator
    if solved then
      love.graphics.setColor(0, 1, 0.5, 0.5 + math.sin(time * 5) * 0.3)
      love.graphics.setFont(love.graphics.newFont(20))
      love.graphics.printf("✓ SOLVED", -puzzle.gateWidth/2, puzzle.gateHeight/2 + 5, puzzle.gateWidth, "center")
    end

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    ::continue::
  end

  -- Draw puzzle hint
  if M.puzzleHintTimer > 0 then
    for _, puzzle in ipairs(M.puzzles) do
      if puzzle.hintShown and not puzzle.solved then
        local hintAlpha = math.min(1, M.puzzleHintTimer)
        love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], hintAlpha * 0.8)
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.printf(puzzle.hint, 0, screen.HEIGHT - 60, screen.WIDTH, "center")
        break
      end
    end
  end
end

function M.drawGateSymbol(puzzle, palette)
  -- Draw simplified logic gate schematic
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.5)
  love.graphics.setLineWidth(2)

  if puzzle.type == "and" then
    -- AND gate shape
    love.graphics.rectangle("line", -20, -25, 30, 50)
    love.graphics.arc("line", "open", 10, 0, 25, -math.pi/2, math.pi/2)
  elseif puzzle.type == "or" then
    -- OR gate curved shape
    love.graphics.arc("line", "open", -30, 0, 35, -math.pi/4, math.pi/4)
    love.graphics.arc("line", "open", 10, 0, 25, -math.pi/2, math.pi/2)
  elseif puzzle.type == "xor" then
    -- XOR gate
    love.graphics.arc("line", "open", -30, 0, 35, -math.pi/4, math.pi/4)
    love.graphics.arc("line", "open", -35, 0, 35, -math.pi/4, math.pi/4)
    love.graphics.arc("line", "open", 10, 0, 25, -math.pi/2, math.pi/2)
  elseif puzzle.type == "nand" then
    -- NAND gate (AND + bubble)
    love.graphics.rectangle("line", -20, -25, 30, 50)
    love.graphics.arc("line", "open", 10, 0, 25, -math.pi/2, math.pi/2)
    love.graphics.circle("line", 38, 0, 5)
  end

  love.graphics.setLineWidth(1)
end

function M.drawHazards()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()

  for _, hz in ipairs(M.hazards) do
    if hz.layer ~= M.currentLayer then goto continue end

    -- Electrical arc (zigzag line)
    local arcAlpha = 0.5 + math.sin(hz.arcPhase) * 0.3
    love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], arcAlpha)
    love.graphics.setLineWidth(2)

    local segments = 8
    local prevX, prevY = hz.x - hz.width/2, hz.y
    for i = 1, segments do
      local t = i / segments
      local nx = hz.x - hz.width/2 + hz.width * t
      local ny = hz.y + math.sin(hz.arcPhase + i * 2.3) * 15
      love.graphics.line(prevX, prevY, nx, ny)
      prevX, prevY = nx, ny
    end

    -- Spark at ends
    love.graphics.setColor(1, 1, 1, arcAlpha * 0.8)
    love.graphics.circle("fill", hz.x - hz.width/2, hz.y, 3)
    love.graphics.circle("fill", hz.x + hz.width/2, hz.y, 3)

    love.graphics.setLineWidth(1)
    ::continue::
  end
end

function M.drawPuzzleGates()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()

  for _, gate in ipairs(M.puzzleGates) do
    if gate.y < -100 or gate.y > screen.HEIGHT + 100 then goto continue end

    if gate.open then
      -- Opening animation
      if gate.openTimer < 1 then
        local openProgress = gate.openTimer
        local halfW = gate.width / 2 * (1 - openProgress)
        love.graphics.setColor(0, 1, 0.5, 0.3 * (1 - openProgress))
        love.graphics.rectangle("fill", gate.x - gate.width/2, gate.y - gate.height/2, halfW, gate.height)
        love.graphics.rectangle("fill", gate.x + gate.width/2 - halfW, gate.y - gate.height/2, halfW, gate.height)
      end
    else
      -- Solid barrier with electric arcs
      love.graphics.setColor(0.1, 0.02, 0.02, 0.8)
      love.graphics.rectangle("fill", gate.x - gate.width/2, gate.y - gate.height/2, gate.width, gate.height)

      -- Electric arc across the gate
      local arcPulse = 0.4 + math.sin(gate.electricArc) * 0.4
      love.graphics.setColor(1, 0.2, 0.1, arcPulse)
      love.graphics.setLineWidth(2)
      local numArcs = 6
      for i = 0, numArcs do
        local t = i / numArcs
        local ax = gate.x - gate.width/2 + gate.width * t
        local ay = gate.y + math.sin(gate.electricArc * 3 + i * 1.7) * 8
        if i > 0 then
          local prevT = (i - 1) / numArcs
          local prevAx = gate.x - gate.width/2 + gate.width * prevT
          local prevAy = gate.y + math.sin(gate.electricArc * 3 + (i-1) * 1.7) * 8
          love.graphics.line(prevAx, prevAy, ax, ay)
        end
      end
      love.graphics.setLineWidth(1)

      -- Warning text
      love.graphics.setColor(1, 0.3, 0.1, 0.6 + math.sin(time * 4) * 0.3)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf("LOGIC GATE LOCKED", gate.x - 80, gate.y - 6, 160, "center")
    end

    ::continue::
  end
end

function M.drawDesignators()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]

  love.graphics.setFont(love.graphics.newFont(9))
  for _, des in ipairs(M.designators) do
    if des.y > -50 and des.y < screen.HEIGHT + 50 then
      local alpha = des.layer == M.currentLayer and des.alpha or des.alpha * 0.15
      love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], alpha)
      love.graphics.print(des.text, des.x, des.y)
    end
  end
end

function M.drawTraceParticles()
  if not M.raidActive then return end

  for _, tp in ipairs(M.traceParticles) do
    local alpha = tp.life
    love.graphics.setColor(tp.color[1], tp.color[2], tp.color[3], alpha)
    love.graphics.circle("fill", tp.x, tp.y, tp.size)
  end
end

function M.drawViaPrompt()
  if not M.viaPrompt then return end
  local via = M.viaPrompt.via
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()
  local pulse = 0.5 + math.sin(time * 6) * 0.4

  -- Draw prompt
  love.graphics.setColor(1, 1, 1, pulse)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf("[V] ENTER VIA → " .. M.LAYER_PALETTES[via.toLayer].name,
    via.x - 120, via.y - via.radius - 35, 240, "center")

  -- Highlight ring
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], pulse * 0.6)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", via.x, via.y, via.radius + 10)
  love.graphics.setLineWidth(1)
end

function M.drawLayerTransition()
  if not M.layerTransitioning then return end

  local progress = M.getTransitionProgress()
  local targetPalette = M.LAYER_PALETTES[M.targetLayer]

  -- Full-screen flash + scan line effect
  local flashAlpha = math.sin(progress * math.pi) * 0.8
  love.graphics.setColor(targetPalette.trace[1], targetPalette.trace[2], targetPalette.trace[3], flashAlpha)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Horizontal scan lines (CRT/Tron effect)
  love.graphics.setColor(0, 0, 0, flashAlpha * 0.5)
  for y = 0, screen.HEIGHT, 4 do
    love.graphics.line(0, y, screen.WIDTH, y)
  end

  -- Layer name display
  love.graphics.setColor(1, 1, 1, flashAlpha)
  love.graphics.setFont(love.graphics.newFont(24))
  love.graphics.printf("TRANSITIONING TO " .. targetPalette.name,
    0, screen.HEIGHT / 2 - 20, screen.WIDTH, "center")
end

function M.drawHUD()
  if not M.raidActive then return end
  local palette = M.LAYER_PALETTES[M.currentLayer]
  local time = love.timer.getTime()

  -- Layer indicator (top-right)
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.8)
  love.graphics.setFont(love.graphics.newFont(12))
  love.graphics.printf("LAYER: " .. palette.name, screen.WIDTH - 250, 55, 240, "right")

  -- Layer diagram (mini stack)
  for i = 1, M.layerCount do
    local ly = 75 + (i - 1) * 12
    local lp = M.LAYER_PALETTES[i]
    local isActive = i == M.currentLayer
    love.graphics.setColor(lp.trace[1], lp.trace[2], lp.trace[3], isActive and 0.9 or 0.2)
    love.graphics.rectangle("fill", screen.WIDTH - 60, ly, 50, 8)
    if isActive then
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.print("►", screen.WIDTH - 75, ly - 2)
    end
  end

  -- Puzzle progress
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.7)
  love.graphics.setFont(love.graphics.newFont(11))
  love.graphics.printf("PUZZLES: " .. M.puzzleSolvedCount .. "/" .. M.puzzleRequired,
    screen.WIDTH - 250, 130, 240, "right")

  -- Puzzle progress pips
  for i = 1, M.puzzleRequired do
    local pipX = screen.WIDTH - 60 + (i - 1) * 14
    local pipY = 148
    if i <= M.puzzleSolvedCount then
      love.graphics.setColor(0, 1, 0.5, 0.9)
    else
      love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    end
    love.graphics.rectangle("fill", pipX, pipY, 10, 10)
  end

  -- Raid title
  love.graphics.setColor(palette.trace[1], palette.trace[2], palette.trace[3], 0.3 + math.sin(time * 0.5) * 0.1)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("LOGICIAN'S LAMENT", 0, screen.HEIGHT - 25, screen.WIDTH, "center")

  -- CPU approach indicator
  if M.puzzleSolvedCount >= M.puzzleRequired and not M.bossReached then
    local approachPulse = 0.5 + math.sin(time * 3) * 0.5
    love.graphics.setColor(1, 0.3, 0.1, approachPulse)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("APPROACHING CPU DIE...", 0, screen.HEIGHT / 2 - 100, screen.WIDTH, "center")
  end
end

-- Draw everything in correct order
function M.draw()
  if not M.raidActive then return end

  M.drawBackground()
  M.drawTraces()
  M.drawDesignators()
  M.drawComponents()
  M.drawHazards()
  M.drawPuzzleGates()
  M.drawPuzzles()
  M.drawVias()
  M.drawTraceParticles()
  M.drawViaPrompt()
  M.drawLayerTransition()
  M.drawHUD()
end

return M
