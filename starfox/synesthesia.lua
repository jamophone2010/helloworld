-- ============================================================================
-- SYNESTHESIA INSTALLATION
-- ============================================================================
-- An endgame raid where the player flies through the fins and circuit board
-- of a massive graphics card toward the GPU core. The background is a
-- music-reactive visualizer. The boss is a 10-phase Elden Ring-style
-- encounter with Indiana Jones obstacles and puzzle mechanics.
-- ============================================================================

local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- ============================================================================
-- DAMAGE TABLE (Elden Ring: every mistake is costly)
-- ============================================================================
local DAMAGE = {
  -- Terrain / Obstacles (Indiana Jones)
  heatsinkFin       = 20,   -- Colliding with heatsink fin walls
  capacitorBoulder  = 30,   -- Rolling capacitor crushes you
  laserGrid         = 15,   -- Laser security grid per hit
  pcbCollapse       = 25,   -- Falling into collapsed PCB bridge
  arcDischarge      = 18,   -- Electrical arc from circuit trace
  vrm_explosion     = 35,   -- VRM thermal explosion (timed dodge)

  -- Boss attacks
  shaderStorm       = 12,   -- Phase 1: Compiled shader fragments
  pipelineLance     = 16,   -- Phase 2: Render pipeline lance
  rasterSweep       = 10,   -- Phase 3: Rasterizer sweep beam per tick
  tensorSlam        = 22,   -- Phase 4: Tensor core gravity slam
  raytraceBeam      = 28,   -- Phase 5: Ray-traced reflection beam
  bufferOverflow    = 14,   -- Phase 6: Frame buffer flood projectiles
  clockPulse        = 8,    -- Phase 7: Overclock pulse DOT per tick
  kernelPanic       = 40,   -- Phase 8: Kernel panic near-lethal
  thermalMeltdown   = 18,   -- Phase 9: Thermal throttle fire waves
  gpuAscension      = 25,   -- Phase 10: Transcendent combo attacks
}

-- Phase HP thresholds (out of 500 total)
local PHASE_THRESHOLDS = {500, 460, 410, 350, 290, 230, 170, 120, 70, 30}

-- ============================================================================
-- TERRAIN: GRAPHICS CARD ENVIRONMENT
-- ============================================================================

-- Heatsink fins the player must navigate between
M.heatsinkFins = {}
M.finSpawnTimer = 0
M.finScrollSpeed = 120

-- Circuit board traces that arc with electricity
M.circuitTraces = {}
M.traceArcTimer = 0

-- Rolling capacitor boulders (Indiana Jones)
M.capacitorBoulders = {}
M.boulderSpawnTimer = 0

-- Laser security grids (must find gap or barrel-roll through)
M.laserGrids = {}
M.laserGridTimer = 0

-- Collapsing PCB bridge sections
M.pcbBridges = {}

-- VRM thermal explosions (timed area denial)
M.vrmExplosions = {}
M.vrmTimer = 0

-- ============================================================================
-- PUZZLE SYSTEM
-- ============================================================================

-- Active puzzle state
M.puzzleActive = false
M.puzzleType = nil
M.puzzleSolved = false
M.puzzleTimer = 0
M.puzzleData = nil

-- Puzzle types:
-- 1. "trace_route"   - Shoot colored nodes in correct order to open path
-- 2. "frequency"     - Match ship position to oscillating frequency pattern
-- 3. "color_decode"  - Shoot targets matching the background color pulse
-- 4. "memory_bus"    - Remember and replay a pattern sequence

-- ============================================================================
-- MUSIC VISUALIZATION BACKGROUND
-- ============================================================================

M.vizBars = {}        -- Frequency spectrum bars
M.vizPulse = 0        -- Global pulse intensity
M.vizHue = 0          -- Rotating hue for chromatic effects
M.vizBeatTimer = 0    -- Simulated beat tracker
M.vizBeatInterval = 0.5  -- BPM-derived interval
M.vizWaveforms = {}   -- Oscilloscope waveform points
M.vizIntensity = 0.5  -- Overall visual intensity (ramps up in later phases)
M.vizGridLines = {}   -- Background grid that pulses with music
M.vizParticles = {}   -- Floating music note particles
M.vizBassHit = false  -- Flash on bass hits
M.vizBassDecay = 0    -- Decay timer for bass flash

-- ============================================================================
-- RAID SECTION PROGRESSION
-- ============================================================================

-- The raid has 3 sections before the boss:
-- Section 1: Heatsink Canyon (navigate fins, dodge arcs)
-- Section 2: PCB Gauntlet (boulders, laser grids, puzzles)
-- Section 3: VRM Corridor (thermal explosions, final puzzle)
-- Section 4: GPU Core (boss fight, 10 phases)

M.raidSection = 0  -- 0 = not started, 1-3 = terrain, 4 = boss
M.sectionTimer = 0
M.raidActive = false

-- ============================================================================
-- RESET
-- ============================================================================
function M.reset()
  M.boss = nil
  M.heatsinkFins = {}
  M.finSpawnTimer = 0
  M.circuitTraces = {}
  M.traceArcTimer = 0
  M.capacitorBoulders = {}
  M.boulderSpawnTimer = 0
  M.laserGrids = {}
  M.laserGridTimer = 0
  M.pcbBridges = {}
  M.vrmExplosions = {}
  M.vrmTimer = 0

  M.puzzleActive = false
  M.puzzleType = nil
  M.puzzleSolved = false
  M.puzzleTimer = 0
  M.puzzleData = nil

  M.vizBars = {}
  M.vizPulse = 0
  M.vizHue = 0
  M.vizBeatTimer = 0
  M.vizWaveforms = {}
  M.vizIntensity = 0.5
  M.vizGridLines = {}
  M.vizParticles = {}
  M.vizBassHit = false
  M.vizBassDecay = 0

  M.raidSection = 0
  M.sectionTimer = 0
  M.raidActive = false

  -- Initialize visualization bars
  for i = 1, 32 do
    table.insert(M.vizBars, {
      height = 0,
      targetHeight = 0,
      hue = (i - 1) / 32,
      phase = math.random() * math.pi * 2
    })
  end

  -- Initialize grid lines
  for i = 1, 20 do
    table.insert(M.vizGridLines, {
      y = i * (screen.HEIGHT / 20),
      alpha = 0.1,
      pulse = math.random() * math.pi * 2
    })
  end
end

-- ============================================================================
-- SPAWN (called from wave system when type="synesthesiaboss")
-- ============================================================================
function M.spawn()
  M.raidActive = true
  M.raidSection = 1
  M.sectionTimer = 0
  M.vizIntensity = 0.4

  -- Boss is spawned later when section 4 begins
end

function M.spawnBoss()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -200,
    width = 200,
    height = 150,
    health = 500,
    maxHealth = 500,
    score = 25000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 90,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Shader Warp)
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 6,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 90,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack states
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Phase 1: Shader Storm - fragment shrapnel
    shaderFragments = {},

    -- Phase 2: Pipeline Lance - piercing beam combo
    lanceActive = false,
    lanceAngle = 0,
    lanceSweeps = 0,

    -- Phase 3: Rasterizer - scanning sweep beam
    rasterActive = false,
    rasterX = 0,
    rasterDirection = 1,
    rasterSpeed = 300,

    -- Phase 4: Tensor Core - gravity manipulation
    tensorActive = false,
    tensorTimer = 0,
    tensorCooldown = 10,
    tensorPullStrength = 0,
    tensorNodes = {},  -- Orbiting tensor core satellites

    -- Phase 5: Ray Trace - reflected beam that bounces off walls
    raytraceActive = false,
    raytraceBeams = {},
    raytraceCooldown = 8,

    -- Phase 6: Buffer Overflow - screen floods with projectiles
    bufferFloodActive = false,
    bufferFloodTimer = 0,
    bufferProjectiles = {},

    -- Phase 7: Overclock - DOT zones + speed increase
    overclockActive = false,
    overclockZones = {},
    overclockSpawnTimer = 0,
    overclockSpeedMult = 1.0,

    -- Phase 8: Kernel Panic - telegraphed near-lethal blast
    kernelPanicCharging = false,
    kernelPanicTimer = 0,
    kernelPanicDuration = 3.0,
    kernelPanicTargetX = 0,
    kernelPanicTargetY = 0,
    kernelPanicRadius = 0,

    -- Phase 9: Thermal Throttle - fire wave patterns
    thermalWaves = {},
    thermalWaveTimer = 0,

    -- Phase 10: GPU Ascension - all abilities combined, enraged
    ascended = false,
    ascensionMultiplier = 1.8,
    ascensionPulse = 0,

    -- Shield cores (must destroy to expose main body)
    leftShieldCore = {health = 40, x = -80, destroyed = false},
    rightShieldCore = {health = 40, x = 80, destroyed = false},
    shieldCoresDown = false,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0,
  }
end

-- ============================================================================
-- ACTIVE / DEFEATED CHECKS
-- ============================================================================
function M.isActive()
  return M.raidActive or (M.boss ~= nil and M.boss.active)
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

function M.isBossActive()
  return M.boss ~= nil and M.boss.active
end

-- ============================================================================
-- MAIN UPDATE
-- ============================================================================
function M.update(dt, playerX, playerY)
  M.updateVisualization(dt)

  if M.raidSection >= 1 and M.raidSection <= 3 then
    M.sectionTimer = M.sectionTimer + dt
    M.updateTerrain(dt, playerX, playerY)
    M.updatePuzzles(dt, playerX, playerY)

    -- Section progression timers
    if M.raidSection == 1 and M.sectionTimer > 25 then
      M.raidSection = 2
      M.sectionTimer = 0
      M.vizIntensity = 0.55
    elseif M.raidSection == 2 and M.sectionTimer > 30 then
      M.raidSection = 3
      M.sectionTimer = 0
      M.vizIntensity = 0.7
    elseif M.raidSection == 3 and M.sectionTimer > 20 then
      M.raidSection = 4
      M.sectionTimer = 0
      M.vizIntensity = 0.85
      M.spawnBoss()
    end
  end

  if M.boss then
    M.updateBoss(dt, playerX, playerY)
  end
end

-- ============================================================================
-- MUSIC VISUALIZATION UPDATE
-- ============================================================================
function M.updateVisualization(dt)
  M.vizHue = (M.vizHue + dt * 0.1) % 1.0
  M.vizBeatTimer = M.vizBeatTimer + dt

  -- Simulate beat detection (synth bass-like pulse)
  local bossPhase = M.boss and M.boss.phase or 1
  M.vizBeatInterval = math.max(0.25, 0.6 - (bossPhase * 0.03))

  if M.vizBeatTimer >= M.vizBeatInterval then
    M.vizBeatTimer = 0
    M.vizBassHit = true
    M.vizBassDecay = 0.3
    M.vizPulse = 1.0

    -- Spawn visualization particle burst on beat
    for i = 1, 3 do
      table.insert(M.vizParticles, {
        x = math.random(0, screen.WIDTH),
        y = math.random(0, screen.HEIGHT),
        vx = (math.random() - 0.5) * 60,
        vy = (math.random() - 0.5) * 60,
        life = 1.5,
        maxLife = 1.5,
        size = math.random(2, 6),
        hue = (M.vizHue + math.random() * 0.3) % 1.0
      })
    end
  end

  -- Decay bass hit
  if M.vizBassDecay > 0 then
    M.vizBassDecay = M.vizBassDecay - dt
    if M.vizBassDecay <= 0 then
      M.vizBassHit = false
    end
  end

  -- Pulse decay
  M.vizPulse = M.vizPulse * (1 - dt * 4)

  -- Update frequency bars (simulated spectrum analysis)
  local time = love.timer.getTime()
  for i, bar in ipairs(M.vizBars) do
    -- Generate target heights from overlapping sine waves (simulates music)
    local freq1 = math.sin(time * (1.5 + i * 0.4) + bar.phase) * 0.5 + 0.5
    local freq2 = math.sin(time * (0.7 + i * 0.2) + bar.phase * 1.3) * 0.3 + 0.3
    local freq3 = math.sin(time * (3.0 + i * 0.1)) * 0.2 + 0.2
    local bassBoost = i <= 8 and (M.vizPulse * 0.5) or 0

    bar.targetHeight = (freq1 + freq2 + freq3 + bassBoost) * M.vizIntensity * 120
    bar.height = bar.height + (bar.targetHeight - bar.height) * dt * 12
  end

  -- Update waveform (oscilloscope display)
  M.vizWaveforms = {}
  for i = 0, 60 do
    local t = i / 60
    local wave1 = math.sin(time * 3 + t * math.pi * 4) * 30 * M.vizIntensity
    local wave2 = math.sin(time * 5.5 + t * math.pi * 8) * 15 * M.vizIntensity
    local wave3 = math.sin(time * 1.2 + t * math.pi * 2) * 20 * M.vizIntensity
    table.insert(M.vizWaveforms, {
      x = t * screen.WIDTH,
      y = screen.HEIGHT / 2 + wave1 + wave2 + wave3
    })
  end

  -- Update grid lines
  for _, line in ipairs(M.vizGridLines) do
    line.alpha = 0.05 + math.sin(time * 2 + line.pulse) * 0.05 * M.vizIntensity
          + M.vizPulse * 0.1
  end

  -- Update floating particles
  for i = #M.vizParticles, 1, -1 do
    local p = M.vizParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(M.vizParticles, i)
    end
  end
end

-- ============================================================================
-- TERRAIN UPDATES (Indiana Jones obstacles)
-- ============================================================================
function M.updateTerrain(dt, playerX, playerY)
  if M.raidSection == 1 then
    M.updateHeatsinkFins(dt, playerX, playerY)
    M.updateCircuitTraces(dt, playerX, playerY)
  elseif M.raidSection == 2 then
    M.updateCapacitorBoulders(dt, playerX, playerY)
    M.updateLaserGrids(dt, playerX, playerY)
    M.updateCircuitTraces(dt, playerX, playerY)
  elseif M.raidSection == 3 then
    M.updateVRMExplosions(dt, playerX, playerY)
    M.updateLaserGrids(dt, playerX, playerY)
    M.updatePCBBridges(dt, playerX, playerY)
  end
end

-- Section 1: Heatsink fins - walls with gaps, like canyon flying
function M.updateHeatsinkFins(dt, playerX, playerY)
  M.finSpawnTimer = M.finSpawnTimer - dt
  if M.finSpawnTimer <= 0 then
    M.finSpawnTimer = 2.0 + math.random() * 1.5

    -- Create alternating fin patterns
    local pattern = math.random(1, 4)
    local gapX, gapWidth

    if pattern == 1 then
      gapX = screen.WIDTH * 0.3
      gapWidth = 180
    elseif pattern == 2 then
      gapX = screen.WIDTH * 0.7
      gapWidth = 180
    elseif pattern == 3 then
      gapX = screen.WIDTH * 0.5
      gapWidth = 150
    else
      -- Double gap (two narrow openings)
      table.insert(M.heatsinkFins, {
        y = -80,
        height = 70,
        gapLeft1 = screen.WIDTH * 0.2,
        gapRight1 = screen.WIDTH * 0.2 + 120,
        gapLeft2 = screen.WIDTH * 0.65,
        gapRight2 = screen.WIDTH * 0.65 + 120,
        doubleGap = true,
        glowPhase = math.random() * math.pi * 2,
        color = math.random(1, 3)  -- Aesthetic variation
      })
      return
    end

    table.insert(M.heatsinkFins, {
      y = -80,
      height = 70,
      gapLeft = gapX - gapWidth / 2,
      gapRight = gapX + gapWidth / 2,
      doubleGap = false,
      glowPhase = math.random() * math.pi * 2,
      color = math.random(1, 3)
    })
  end

  -- Update fins
  for i = #M.heatsinkFins, 1, -1 do
    local fin = M.heatsinkFins[i]
    fin.y = fin.y + M.finScrollSpeed * dt

    if fin.y > screen.HEIGHT + 100 then
      table.remove(M.heatsinkFins, i)
    end
  end
end

-- Circuit traces that arc with electricity
function M.updateCircuitTraces(dt, playerX, playerY)
  M.traceArcTimer = M.traceArcTimer - dt
  if M.traceArcTimer <= 0 then
    M.traceArcTimer = 3.0 + math.random() * 2.0

    local startX = math.random(50, screen.WIDTH - 50)
    local endX = startX + (math.random() - 0.5) * 300
    endX = math.max(50, math.min(screen.WIDTH - 50, endX))

    table.insert(M.circuitTraces, {
      startX = startX,
      endX = endX,
      y = -20,
      width = 4,
      arcActive = false,
      arcTimer = 0.8 + math.random() * 0.5,
      arcDuration = 0.6,
      arcIntensity = 0,
      lifetime = 6,
      warned = false
    })
  end

  for i = #M.circuitTraces, 1, -1 do
    local trace = M.circuitTraces[i]
    trace.y = trace.y + M.finScrollSpeed * 0.8 * dt
    trace.lifetime = trace.lifetime - dt

    -- Arc warning then discharge
    if not trace.arcActive then
      trace.arcTimer = trace.arcTimer - dt
      if trace.arcTimer <= 0 then
        trace.arcActive = true
        trace.arcIntensity = 1.0
      elseif trace.arcTimer < 0.5 then
        trace.warned = true
      end
    else
      trace.arcDuration = trace.arcDuration - dt
      trace.arcIntensity = trace.arcIntensity * (1 - dt * 2)
      if trace.arcDuration <= 0 then
        trace.arcActive = false
        trace.arcTimer = 1.0 + math.random() * 1.5
        trace.arcDuration = 0.6
      end
    end

    if trace.lifetime <= 0 or trace.y > screen.HEIGHT + 50 then
      table.remove(M.circuitTraces, i)
    end
  end
end

-- Section 2: Rolling capacitor boulders (Indiana Jones boulder chase)
function M.updateCapacitorBoulders(dt, playerX, playerY)
  M.boulderSpawnTimer = M.boulderSpawnTimer - dt
  if M.boulderSpawnTimer <= 0 then
    M.boulderSpawnTimer = 3.5 + math.random() * 2.0

    local side = math.random(1, 2)
    table.insert(M.capacitorBoulders, {
      x = side == 1 and -40 or (screen.WIDTH + 40),
      y = math.random(150, screen.HEIGHT - 150),
      vx = side == 1 and 180 or -180,
      vy = (math.random() - 0.5) * 40,
      radius = 30 + math.random(0, 15),
      rotation = 0,
      rotSpeed = (math.random() - 0.5) * 6,
      warned = true,  -- Warning arrow shows direction
      lifetime = 8
    })
  end

  for i = #M.capacitorBoulders, 1, -1 do
    local boulder = M.capacitorBoulders[i]
    boulder.x = boulder.x + boulder.vx * dt
    boulder.y = boulder.y + boulder.vy * dt
    boulder.rotation = boulder.rotation + boulder.rotSpeed * dt
    boulder.lifetime = boulder.lifetime - dt

    if boulder.lifetime <= 0 or boulder.x < -100 or boulder.x > screen.WIDTH + 100 then
      table.remove(M.capacitorBoulders, i)
    end
  end
end

-- Laser security grids - horizontal/vertical laser lines with moving gaps
function M.updateLaserGrids(dt, playerX, playerY)
  M.laserGridTimer = M.laserGridTimer - dt
  if M.laserGridTimer <= 0 then
    M.laserGridTimer = 4.0 + math.random() * 3.0

    local gridType = math.random(1, 3)
    if gridType == 1 then
      -- Horizontal sweep
      table.insert(M.laserGrids, {
        type = "horizontal",
        y = -10,
        gapX = math.random(100, screen.WIDTH - 100),
        gapWidth = 140,
        gapSpeed = 100 + math.random(0, 80),
        gapDirection = math.random() > 0.5 and 1 or -1,
        scrollSpeed = 60,
        lifetime = 12
      })
    elseif gridType == 2 then
      -- Vertical sweep (stationary Y, sweeps across screen)
      table.insert(M.laserGrids, {
        type = "vertical",
        x = -10,
        gapY = math.random(100, screen.HEIGHT - 100),
        gapHeight = 140,
        sweepSpeed = 80,
        lifetime = 10
      })
    else
      -- Cross pattern - two perpendicular beams rotating
      table.insert(M.laserGrids, {
        type = "cross",
        cx = screen.WIDTH / 2,
        cy = screen.HEIGHT / 2 - 50,
        angle = 0,
        rotSpeed = 0.8 + math.random() * 0.5,
        beamWidth = 20,
        lifetime = 6
      })
    end
  end

  for i = #M.laserGrids, 1, -1 do
    local grid = M.laserGrids[i]
    grid.lifetime = grid.lifetime - dt

    if grid.type == "horizontal" then
      grid.y = grid.y + grid.scrollSpeed * dt
      grid.gapX = grid.gapX + grid.gapSpeed * grid.gapDirection * dt
      if grid.gapX < 80 or grid.gapX > screen.WIDTH - 80 then
        grid.gapDirection = -grid.gapDirection
      end
    elseif grid.type == "vertical" then
      grid.x = grid.x + grid.sweepSpeed * dt
    elseif grid.type == "cross" then
      grid.angle = grid.angle + grid.rotSpeed * dt
    end

    if grid.lifetime <= 0 then
      table.remove(M.laserGrids, i)
    end
  end
end

-- VRM thermal explosions - timed area denial (dodge or die)
function M.updateVRMExplosions(dt, playerX, playerY)
  M.vrmTimer = M.vrmTimer - dt
  if M.vrmTimer <= 0 then
    M.vrmTimer = 2.5 + math.random() * 2.0

    table.insert(M.vrmExplosions, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(120, screen.HEIGHT - 120),
      radius = 0,
      maxRadius = 80 + math.random(0, 40),
      chargeTimer = 1.8,  -- Warning before explosion
      exploding = false,
      explosionTimer = 0.5,
      damage = DAMAGE.vrm_explosion,
      warned = false
    })
  end

  for i = #M.vrmExplosions, 1, -1 do
    local vrm = M.vrmExplosions[i]

    if not vrm.exploding then
      vrm.chargeTimer = vrm.chargeTimer - dt
      if vrm.chargeTimer < 1.0 then
        vrm.warned = true
      end
      if vrm.chargeTimer <= 0 then
        vrm.exploding = true
        vrm.radius = vrm.maxRadius
      end
    else
      vrm.explosionTimer = vrm.explosionTimer - dt
      if vrm.explosionTimer <= 0 then
        table.remove(M.vrmExplosions, i)
      end
    end
  end
end

-- PCB bridge collapse sections
function M.updatePCBBridges(dt, playerX, playerY)
  -- Bridges are pre-placed in section 3 - they crumble as you approach
  if M.sectionTimer < 1 and #M.pcbBridges == 0 then
    -- Spawn a series of bridge sections
    for i = 1, 4 do
      table.insert(M.pcbBridges, {
        x = screen.WIDTH / 2,
        y = -100 + i * 200,
        width = screen.WIDTH - 100,
        height = 30,
        integrity = 1.0,  -- 1.0 = solid, 0.0 = collapsed
        collapseSpeed = 0.3 + math.random() * 0.2,
        collapsing = false,
        collapseDelay = 0.8,  -- Brief warning before collapse
        scrolled = false
      })
    end
  end

  for i = #M.pcbBridges, 1, -1 do
    local bridge = M.pcbBridges[i]
    bridge.y = bridge.y + M.finScrollSpeed * 0.6 * dt

    -- Start collapsing when player is near
    if not bridge.collapsing and bridge.y > 0 and bridge.y < screen.HEIGHT then
      local dy = math.abs(playerY - bridge.y)
      if dy < 150 then
        bridge.collapsing = true
      end
    end

    if bridge.collapsing then
      if bridge.collapseDelay > 0 then
        bridge.collapseDelay = bridge.collapseDelay - dt
      else
        bridge.integrity = bridge.integrity - bridge.collapseSpeed * dt
        if bridge.integrity < 0 then bridge.integrity = 0 end
      end
    end

    if bridge.y > screen.HEIGHT + 100 then
      table.remove(M.pcbBridges, i)
    end
  end
end

-- ============================================================================
-- PUZZLE UPDATES
-- ============================================================================
function M.updatePuzzles(dt, playerX, playerY)
  if not M.puzzleActive then
    -- Trigger puzzles at specific section times
    if M.raidSection == 1 and M.sectionTimer > 12 and not M.puzzleSolved then
      M.startPuzzle("trace_route")
    elseif M.raidSection == 2 and M.sectionTimer > 15 and not M.puzzleSolved then
      M.startPuzzle("frequency")
    elseif M.raidSection == 3 and M.sectionTimer > 10 and not M.puzzleSolved then
      M.startPuzzle("color_decode")
    end
    return
  end

  M.puzzleTimer = M.puzzleTimer - dt

  if M.puzzleType == "trace_route" then
    M.updateTraceRoutePuzzle(dt, playerX, playerY)
  elseif M.puzzleType == "frequency" then
    M.updateFrequencyPuzzle(dt, playerX, playerY)
  elseif M.puzzleType == "color_decode" then
    M.updateColorDecodePuzzle(dt, playerX, playerY)
  elseif M.puzzleType == "memory_bus" then
    M.updateMemoryBusPuzzle(dt, playerX, playerY)
  end

  -- Puzzle timeout penalty
  if M.puzzleTimer <= 0 then
    M.puzzleActive = false
    M.puzzleSolved = true  -- Mark as "attempted" so it doesn't respawn
  end
end

function M.startPuzzle(puzzleType)
  M.puzzleActive = true
  M.puzzleType = puzzleType
  M.puzzleSolved = false
  M.puzzleTimer = 15  -- 15 seconds to solve

  if puzzleType == "trace_route" then
    -- Spawn colored nodes that must be shot in order (1-2-3-4)
    local colors = {"red", "green", "blue", "yellow"}
    M.puzzleData = {
      nodes = {},
      currentTarget = 1,
      solved = false
    }
    for i = 1, 4 do
      table.insert(M.puzzleData.nodes, {
        x = 100 + (i - 1) * (screen.WIDTH - 200) / 3 + (math.random() - 0.5) * 60,
        y = screen.HEIGHT / 2 - 100 + (math.random() - 0.5) * 80,
        color = colors[i],
        radius = 20,
        hit = false,
        order = i,
        pulsePhase = math.random() * math.pi * 2
      })
    end

  elseif puzzleType == "frequency" then
    -- Player must align with an oscillating target zone
    M.puzzleData = {
      targetFreq = 1.5 + math.random() * 2,
      targetAmplitude = 80 + math.random() * 60,
      matchTimer = 0,
      matchRequired = 2.0,  -- Must stay in zone for 2 seconds
      matched = false,
      zoneWidth = 60
    }

  elseif puzzleType == "color_decode" then
    -- Background flashes a color sequence; shoot matching colored targets
    local palette = {
      {1, 0.2, 0.2, name = "red"},
      {0.2, 1, 0.2, name = "green"},
      {0.2, 0.4, 1, name = "blue"},
      {1, 1, 0.2, name = "yellow"}
    }
    local sequence = {}
    for i = 1, 4 do
      table.insert(sequence, palette[math.random(1, #palette)])
    end
    M.puzzleData = {
      sequence = sequence,
      currentStep = 1,
      targets = {},
      flashTimer = 0,
      flashIndex = 1,
      showingSequence = true,
      flashDuration = 0.8,
      solved = false
    }
    -- Spawn 4 color targets
    for i, color in ipairs(palette) do
      table.insert(M.puzzleData.targets, {
        x = 150 + (i - 1) * (screen.WIDTH - 300) / 3,
        y = screen.HEIGHT - 150,
        radius = 25,
        color = color,
        colorName = color.name,
        pulsePhase = math.random() * math.pi * 2
      })
    end
    M.puzzleTimer = 25  -- Extra time for this puzzle

  elseif puzzleType == "memory_bus" then
    -- Show a pattern of positions, player must fly through them in order
    M.puzzleData = {
      waypoints = {},
      currentWaypoint = 1,
      showingPattern = true,
      showTimer = 4,
      solved = false
    }
    for i = 1, 5 do
      table.insert(M.puzzleData.waypoints, {
        x = math.random(100, screen.WIDTH - 100),
        y = math.random(150, screen.HEIGHT - 150),
        radius = 40,
        reached = false
      })
    end
  end
end

function M.updateTraceRoutePuzzle(dt, playerX, playerY)
  if not M.puzzleData or M.puzzleData.solved then
    M.puzzleActive = false
    M.puzzleSolved = true
    return
  end

  -- Pulse animation
  for _, node in ipairs(M.puzzleData.nodes) do
    node.pulsePhase = node.pulsePhase + dt * 3
  end

  -- Check if all nodes are hit
  if M.puzzleData.currentTarget > #M.puzzleData.nodes then
    M.puzzleData.solved = true
  end
end

function M.updateFrequencyPuzzle(dt, playerX, playerY)
  if not M.puzzleData or M.puzzleData.matched then
    M.puzzleActive = false
    M.puzzleSolved = true
    return
  end

  local time = love.timer.getTime()
  local targetY = screen.HEIGHT / 2 + math.sin(time * M.puzzleData.targetFreq) * M.puzzleData.targetAmplitude

  -- Check if player is in the target zone
  local inZone = math.abs(playerY - targetY) < M.puzzleData.zoneWidth / 2

  if inZone then
    M.puzzleData.matchTimer = M.puzzleData.matchTimer + dt
    if M.puzzleData.matchTimer >= M.puzzleData.matchRequired then
      M.puzzleData.matched = true
    end
  else
    M.puzzleData.matchTimer = math.max(0, M.puzzleData.matchTimer - dt * 2)
  end
end

function M.updateColorDecodePuzzle(dt, playerX, playerY)
  if not M.puzzleData or M.puzzleData.solved then
    M.puzzleActive = false
    M.puzzleSolved = true
    return
  end

  -- Flash sequence display
  if M.puzzleData.showingSequence then
    M.puzzleData.flashTimer = M.puzzleData.flashTimer + dt
    if M.puzzleData.flashTimer >= M.puzzleData.flashDuration then
      M.puzzleData.flashTimer = 0
      M.puzzleData.flashIndex = M.puzzleData.flashIndex + 1
      if M.puzzleData.flashIndex > #M.puzzleData.sequence then
        M.puzzleData.showingSequence = false
      end
    end
  end

  -- Check if all steps are complete
  if M.puzzleData.currentStep > #M.puzzleData.sequence then
    M.puzzleData.solved = true
  end
end

function M.updateMemoryBusPuzzle(dt, playerX, playerY)
  if not M.puzzleData or M.puzzleData.solved then
    M.puzzleActive = false
    M.puzzleSolved = true
    return
  end

  if M.puzzleData.showingPattern then
    M.puzzleData.showTimer = M.puzzleData.showTimer - dt
    if M.puzzleData.showTimer <= 0 then
      M.puzzleData.showingPattern = false
    end
    return
  end

  -- Check if player reached current waypoint
  local wp = M.puzzleData.waypoints[M.puzzleData.currentWaypoint]
  if wp then
    local dist = math.sqrt((playerX - wp.x)^2 + (playerY - wp.y)^2)
    if dist < wp.radius then
      wp.reached = true
      M.puzzleData.currentWaypoint = M.puzzleData.currentWaypoint + 1
      if M.puzzleData.currentWaypoint > #M.puzzleData.waypoints then
        M.puzzleData.solved = true
      end
    end
  end
end

-- Called when player shoots a puzzle node (from init.lua collision checks)
function M.onPuzzleNodeHit(nodeIndex)
  if not M.puzzleActive or not M.puzzleData then return end

  if M.puzzleType == "trace_route" then
    if nodeIndex == M.puzzleData.currentTarget then
      M.puzzleData.nodes[nodeIndex].hit = true
      M.puzzleData.currentTarget = M.puzzleData.currentTarget + 1
    else
      -- Wrong order! Reset progress
      M.puzzleData.currentTarget = 1
      for _, node in ipairs(M.puzzleData.nodes) do
        node.hit = false
      end
    end

  elseif M.puzzleType == "color_decode" and not M.puzzleData.showingSequence then
    local target = M.puzzleData.targets[nodeIndex]
    local expected = M.puzzleData.sequence[M.puzzleData.currentStep]
    if target and expected and target.colorName == expected.name then
      M.puzzleData.currentStep = M.puzzleData.currentStep + 1
    else
      -- Wrong color! Reset
      M.puzzleData.currentStep = 1
    end
  end
end

-- ============================================================================
-- BOSS UPDATE
-- ============================================================================
function M.updateBoss(dt, playerX, playerY)
  local b = M.boss
  if not b or not b.active then return end

  b.shouldAttack = false
  b.pendingProjectiles = {}

  -- Entry animation
  if b.entering then
    b.y = b.y + 60 * dt
    if b.y >= b.targetY then
      b.y = b.targetY
      b.entering = false
    end
    return
  end

  -- Phase transition invuln
  if b.phaseTransitioning then
    b.transitionTimer = b.transitionTimer - dt
    if b.transitionTimer <= 0 then
      b.phaseTransitioning = false
      M.onPhaseStart()
    end
    return
  end

  M.updateBossPhase()
  M.updateBossTeleport(dt, playerX, playerY)
  M.updateTensorNodes(dt, playerX, playerY)
  M.updateOverclockZones(dt)
  M.updateThermalWaves(dt, playerX, playerY)
  M.updateRasterizer(dt, playerX, playerY)
  M.updateBufferFlood(dt, playerX, playerY)
  M.updateKernelPanic(dt, playerX, playerY)
  M.updateRaytrace(dt, playerX, playerY)
  M.updateBossAttacks(dt, playerX, playerY)
  M.updateBossMovement(dt)

  -- Ramp up visualization intensity with boss phases
  M.vizIntensity = 0.6 + (b.phase * 0.04)
  if b.ascended then M.vizIntensity = 1.0 end
end

function M.updateBossPhase()
  local b = M.boss
  local oldPhase = b.phase

  for i = 10, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      b.phase = i
      break
    end
  end

  if b.phase > oldPhase then
    b.phaseTransitioning = true
    b.transitionTimer = 2.0  -- Longer transition for dramatic effect
    -- Cancel all active attacks
    b.lanceActive = false
    b.rasterActive = false
    b.tensorActive = false
    b.bufferFloodActive = false
    b.kernelPanicCharging = false
    b.overclockActive = false
    -- Pulse the visualization on phase change
    M.vizPulse = 1.0
    M.vizBassHit = true
    M.vizBassDecay = 0.5
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 10 then
    b.ascended = true
    b.overclockActive = true
    b.overclockSpeedMult = 1.5
  end

  -- Phase-specific initializations
  if b.phase == 4 then
    -- Spawn tensor nodes
    for i = 1, 3 do
      table.insert(b.tensorNodes, {
        angle = (i - 1) * (2 * math.pi / 3),
        dist = 100,
        rotSpeed = 1.5,
        health = 15,
        active = true
      })
    end
  end

  if b.phase == 7 then
    b.overclockActive = true
    b.overclockSpeedMult = 1.2
  end

  b.attackTimer = 1.5
end

-- ============================================================================
-- BOSS MOVEMENT
-- ============================================================================
function M.updateBossMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end
  if b.rasterActive or b.kernelPanicCharging then return end

  local speed = 1.0
  if b.phase >= 4 then speed = 1.8 end
  if b.phase >= 7 then speed = 2.5 end
  if b.ascended then speed = 3.5 end

  b.moveAngle = b.moveAngle + speed * dt
  local rangeX = 120 + (b.phase * 15)
  b.x = b.baseX + math.sin(b.moveAngle) * rangeX

  -- Vertical movement in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.6) * 25
  end

  -- Ascension pulse
  if b.ascended then
    b.ascensionPulse = b.ascensionPulse + dt * 10
  end
end

-- ============================================================================
-- BOSS TELEPORT (Shader Warp)
-- ============================================================================
function M.updateBossTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.rasterActive or b.tensorActive or b.kernelPanicCharging then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 3.5
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      -- Pipeline Lance on reappear (phase 2+)
      if b.phase >= 2 then
        b.shouldAttack = true
        b.currentAttack = "pipelineLance"
      end
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 3.5
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    local cooldown = b.teleportCooldown
    if b.ascended then cooldown = cooldown * 0.4 end
    if b.overclockActive then cooldown = cooldown / b.overclockSpeedMult end

    if b.teleportTimer <= 0 then
      M.startBossTeleport(playerX, playerY)
      b.teleportTimer = cooldown
    end
  end
end

function M.startBossTeleport(playerX, playerY)
  local b = M.boss
  b.teleporting = true

  local angle = math.random() * math.pi * 2
  local dist = 100 + math.random() * 50
  b.teleportTargetX = math.max(100, math.min(screen.WIDTH - 100, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(250, playerY - 70 - math.random() * 30))
end

-- ============================================================================
-- PHASE 3: RASTERIZER - Sweeping beam across the screen
-- ============================================================================
function M.updateRasterizer(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 3 then return end

  if b.rasterActive then
    b.rasterX = b.rasterX + b.rasterDirection * b.rasterSpeed * dt
    if b.ascended then
      b.rasterSpeed = 400
    elseif b.phase >= 7 then
      b.rasterSpeed = 350
    end

    -- Fire projectiles along the sweep line
    if math.floor(b.rasterX) % 30 == 0 then
      table.insert(b.pendingProjectiles, {
        type = "rasterSweep",
        x = b.rasterX,
        y = b.y + 60,
        angle = math.pi / 2,
        speed = 250,
        damage = DAMAGE.rasterSweep
      })
    end

    if b.rasterX > screen.WIDTH + 20 or b.rasterX < -20 then
      b.rasterActive = false
    end
  end
end

-- ============================================================================
-- PHASE 4: TENSOR CORE - Gravity + Orbiting Nodes
-- ============================================================================
function M.updateTensorNodes(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  -- Update orbiting tensor nodes
  for i = #b.tensorNodes, 1, -1 do
    local node = b.tensorNodes[i]
    if node.active then
      node.angle = node.angle + node.rotSpeed * dt
    end
  end

  -- Tensor gravity pull
  if b.tensorActive then
    b.tensorTimer = b.tensorTimer - dt
    b.tensorPullStrength = 180 + (b.phase * 25)
    if b.ascended then b.tensorPullStrength = b.tensorPullStrength * 1.5 end

    if b.tensorTimer <= 0 then
      b.tensorActive = false
      b.tensorCooldown = b.ascended and 5 or 9
      -- Slam at end
      b.shouldAttack = true
      b.currentAttack = "tensorSlam"
    end
  else
    b.tensorCooldown = b.tensorCooldown - dt
    if b.tensorCooldown <= 0 and not b.rasterActive and not b.kernelPanicCharging and not b.bufferFloodActive then
      b.tensorActive = true
      b.tensorTimer = 3.5
    end
  end
end

-- ============================================================================
-- PHASE 5: RAY TRACE - Bouncing beam
-- ============================================================================
function M.updateRaytrace(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then return end

  -- Update existing beams (bounce off screen edges)
  for i = #b.raytraceBeams, 1, -1 do
    local beam = b.raytraceBeams[i]
    beam.x = beam.x + beam.vx * dt
    beam.y = beam.y + beam.vy * dt
    beam.bounces = beam.bounces or 0

    -- Bounce off walls
    if beam.x < 0 or beam.x > screen.WIDTH then
      beam.vx = -beam.vx
      beam.bounces = beam.bounces + 1
    end
    if beam.y < 0 or beam.y > screen.HEIGHT then
      beam.vy = -beam.vy
      beam.bounces = beam.bounces + 1
    end

    beam.lifetime = beam.lifetime - dt
    if beam.lifetime <= 0 or beam.bounces > 5 then
      table.remove(b.raytraceBeams, i)
    end
  end

  -- Spawn new raytrace beams
  b.raytraceCooldown = b.raytraceCooldown - dt
  if b.raytraceCooldown <= 0 and not b.tensorActive and not b.kernelPanicCharging then
    b.raytraceCooldown = b.ascended and 3 or 6

    local angle = math.atan2(playerY - b.y, playerX - b.x)
    local speed = 280
    table.insert(b.raytraceBeams, {
      x = b.x,
      y = b.y + 60,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      damage = DAMAGE.raytraceBeam,
      lifetime = 5,
      bounces = 0,
      width = 12
    })
  end
end

-- ============================================================================
-- PHASE 6: BUFFER OVERFLOW - Screen flood
-- ============================================================================
function M.updateBufferFlood(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 6 then return end

  if b.bufferFloodActive then
    b.bufferFloodTimer = b.bufferFloodTimer - dt

    -- Spawn projectiles from all screen edges
    if math.floor(b.bufferFloodTimer * 10) % 2 == 0 then
      local side = math.random(1, 4)
      local px, py, pvx, pvy
      if side == 1 then -- top
        px = math.random(0, screen.WIDTH)
        py = 0
        pvx = (math.random() - 0.5) * 100
        pvy = 150 + math.random() * 100
      elseif side == 2 then -- bottom
        px = math.random(0, screen.WIDTH)
        py = screen.HEIGHT
        pvx = (math.random() - 0.5) * 100
        pvy = -(150 + math.random() * 100)
      elseif side == 3 then -- left
        px = 0
        py = math.random(0, screen.HEIGHT)
        pvx = 150 + math.random() * 100
        pvy = (math.random() - 0.5) * 100
      else -- right
        px = screen.WIDTH
        py = math.random(0, screen.HEIGHT)
        pvx = -(150 + math.random() * 100)
        pvy = (math.random() - 0.5) * 100
      end

      table.insert(b.pendingProjectiles, {
        type = "bufferFlood",
        x = px, y = py,
        angle = math.atan2(pvy, pvx),
        speed = math.sqrt(pvx*pvx + pvy*pvy),
        damage = DAMAGE.bufferOverflow
      })
    end

    if b.bufferFloodTimer <= 0 then
      b.bufferFloodActive = false
    end
  end
end

-- ============================================================================
-- PHASE 7: OVERCLOCK - DOT zones + attack speed increase
-- ============================================================================
function M.updateOverclockZones(dt)
  local b = M.boss
  if not b.overclockActive then return end

  b.overclockSpawnTimer = b.overclockSpawnTimer - dt
  local spawnRate = b.ascended and 1.5 or 3.0

  if b.overclockSpawnTimer <= 0 and #b.overclockZones < 6 then
    b.overclockSpawnTimer = spawnRate
    table.insert(b.overclockZones, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(180, screen.HEIGHT - 80),
      radius = 50 + math.random(0, 20),
      lifetime = 10,
      damage = DAMAGE.clockPulse,
      damageTimer = 0,
      pulsePhase = math.random() * math.pi * 2
    })
  end

  for i = #b.overclockZones, 1, -1 do
    local zone = b.overclockZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt
    if zone.lifetime <= 0 then
      table.remove(b.overclockZones, i)
    end
  end
end

-- ============================================================================
-- PHASE 8: KERNEL PANIC - Telegraphed near-lethal blast
-- ============================================================================
function M.updateKernelPanic(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 8 then return end

  if b.kernelPanicCharging then
    b.kernelPanicTimer = b.kernelPanicTimer - dt
    -- Grow warning radius during charge
    b.kernelPanicRadius = (1 - b.kernelPanicTimer / b.kernelPanicDuration) * 200

    if b.kernelPanicTimer <= 0 then
      b.kernelPanicCharging = false
      -- Fire the kernel panic blast
      table.insert(b.pendingProjectiles, {
        type = "kernelPanic",
        x = b.kernelPanicTargetX,
        y = b.kernelPanicTargetY,
        damage = DAMAGE.kernelPanic,
        radius = 200
      })
      b.shouldAttack = true
      b.currentAttack = "kernelPanic"
    end
  end
end

function M.startKernelPanic(playerX, playerY)
  local b = M.boss
  b.kernelPanicCharging = true
  b.kernelPanicTimer = b.ascended and 2.0 or b.kernelPanicDuration
  b.kernelPanicTargetX = playerX
  b.kernelPanicTargetY = playerY
  b.kernelPanicRadius = 0
end

-- ============================================================================
-- PHASE 9: THERMAL THROTTLE - Fire wave patterns
-- ============================================================================
function M.updateThermalWaves(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 9 then return end

  -- Spawn fire waves
  b.thermalWaveTimer = b.thermalWaveTimer - dt
  if b.thermalWaveTimer <= 0 then
    b.thermalWaveTimer = b.ascended and 1.5 or 2.5

    -- Horizontal fire wave
    table.insert(b.thermalWaves, {
      y = b.y + 60,
      speed = 120,
      width = screen.WIDTH,
      height = 25,
      lifetime = 5,
      damage = DAMAGE.thermalMeltdown,
      damageTimer = 0
    })
  end

  for i = #b.thermalWaves, 1, -1 do
    local wave = b.thermalWaves[i]
    wave.y = wave.y + wave.speed * dt
    wave.lifetime = wave.lifetime - dt
    wave.damageTimer = wave.damageTimer - dt

    if wave.lifetime <= 0 or wave.y > screen.HEIGHT + 50 then
      table.remove(b.thermalWaves, i)
    end
  end
end

-- ============================================================================
-- BOSS ATTACK AI
-- ============================================================================
function M.updateBossAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.rasterActive or b.tensorActive or b.kernelPanicCharging or b.bufferFloodActive then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 4 then attackSpeed = 1.2 end
  if b.phase >= 7 then attackSpeed = 1.5 end
  if b.ascended then attackSpeed = 2.0 end
  if b.overclockActive then attackSpeed = attackSpeed * b.overclockSpeedMult end

  local baseCooldown = 2.2 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseBossAttack(playerX, playerY)
  end
end

function M.chooseBossAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Shader Storm only
    M.fireShaderStorm(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: Shader Storm + Pipeline Lance
    if roll < 55 then
      M.fireShaderStorm(playerX, playerY)
    else
      M.firePipelineLance(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: + Rasterizer sweep
    if roll < 35 then
      M.fireShaderStorm(playerX, playerY)
    elseif roll < 65 then
      M.firePipelineLance(playerX, playerY)
    else
      M.startRasterizer()
    end

  elseif b.phase == 4 then
    -- Phase 4: + Tensor Core gravity
    if roll < 25 and not b.tensorActive then
      b.tensorActive = true
      b.tensorTimer = 3.5
    elseif roll < 50 then
      M.fireShaderStorm(playerX, playerY)
    elseif roll < 75 then
      M.firePipelineLance(playerX, playerY)
    else
      M.startRasterizer()
    end

  elseif b.phase == 5 then
    -- Phase 5: + Ray Trace bouncing beams
    if roll < 20 then
      M.fireShaderStorm(playerX, playerY)
    elseif roll < 40 then
      M.firePipelineLance(playerX, playerY)
    elseif roll < 55 then
      M.startRasterizer()
    elseif roll < 70 then
      b.tensorActive = true
      b.tensorTimer = 3
    else
      -- Raytrace is handled passively
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 6 then
    -- Phase 6: + Buffer Overflow flood
    if roll < 15 and not b.bufferFloodActive then
      b.bufferFloodActive = true
      b.bufferFloodTimer = 3
    elseif roll < 35 then
      M.firePipelineLance(playerX, playerY)
    elseif roll < 55 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 70 then
      M.startRasterizer()
    else
      M.fireShaderStorm(playerX, playerY)
    end

  elseif b.phase == 7 then
    -- Phase 7: + Overclock (passive speed boost + zones)
    if roll < 25 then
      M.firePipelineLance(playerX, playerY)
    elseif roll < 45 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 60 then
      M.startRasterizer()
    elseif roll < 75 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.fireShaderStorm(playerX, playerY)
    end

  elseif b.phase == 8 then
    -- Phase 8: + Kernel Panic
    if roll < 15 then
      M.startKernelPanic(playerX, playerY)
    elseif roll < 30 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 45 then
      M.firePipelineLance(playerX, playerY)
    elseif roll < 60 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 75 then
      M.startRasterizer()
    else
      b.bufferFloodActive = true
      b.bufferFloodTimer = 2.5
    end

  elseif b.phase == 9 then
    -- Phase 9: + Thermal Throttle fire waves
    if roll < 15 then
      M.startKernelPanic(playerX, playerY)
    elseif roll < 30 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 45 then
      b.bufferFloodActive = true
      b.bufferFloodTimer = 2
    elseif roll < 60 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 75 then
      M.startRasterizer()
    else
      M.firePipelineLance(playerX, playerY)
    end

  else
    -- Phase 10: GPU ASCENSION - everything combined, combos
    b.comboCount = b.comboCount + 1

    if b.comboCount >= 3 then
      b.comboCount = 0
      -- Devastating combo: kernel panic + buffer flood
      if roll < 40 then
        M.startKernelPanic(playerX, playerY)
      elseif roll < 70 then
        b.bufferFloodActive = true
        b.bufferFloodTimer = 3
      else
        M.fireSweepPattern(playerX, playerY)
        M.fireSpreadPattern(playerX, playerY)
      end
    else
      if roll < 20 then
        M.fireShaderStorm(playerX, playerY)
      elseif roll < 35 then
        M.firePipelineLance(playerX, playerY)
      elseif roll < 50 then
        M.fireSpreadPattern(playerX, playerY)
      elseif roll < 65 then
        M.fireSweepPattern(playerX, playerY)
      elseif roll < 80 then
        M.startRasterizer()
      else
        M.fireShaderStorm(playerX, playerY)
        M.firePipelineLance(playerX, playerY)
      end
    end
    b.attackTimer = 0.6  -- Blazing fast in ascension
  end
end

-- ============================================================================
-- BOSS ATTACK PATTERNS
-- ============================================================================

-- Phase 1: Shader Storm - fragments fly in chaotic arcs
function M.fireShaderStorm(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.shaderStorm
  if b.ascended then damage = math.floor(damage * b.ascensionMultiplier) end

  local count = b.ascended and 7 or 4
  for i = 1, count do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + (math.random() - 0.5) * 0.8
    table.insert(b.pendingProjectiles, {
      type = "shaderFragment",
      x = b.x + (math.random() - 0.5) * 40,
      y = b.y + 50,
      angle = angle,
      speed = 280 + math.random() * 80,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "shaderStorm"
end

-- Phase 2: Pipeline Lance - focused triple beam
function M.firePipelineLance(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.pipelineLance
  if b.ascended then damage = math.floor(damage * b.ascensionMultiplier) end

  for i = -1, 1 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.2
    table.insert(b.pendingProjectiles, {
      type = "pipelineLance",
      x = b.x + i * 25,
      y = b.y + 55,
      angle = angle,
      speed = 400,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "pipelineLance"
end

-- Rasterizer initiation
function M.startRasterizer()
  local b = M.boss
  b.rasterActive = true
  b.rasterX = b.rasterDirection > 0 and -10 or screen.WIDTH + 10
  b.rasterDirection = -b.rasterDirection  -- Alternate direction
end

-- Generic spread pattern
function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.shaderStorm
  if b.ascended then damage = math.floor(damage * b.ascensionMultiplier) end

  local count = b.ascended and 9 or 6
  for i = 1, count do
    local angle = math.pi/2 + ((i - (count+1)/2) * 0.2)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 260,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "spread"
end

-- Sweep pattern
function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.pipelineLance
  if b.ascended then damage = math.floor(damage * b.ascensionMultiplier) end

  local count = b.ascended and 14 or 10
  for i = 0, count - 1 do
    local delay = i * 0.06
    local angle = math.pi/2 - 0.7 + (i * (1.4 / count))
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 360,
      damage = damage,
      delay = delay
    })
  end

  b.shouldAttack = true
  b.currentAttack = "sweep"
end

-- ============================================================================
-- BOSS DAMAGE
-- ============================================================================
function M.damage(amount, hitArm)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Must destroy shield cores first
  if not b.shieldCoresDown then
    if hitArm == "left" and not b.leftShieldCore.destroyed then
      b.leftShieldCore.health = b.leftShieldCore.health - amount
      if b.leftShieldCore.health <= 0 then
        b.leftShieldCore.destroyed = true
      end
      if b.leftShieldCore.destroyed and b.rightShieldCore.destroyed then
        b.shieldCoresDown = true
      end
      return false
    elseif hitArm == "right" and not b.rightShieldCore.destroyed then
      b.rightShieldCore.health = b.rightShieldCore.health - amount
      if b.rightShieldCore.health <= 0 then
        b.rightShieldCore.destroyed = true
      end
      if b.leftShieldCore.destroyed and b.rightShieldCore.destroyed then
        b.shieldCoresDown = true
      end
      return false
    end
    return false
  end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    M.raidActive = false
    return true
  end
  return false
end

-- Damage tensor nodes directly
function M.damageTensorNode(nodeIndex, amount)
  local b = M.boss
  if not b or not b.tensorNodes then return end
  local node = b.tensorNodes[nodeIndex]
  if node and node.active then
    node.health = node.health - amount
    if node.health <= 0 then
      node.active = false
    end
  end
end

-- ============================================================================
-- TERRAIN COLLISION CHECKS (called from init.lua)
-- ============================================================================

-- Check if player hits heatsink fins
function M.checkFinCollision(playerX, playerY, playerRadius)
  for _, fin in ipairs(M.heatsinkFins) do
    if playerY + playerRadius > fin.y and playerY - playerRadius < fin.y + fin.height then
      if fin.doubleGap then
        local inGap1 = playerX > fin.gapLeft1 and playerX < fin.gapRight1
        local inGap2 = playerX > fin.gapLeft2 and playerX < fin.gapRight2
        if not inGap1 and not inGap2 then
          return true, DAMAGE.heatsinkFin
        end
      else
        if playerX - playerRadius < fin.gapLeft or playerX + playerRadius > fin.gapRight then
          return true, DAMAGE.heatsinkFin
        end
      end
    end
  end
  return false, 0
end

-- Check if player hits circuit trace arc
function M.checkTraceArcDamage(playerX, playerY, playerRadius)
  for _, trace in ipairs(M.circuitTraces) do
    if trace.arcActive then
      local minX = math.min(trace.startX, trace.endX) - 15
      local maxX = math.max(trace.startX, trace.endX) + 15
      if playerX > minX and playerX < maxX then
        if math.abs(playerY - trace.y) < 30 + playerRadius then
          return true, DAMAGE.arcDischarge
        end
      end
    end
  end
  return false, 0
end

-- Check if player hits capacitor boulder
function M.checkBoulderCollision(playerX, playerY, playerRadius)
  for _, boulder in ipairs(M.capacitorBoulders) do
    local dist = math.sqrt((playerX - boulder.x)^2 + (playerY - boulder.y)^2)
    if dist < boulder.radius + playerRadius then
      return true, DAMAGE.capacitorBoulder
    end
  end
  return false, 0
end

-- Check if player is in laser grid
function M.checkLaserGridDamage(playerX, playerY, playerRadius)
  for _, grid in ipairs(M.laserGrids) do
    if grid.type == "horizontal" then
      if math.abs(playerY - grid.y) < 10 + playerRadius then
        if playerX < grid.gapX - grid.gapWidth/2 or playerX > grid.gapX + grid.gapWidth/2 then
          return true, DAMAGE.laserGrid
        end
      end
    elseif grid.type == "vertical" then
      if math.abs(playerX - grid.x) < 10 + playerRadius then
        if playerY < grid.gapY - grid.gapHeight/2 or playerY > grid.gapY + grid.gapHeight/2 then
          return true, DAMAGE.laserGrid
        end
      end
    elseif grid.type == "cross" then
      -- Rotating cross beams
      local dx = playerX - grid.cx
      local dy = playerY - grid.cy
      local rotX = dx * math.cos(-grid.angle) - dy * math.sin(-grid.angle)
      local rotY = dx * math.sin(-grid.angle) + dy * math.cos(-grid.angle)
      if (math.abs(rotX) < grid.beamWidth/2 and math.abs(rotY) < 400) or
         (math.abs(rotY) < grid.beamWidth/2 and math.abs(rotX) < 400) then
        return true, DAMAGE.laserGrid
      end
    end
  end
  return false, 0
end

-- Check VRM explosion damage
function M.checkVRMDamage(playerX, playerY, playerRadius)
  for _, vrm in ipairs(M.vrmExplosions) do
    if vrm.exploding then
      local dist = math.sqrt((playerX - vrm.x)^2 + (playerY - vrm.y)^2)
      if dist < vrm.radius + playerRadius then
        return true, DAMAGE.vrm_explosion
      end
    end
  end
  return false, 0
end

-- Check PCB bridge damage
function M.checkBridgeDamage(playerX, playerY, playerRadius)
  for _, bridge in ipairs(M.pcbBridges) do
    if bridge.integrity < 0.3 then
      if math.abs(playerY - bridge.y) < bridge.height + playerRadius then
        if playerX > bridge.x - bridge.width/2 and playerX < bridge.x + bridge.width/2 then
          return true, DAMAGE.pcbCollapse
        end
      end
    end
  end
  return false, 0
end

-- ============================================================================
-- BOSS SPECIAL MECHANIC CHECKS (called from init.lua)
-- ============================================================================

-- Tensor gravity pull
function M.getGravityPull()
  local b = M.boss
  if not b or not b.tensorActive then
    return 0, 0, 0
  end
  return b.x, b.y, b.tensorPullStrength
end

-- Overclock zone DOT
function M.checkOverclockZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.overclockZones) do
    local dx = playerX - zone.x
    local dy = playerY - zone.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
      zone.damageTimer = 0.5
      totalDamage = totalDamage + zone.damage
    end
  end

  return totalDamage
end

-- Thermal wave collision
function M.checkThermalWaveDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, wave in ipairs(b.thermalWaves) do
    if math.abs(playerY - wave.y) < wave.height/2 + playerRadius then
      if wave.damageTimer <= 0 then
        wave.damageTimer = 0.5
        totalDamage = totalDamage + wave.damage
      end
    end
  end

  return totalDamage
end

-- Raytrace beam collision
function M.checkRaytraceBeamDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  for _, beam in ipairs(b.raytraceBeams) do
    local dist = math.sqrt((playerX - beam.x)^2 + (playerY - beam.y)^2)
    if dist < beam.width + playerRadius then
      return beam.damage
    end
  end

  return 0
end

-- Get pending projectiles
function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

-- Get puzzle nodes for collision (so player lasers can hit them)
function M.getPuzzleTargets()
  if not M.puzzleActive or not M.puzzleData then return nil end

  if M.puzzleType == "trace_route" then
    return M.puzzleData.nodes
  elseif M.puzzleType == "color_decode" and not M.puzzleData.showingSequence then
    return M.puzzleData.targets
  end

  return nil
end

-- ============================================================================
-- ATTACK WARNING (for HUD display)
-- ============================================================================
function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.kernelPanicCharging then
    return "KERNEL PANIC", b.kernelPanicTimer / b.kernelPanicDuration
  elseif b.tensorActive then
    return "TENSOR CORE", b.tensorTimer / 3.5
  elseif b.bufferFloodActive then
    return "BUFFER OVERFLOW", b.bufferFloodTimer / 3
  elseif b.rasterActive then
    return "RASTERIZER", 1
  elseif b.phaseTransitioning then
    return "PHASE SHIFT", b.transitionTimer / 2.0
  end

  return nil
end

-- ============================================================================
-- PHASE NAME (for HUD display)
-- ============================================================================
function M.getPhaseName()
  local b = M.boss
  if not b then return "" end

  local names = {
    "SHADER STORM",
    "RENDER PIPELINE",
    "RASTERIZER",
    "TENSOR CORE",
    "RAY TRACING",
    "BUFFER OVERFLOW",
    "OVERCLOCK",
    "KERNEL PANIC",
    "THERMAL THROTTLE",
    "GPU ASCENSION"
  }
  return names[b.phase] or ""
end

-- ============================================================================
-- SECTION NAME (for HUD display during terrain sections)
-- ============================================================================
function M.getSectionName()
  local names = {
    "HEATSINK CANYON",
    "PCB GAUNTLET",
    "VRM CORRIDOR",
    "GPU CORE"
  }
  return names[M.raidSection] or ""
end

return M
