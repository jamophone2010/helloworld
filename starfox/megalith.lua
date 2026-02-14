-- Megalith of Memories: Endgame Raid Boss
-- A journey through the architecture of a dying machine god:
--   Act I:   RAM Corridor   (phases 1-3)  - flying through towering RAM sticks
--   Act II:  Sector Gauntlet (phases 4-6)  - hard drive sectors with puzzle locks
--   Act III: The Core       (phases 7-10) - spinning disk drive boss fight
--
-- Elden Ring boss mechanics + Indiana Jones obstacle runs
-- 10 phases, each with unique mechanics, obstacles, and puzzle elements

local M = {}
local screen = require("starfox.screen")

M.boss = nil

------------------------------------------------------------------------
-- DAMAGE TABLE
------------------------------------------------------------------------
local DAMAGE = {
  -- Act I – RAM Corridor
  ramBolt        = 10,   -- Electrical bolt between RAM sticks
  dataSurge      = 15,   -- Surging data beam sweeping across
  memoryLeak     = 6,    -- DOT pool left behind (per tick)
  overclockSlam  = 25,   -- Full-width shockwave

  -- Act II – Sector Gauntlet
  sectorSweep    = 12,   -- Read-head laser sweep
  badSector      = 8,    -- Corrupted sector hazard DOT
  defragBeam     = 30,   -- Charged defrag laser
  seekArmCrush   = 20,   -- Seek arm slamming across screen

  -- Act III – The Core
  platterSpin    = 10,   -- Spinning platter edge (continuous)
  spindleLaser   = 18,   -- Spindle motor laser ring
  headCrash      = 35,   -- Boss dive-bomb (head crash)
  magneticPulse  = 22,   -- EMP ring expanding outward
  thermalEvent   = 50,   -- Phase 10 near-kill attack (dodge-check)
  coreOverload   = 15,   -- Rage-mode rapid fire
}

------------------------------------------------------------------------
-- PHASE THRESHOLDS (out of 600 total HP)
------------------------------------------------------------------------
local PHASE_THRESHOLDS = {600, 540, 480, 420, 360, 290, 220, 150, 80, 30}

------------------------------------------------------------------------
-- OBSTACLE / ENVIRONMENT TABLES
------------------------------------------------------------------------

-- RAM stick columns (Act I visual + obstacle)
local function generateRAMSticks()
  local sticks = {}
  for i = 1, 8 do
    table.insert(sticks, {
      x = (i - 1) * (screen.WIDTH / 8) + (screen.WIDTH / 16),
      gapY = math.random(200, screen.HEIGHT - 200),
      gapH = 140 + math.random(0, 40),  -- passage height
      speed = 60 + math.random(0, 30),
      scrollY = 0,
      active = true,
      pulse = math.random() * math.pi * 2,
      -- Circuit traces running along the stick
      tracePhase = math.random() * 10,
    })
  end
  return sticks
end

-- Hard-drive sector rings (Act II environment)
local function generateSectors()
  local sectors = {}
  for ring = 1, 5 do
    for seg = 1, 8 do
      local angle = (seg - 1) * (math.pi * 2 / 8)
      table.insert(sectors, {
        ring = ring,
        segment = seg,
        angle = angle,
        corrupted = math.random() < 0.25,
        locked = false,
        unlockCode = math.random(1, 4),  -- puzzle: hit correct color sequence
        radius = 80 + ring * 50,
        health = 0,  -- some sectors are destructible barriers
      })
    end
  end
  return sectors
end

------------------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------------------

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    -- Identity
    type = "megalith",
    name = "MEGALITH OF MEMORIES",

    -- Position
    x = screen.WIDTH / 2,
    y = -180,
    width = 200,
    height = 150,
    targetY = 100,
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Stats
    health = 600,
    maxHealth = 600,
    score = 25000,
    phase = 1,
    active = true,
    entering = true,

    -- Act tracking (which visual backdrop)
    act = 1,           -- 1 = RAM, 2 = Sectors, 3 = Core
    actTimer = 0,

    -- Teleport / flicker
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 6,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 100,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack state machine
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,
    comboMax = 3,

    -- Pending projectiles (init.lua reads these)
    pendingProjectiles = {},

    -- Phase transition
    phaseTransitioning = false,
    transitionTimer = 0,

    -------------------------------------------------------------------
    -- ACT I: RAM CORRIDOR  (phases 1-3)
    -------------------------------------------------------------------
    ramSticks = generateRAMSticks(),
    ramBoltTimer = 0,
    dataSurgeActive = false,
    dataSurgeTimer = 0,
    dataSurgeAngle = 0,
    memoryLeakZones = {},
    memoryLeakSpawnTimer = 0,
    overclockCharging = false,
    overclockTimer = 0,

    -- Puzzle: memory address matching
    -- Three RAM addresses flash in sequence; player must fly through
    -- matching gates in the same order to stagger the boss
    puzzleActive = false,
    puzzleSequence = {},
    puzzleIndex = 0,
    puzzleGates = {},
    puzzleSolved = false,
    puzzleTimer = 0,
    puzzleCooldown = 0,
    puzzleStagger = false,
    puzzleStaggerTimer = 0,

    -------------------------------------------------------------------
    -- ACT II: SECTOR GAUNTLET  (phases 4-6)
    -------------------------------------------------------------------
    sectors = {},
    seekArmX = 0,
    seekArmDir = 1,
    seekArmSpeed = 200,
    seekArmActive = false,
    seekArmTimer = 0,
    defragCharging = false,
    defragTimer = 0,
    defragTargetX = 0,
    defragTargetY = 0,
    badSectorZones = {},
    badSectorSpawnTimer = 0,

    -- Puzzle: sector alignment
    -- Rotating ring segments must be shot in the correct order (color sequence)
    -- to open a path and expose the boss core
    sectorPuzzleActive = false,
    sectorPuzzleRings = {},
    sectorPuzzleIndex = 0,
    sectorPuzzleSolved = false,
    sectorPuzzleCooldown = 0,

    -- Indiana Jones: rolling boulder equivalent – giant read head sweeps
    boulderSweepActive = false,
    boulderSweepTimer = 0,
    boulderSweepY = 0,
    boulderSweepDir = 1,

    -------------------------------------------------------------------
    -- ACT III: THE CORE  (phases 7-10)
    -------------------------------------------------------------------
    -- Spinning disk platters (environmental hazards)
    platters = {},
    platterAngle = 0,
    platterSpeed = 1.5,

    -- Spindle motor (center obstacle)
    spindleRadius = 60,
    spindleLaserAngle = 0,
    spindleLaserCount = 3,  -- rotating laser arms
    spindleLaserActive = false,

    -- Head crash dive-bomb
    headCrashActive = false,
    headCrashTimer = 0,
    headCrashTargetX = 0,
    headCrashTargetY = 0,
    headCrashPhase = "idle",  -- idle, telegraphing, diving, recovering

    -- Magnetic pulse (expanding ring)
    magneticPulseActive = false,
    magneticPulseRadius = 0,
    magneticPulseTimer = 0,

    -- Thermal event (phase 10 ultimate)
    thermalCharging = false,
    thermalTimer = 0,
    thermalDuration = 3.0,
    thermalTargetX = 0,
    thermalTargetY = 0,
    thermalSafeZone = nil,   -- one small zone to dodge into

    -- Enrage (phase 10)
    enraged = false,
    rageMultiplier = 1.6,

    -- Indiana Jones obstacles (Act III)
    -- Swinging actuator arms player must dodge
    actuatorArms = {},
    -- Falling debris (like temple ceiling collapse)
    debrisActive = false,
    debrisTimer = 0,
    debrisColumns = {},

    -- Core shield (must solve final puzzle to break)
    coreShielded = true,
    coreShieldHP = 100,
    coreShieldMaxHP = 100,

    -- Gravity zones (Elden Ring gravity well)
    gravityActive = false,
    gravityTimer = 0,
    gravityCooldown = 10,
    gravityPullStrength = 0,
  }

  -- Initialize platters
  for i = 1, 3 do
    table.insert(M.boss.platters, {
      radius = 100 + i * 60,
      thickness = 15,
      angle = (i - 1) * (math.pi * 2 / 3),
      speed = 0.8 + i * 0.3,
      hasGap = true,
      gapAngle = math.random() * math.pi * 2,
      gapSize = 0.6,  -- radians of safe passage
    })
  end

  -- Initialize actuator arms
  for i = 1, 4 do
    table.insert(M.boss.actuatorArms, {
      pivotX = (i <= 2) and 0 or screen.WIDTH,
      pivotY = 150 + (i - 1) * 150,
      angle = math.random() * math.pi,
      speed = 1.5 + math.random() * 1.0,
      length = 200 + math.random(0, 80),
      active = false,
    })
  end
end

------------------------------------------------------------------------
-- ACTIVE / DEFEATED
------------------------------------------------------------------------

function M.isActive()
  return M.boss ~= nil and M.boss.active
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

------------------------------------------------------------------------
-- MAIN UPDATE
------------------------------------------------------------------------

function M.update(dt, playerX, playerY)
  local b = M.boss
  if not b or not b.active then return end

  b.shouldAttack = false
  b.pendingProjectiles = {}

  -- Entry animation
  if b.entering then
    b.y = b.y + 70 * dt
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

  -- Stagger from puzzle solve
  if b.puzzleStagger then
    b.puzzleStaggerTimer = b.puzzleStaggerTimer - dt
    if b.puzzleStaggerTimer <= 0 then
      b.puzzleStagger = false
    end
    return  -- boss is vulnerable but immobile during stagger
  end

  b.actTimer = b.actTimer + dt

  M.updatePhase()
  M.updateAct(dt)
  M.updateTeleport(dt, playerX, playerY)

  -- Act-specific updates
  if b.act == 1 then
    M.updateRAMCorridor(dt, playerX, playerY)
  elseif b.act == 2 then
    M.updateSectorGauntlet(dt, playerX, playerY)
  elseif b.act == 3 then
    M.updateCore(dt, playerX, playerY)
  end

  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
end

------------------------------------------------------------------------
-- PHASE / ACT MANAGEMENT
------------------------------------------------------------------------

function M.updatePhase()
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
    b.transitionTimer = 2.0
    -- Cancel active attacks
    b.dataSurgeActive = false
    b.overclockCharging = false
    b.headCrashActive = false
    b.headCrashPhase = "idle"
    b.magneticPulseActive = false
    b.thermalCharging = false
    b.defragCharging = false
    b.seekArmActive = false
    b.boulderSweepActive = false
    b.gravityActive = false
    b.spindleLaserActive = false
    b.debrisActive = false
  end
end

function M.updateAct(dt)
  local b = M.boss
  if b.phase <= 3 then
    b.act = 1
  elseif b.phase <= 6 then
    if b.act ~= 2 then
      b.act = 2
      b.sectors = generateSectors()
      b.actTimer = 0
    end
  else
    if b.act ~= 3 then
      b.act = 3
      b.actTimer = 0
      b.coreShielded = true
      b.coreShieldHP = b.coreShieldMaxHP
    end
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 10 then
    b.enraged = true
    b.name = "MEGALITH OF MEMORIES - CORE MELTDOWN"
  elseif b.phase == 7 then
    b.name = "MEGALITH OF MEMORIES - THE CORE"
  elseif b.phase == 4 then
    b.name = "MEGALITH OF MEMORIES - SECTOR GAUNTLET"
  end

  b.attackTimer = 1.5
  b.comboCount = 0
end

------------------------------------------------------------------------
-- MOVEMENT
------------------------------------------------------------------------

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end
  if b.headCrashPhase == "diving" then return end

  local speed = 1.2
  if b.phase >= 4 then speed = 1.8 end
  if b.phase >= 7 then speed = 2.5 end
  if b.enraged then speed = 3.5 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 120 + (b.phase * 15)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Vertical weaving in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.7) * 25
  end
  if b.phase >= 7 then
    b.y = b.targetY + math.sin(b.moveAngle * 1.3) * 40
  end
end

------------------------------------------------------------------------
-- TELEPORT (Elden Ring Shadow Step)
------------------------------------------------------------------------

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.headCrashActive then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 4
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      if b.phase >= 3 then
        b.shouldAttack = true
        b.currentAttack = "shadowStrike"
      end
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 4
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    local cooldown = b.teleportCooldown
    if b.phase >= 7 then cooldown = cooldown * 0.6 end
    if b.enraged then cooldown = cooldown * 0.4 end

    if b.teleportTimer <= 0 then
      M.startTeleport(playerX, playerY)
      b.teleportTimer = cooldown
    end
  end
end

function M.startTeleport(playerX, playerY)
  local b = M.boss
  b.teleporting = true
  local angle = math.random() * math.pi * 2
  local dist = 130
  b.teleportTargetX = math.max(80, math.min(screen.WIDTH - 80, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(250, playerY - 90))
end

------------------------------------------------------------------------
-- ACT I: RAM CORRIDOR  (phases 1-3)
------------------------------------------------------------------------

function M.updateRAMCorridor(dt, playerX, playerY)
  local b = M.boss

  -- Scroll RAM sticks downward (parallax environment)
  for _, stick in ipairs(b.ramSticks) do
    stick.scrollY = stick.scrollY + stick.speed * dt
    stick.pulse = stick.pulse + dt * 3
    if stick.scrollY > screen.HEIGHT + 50 then
      stick.scrollY = -200
      stick.gapY = math.random(200, screen.HEIGHT - 200)
      stick.gapH = 140 + math.random(0, 40)
    end
  end

  -- RAM bolt: electrical arcs between adjacent sticks
  b.ramBoltTimer = b.ramBoltTimer - dt
  if b.ramBoltTimer <= 0 then
    local interval = 3
    if b.phase >= 2 then interval = 2 end
    if b.phase >= 3 then interval = 1.2 end
    b.ramBoltTimer = interval

    -- Pick two adjacent sticks and fire a bolt between them
    local idx = math.random(1, #b.ramSticks - 1)
    local s1 = b.ramSticks[idx]
    local s2 = b.ramSticks[idx + 1]
    table.insert(b.pendingProjectiles, {
      type = "ramBolt",
      x1 = s1.x, y1 = s1.gapY + s1.scrollY,
      x2 = s2.x, y2 = s2.gapY + s2.scrollY,
      damage = DAMAGE.ramBolt,
      width = 12,
    })
    b.shouldAttack = true
    b.currentAttack = "ramBolt"
  end

  -- Data surge: sweeping horizontal beam (phase 2+)
  if b.phase >= 2 then
    if b.dataSurgeActive then
      b.dataSurgeTimer = b.dataSurgeTimer - dt
      b.dataSurgeAngle = b.dataSurgeAngle + dt * 2
      if b.dataSurgeTimer <= 0 then
        b.dataSurgeActive = false
      end
    else
      b.dataSurgeTimer = b.dataSurgeTimer - dt
      if b.dataSurgeTimer <= 0 then
        b.dataSurgeActive = true
        b.dataSurgeTimer = 4  -- duration
        b.dataSurgeAngle = 0
      end
    end
  end

  -- Memory leak zones (phase 2+)
  if b.phase >= 2 then
    b.memoryLeakSpawnTimer = b.memoryLeakSpawnTimer - dt
    if b.memoryLeakSpawnTimer <= 0 and #b.memoryLeakZones < 4 then
      b.memoryLeakSpawnTimer = 5
      table.insert(b.memoryLeakZones, {
        x = math.random(100, screen.WIDTH - 100),
        y = math.random(250, screen.HEIGHT - 80),
        radius = 50 + math.random(0, 20),
        lifetime = 10,
        damageTimer = 0,
      })
    end
    for i = #b.memoryLeakZones, 1, -1 do
      local zone = b.memoryLeakZones[i]
      zone.lifetime = zone.lifetime - dt
      zone.damageTimer = zone.damageTimer - dt
      if zone.lifetime <= 0 then
        table.remove(b.memoryLeakZones, i)
      end
    end
  end

  -- Overclock slam (phase 3): full-width shockwave with one safe gap
  if b.phase >= 3 then
    if b.overclockCharging then
      b.overclockTimer = b.overclockTimer - dt
      if b.overclockTimer <= 0 then
        b.overclockCharging = false
        -- Fire the shockwave
        local safeX = math.random(100, screen.WIDTH - 100)
        table.insert(b.pendingProjectiles, {
          type = "overclockSlam",
          y = b.y + 60,
          damage = DAMAGE.overclockSlam,
          safeX = safeX,
          safeWidth = 80,
          speed = 350,
        })
        b.shouldAttack = true
        b.currentAttack = "overclockSlam"
      end
    end
  end

  -- Puzzle: memory address gates (phase 2+)
  M.updateRAMPuzzle(dt, playerX, playerY)
end

function M.updateRAMPuzzle(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end

  b.puzzleCooldown = b.puzzleCooldown - dt
  if not b.puzzleActive and b.puzzleCooldown <= 0 and not b.puzzleSolved then
    -- Start a new puzzle sequence
    b.puzzleActive = true
    b.puzzleIndex = 1
    b.puzzleTimer = 15  -- time limit
    b.puzzleSequence = {}
    b.puzzleGates = {}

    -- Generate 3-step color sequence
    local colors = {"red", "green", "blue", "gold"}
    for i = 1, 3 do
      table.insert(b.puzzleSequence, colors[math.random(1, 4)])
    end

    -- Place 4 colored gates the player can fly through
    local gateColors = {"red", "green", "blue", "gold"}
    for i, color in ipairs(gateColors) do
      table.insert(b.puzzleGates, {
        x = 100 + (i - 1) * ((screen.WIDTH - 200) / 3),
        y = screen.HEIGHT - 150,
        width = 50,
        height = 80,
        color = color,
        active = true,
      })
    end
  end

  if b.puzzleActive then
    b.puzzleTimer = b.puzzleTimer - dt
    if b.puzzleTimer <= 0 then
      -- Failed: reset puzzle
      b.puzzleActive = false
      b.puzzleCooldown = 20
      b.puzzleIndex = 1
    end
  end
end

-- Called from init.lua when player flies through a gate
function M.checkPuzzleGate(playerX, playerY, playerW, playerH)
  local b = M.boss
  if not b or not b.puzzleActive then return false end

  for _, gate in ipairs(b.puzzleGates) do
    if gate.active then
      local dx = math.abs(playerX - gate.x)
      local dy = math.abs(playerY - gate.y)
      if dx < (gate.width + playerW) / 2 and dy < (gate.height + playerH) / 2 then
        -- Player entered this gate
        local expected = b.puzzleSequence[b.puzzleIndex]
        if gate.color == expected then
          b.puzzleIndex = b.puzzleIndex + 1
          if b.puzzleIndex > #b.puzzleSequence then
            -- Puzzle solved! Stagger boss
            b.puzzleActive = false
            b.puzzleSolved = true
            b.puzzleStagger = true
            b.puzzleStaggerTimer = 4  -- 4 seconds of vulnerability
            b.puzzleCooldown = 30
            return true
          end
        else
          -- Wrong gate: reset sequence
          b.puzzleIndex = 1
        end
        return false
      end
    end
  end
  return false
end

------------------------------------------------------------------------
-- ACT II: SECTOR GAUNTLET  (phases 4-6)
------------------------------------------------------------------------

function M.updateSectorGauntlet(dt, playerX, playerY)
  local b = M.boss

  -- Seek arm sweep (Indiana Jones rolling boulder)
  if b.seekArmActive then
    b.seekArmX = b.seekArmX + b.seekArmSpeed * b.seekArmDir * dt
    if b.seekArmX > screen.WIDTH + 50 or b.seekArmX < -50 then
      b.seekArmActive = false
    end
  else
    b.seekArmTimer = b.seekArmTimer - dt
    local interval = 8
    if b.phase >= 5 then interval = 5.5 end
    if b.phase >= 6 then interval = 3.5 end
    if b.seekArmTimer <= 0 then
      b.seekArmActive = true
      b.seekArmDir = math.random() < 0.5 and 1 or -1
      b.seekArmX = b.seekArmDir > 0 and -50 or screen.WIDTH + 50
      b.seekArmSpeed = 250 + (b.phase - 4) * 50
      b.seekArmTimer = interval
    end
  end

  -- Bad sector zones (DOT areas)
  b.badSectorSpawnTimer = b.badSectorSpawnTimer - dt
  if b.badSectorSpawnTimer <= 0 and #b.badSectorZones < 5 then
    b.badSectorSpawnTimer = 4
    table.insert(b.badSectorZones, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(200, screen.HEIGHT - 100),
      radius = 45 + math.random(0, 25),
      lifetime = 12,
      damageTimer = 0,
    })
  end
  for i = #b.badSectorZones, 1, -1 do
    local zone = b.badSectorZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt
    if zone.lifetime <= 0 then
      table.remove(b.badSectorZones, i)
    end
  end

  -- Defrag beam (charged laser, phase 5+)
  if b.phase >= 5 then
    if b.defragCharging then
      b.defragTimer = b.defragTimer - dt
      if b.defragTimer <= 0 then
        b.defragCharging = false
        -- Fire the beam
        table.insert(b.pendingProjectiles, {
          type = "defragBeam",
          x = b.x,
          y = b.y + 60,
          targetX = b.defragTargetX,
          targetY = b.defragTargetY,
          damage = DAMAGE.defragBeam,
          width = 35,
          speed = 450,
        })
        b.shouldAttack = true
        b.currentAttack = "defragBeam"
      end
    end
  end

  -- Boulder sweep (phase 6): massive horizontal bar sweeps up/down
  if b.phase >= 6 then
    if b.boulderSweepActive then
      b.boulderSweepY = b.boulderSweepY + 300 * b.boulderSweepDir * dt
      if b.boulderSweepY > screen.HEIGHT + 30 or b.boulderSweepY < -30 then
        b.boulderSweepActive = false
      end
    else
      b.boulderSweepTimer = b.boulderSweepTimer - dt
      if b.boulderSweepTimer <= 0 then
        b.boulderSweepActive = true
        b.boulderSweepDir = math.random() < 0.5 and 1 or -1
        b.boulderSweepY = b.boulderSweepDir > 0 and -30 or screen.HEIGHT + 30
        b.boulderSweepTimer = 7
      end
    end
  end

  -- Sector puzzle
  M.updateSectorPuzzle(dt, playerX, playerY)
end

function M.updateSectorPuzzle(dt, playerX, playerY)
  local b = M.boss
  b.sectorPuzzleCooldown = b.sectorPuzzleCooldown - dt

  if not b.sectorPuzzleActive and b.sectorPuzzleCooldown <= 0 and not b.sectorPuzzleSolved then
    -- Create rotating ring puzzle: 4 segments, hit them in sequence
    b.sectorPuzzleActive = true
    b.sectorPuzzleIndex = 1
    b.sectorPuzzleRings = {}

    local colors = {"red", "blue", "green", "gold"}
    -- Shuffle order
    for i = #colors, 2, -1 do
      local j = math.random(1, i)
      colors[i], colors[j] = colors[j], colors[i]
    end

    for i = 1, 4 do
      table.insert(b.sectorPuzzleRings, {
        angle = (i - 1) * (math.pi / 2),
        color = colors[i],
        hit = false,
        radius = 150,
        rotSpeed = 0.8,
      })
    end
  end

  if b.sectorPuzzleActive then
    -- Rotate segments
    for _, ring in ipairs(b.sectorPuzzleRings) do
      ring.angle = ring.angle + ring.rotSpeed * dt
    end
  end
end

-- Called when player bullet hits a sector puzzle segment
function M.hitSectorPuzzleRing(color)
  local b = M.boss
  if not b or not b.sectorPuzzleActive then return false end

  local expected = b.sectorPuzzleRings[b.sectorPuzzleIndex]
  if expected and not expected.hit and expected.color == color then
    expected.hit = true
    b.sectorPuzzleIndex = b.sectorPuzzleIndex + 1
    if b.sectorPuzzleIndex > #b.sectorPuzzleRings then
      -- Puzzle complete! Stagger boss
      b.sectorPuzzleActive = false
      b.sectorPuzzleSolved = true
      b.puzzleStagger = true
      b.puzzleStaggerTimer = 5
      b.sectorPuzzleCooldown = 35
      return true
    end
  elseif expected and expected.color ~= color then
    -- Wrong order: reset all hits
    for _, ring in ipairs(b.sectorPuzzleRings) do
      ring.hit = false
    end
    b.sectorPuzzleIndex = 1
  end
  return false
end

------------------------------------------------------------------------
-- ACT III: THE CORE  (phases 7-10)
------------------------------------------------------------------------

function M.updateCore(dt, playerX, playerY)
  local b = M.boss

  -- Spin platters (environmental hazard)
  b.platterAngle = b.platterAngle + b.platterSpeed * dt
  if b.phase >= 9 then b.platterSpeed = 3.0 end
  if b.enraged then b.platterSpeed = 4.5 end

  for _, platter in ipairs(b.platters) do
    platter.angle = platter.angle + platter.speed * dt
    platter.gapAngle = platter.gapAngle + platter.speed * 0.3 * dt
  end

  -- Spindle lasers (rotating death beams from center)
  if b.phase >= 8 then
    b.spindleLaserActive = true
    local laserSpeed = 1.5
    if b.phase >= 9 then laserSpeed = 2.5 end
    if b.enraged then laserSpeed = 4.0 end
    b.spindleLaserAngle = b.spindleLaserAngle + laserSpeed * dt
    b.spindleLaserCount = b.phase >= 9 and 5 or 3
  end

  -- Head crash (dive-bomb, phase 8+)
  M.updateHeadCrash(dt, playerX, playerY)

  -- Magnetic pulse (phase 9+)
  M.updateMagneticPulse(dt)

  -- Thermal event (phase 10 ultimate)
  M.updateThermalEvent(dt, playerX, playerY)

  -- Gravity well (phase 8+)
  M.updateGravity(dt, playerX, playerY)

  -- Actuator arms (Indiana Jones swinging traps, phase 7+)
  M.updateActuatorArms(dt)

  -- Debris falling (phase 9+)
  M.updateDebris(dt)

  -- Core shield puzzle
  M.updateCoreShield(dt, playerX, playerY)
end

function M.updateHeadCrash(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 8 then return end

  if b.headCrashPhase == "idle" then
    b.headCrashTimer = b.headCrashTimer - dt
    local cooldown = 10
    if b.phase >= 9 then cooldown = 6 end
    if b.enraged then cooldown = 3.5 end
    if b.headCrashTimer <= 0 then
      b.headCrashPhase = "telegraphing"
      b.headCrashTimer = 1.5  -- telegraph duration
      b.headCrashTargetX = playerX
      b.headCrashTargetY = playerY
    end
  elseif b.headCrashPhase == "telegraphing" then
    b.headCrashTimer = b.headCrashTimer - dt
    -- Track player during telegraph
    b.headCrashTargetX = b.headCrashTargetX * 0.95 + playerX * 0.05
    b.headCrashTargetY = b.headCrashTargetY * 0.95 + playerY * 0.05
    if b.headCrashTimer <= 0 then
      b.headCrashPhase = "diving"
      b.headCrashActive = true
      b.headCrashTimer = 0.6  -- dive duration
    end
  elseif b.headCrashPhase == "diving" then
    -- Rush toward target
    local dx = b.headCrashTargetX - b.x
    local dy = b.headCrashTargetY - b.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 5 then
      local speed = 800
      b.x = b.x + (dx / dist) * speed * dt
      b.y = b.y + (dy / dist) * speed * dt
    end
    b.headCrashTimer = b.headCrashTimer - dt
    if b.headCrashTimer <= 0 then
      b.headCrashPhase = "recovering"
      b.headCrashTimer = 1.5
      -- Shockwave on impact
      table.insert(b.pendingProjectiles, {
        type = "headCrashShockwave",
        x = b.x,
        y = b.y,
        damage = DAMAGE.headCrash,
        radius = 100,
      })
      b.shouldAttack = true
      b.currentAttack = "headCrash"
    end
  elseif b.headCrashPhase == "recovering" then
    b.headCrashTimer = b.headCrashTimer - dt
    -- Float back up
    b.y = b.y + (b.targetY - b.y) * 2 * dt
    b.baseX = b.x
    if b.headCrashTimer <= 0 then
      b.headCrashPhase = "idle"
      b.headCrashActive = false
      b.headCrashTimer = 8
    end
  end
end

function M.updateMagneticPulse(dt)
  local b = M.boss
  if b.phase < 9 then return end

  if b.magneticPulseActive then
    b.magneticPulseRadius = b.magneticPulseRadius + 250 * dt
    if b.magneticPulseRadius > screen.WIDTH then
      b.magneticPulseActive = false
    end
  else
    b.magneticPulseTimer = b.magneticPulseTimer - dt
    if b.magneticPulseTimer <= 0 then
      b.magneticPulseActive = true
      b.magneticPulseRadius = 0
      b.magneticPulseTimer = b.enraged and 5 or 8
    end
  end
end

function M.updateThermalEvent(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 10 then return end

  if b.thermalCharging then
    b.thermalTimer = b.thermalTimer - dt
    if b.thermalTimer <= 0 then
      b.thermalCharging = false
      -- Fire the thermal blast everywhere except safe zone
      table.insert(b.pendingProjectiles, {
        type = "thermalEvent",
        x = b.x,
        y = b.y,
        damage = DAMAGE.thermalEvent,
        safeX = b.thermalSafeZone.x,
        safeY = b.thermalSafeZone.y,
        safeRadius = 60,
      })
      b.shouldAttack = true
      b.currentAttack = "thermalEvent"
    end
  end
end

function M.startThermalEvent(playerX, playerY)
  local b = M.boss
  b.thermalCharging = true
  b.thermalTimer = b.thermalDuration
  b.thermalTargetX = playerX
  b.thermalTargetY = playerY
  -- Safe zone appears at a random location away from boss
  b.thermalSafeZone = {
    x = math.random(150, screen.WIDTH - 150),
    y = math.random(300, screen.HEIGHT - 100),
  }
end

function M.updateGravity(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 8 then return end

  if b.gravityActive then
    b.gravityTimer = b.gravityTimer - dt
    b.gravityPullStrength = 180 + (b.phase * 25)
    if b.enraged then b.gravityPullStrength = b.gravityPullStrength * 1.5 end

    if b.gravityTimer <= 0 then
      b.gravityActive = false
      b.gravityCooldown = b.enraged and 5 or 9
    end
  else
    b.gravityCooldown = b.gravityCooldown - dt
    if b.gravityCooldown <= 0 and not b.headCrashActive and not b.thermalCharging then
      b.gravityActive = true
      b.gravityTimer = 3.5
    end
  end
end

function M.updateActuatorArms(dt)
  local b = M.boss
  for _, arm in ipairs(b.actuatorArms) do
    if b.phase >= 7 then
      arm.active = true
    end
    if arm.active then
      arm.angle = arm.angle + arm.speed * dt
    end
  end
end

function M.updateDebris(dt)
  local b = M.boss
  if b.phase < 9 then return end

  if not b.debrisActive then
    b.debrisTimer = b.debrisTimer - dt
    if b.debrisTimer <= 0 then
      b.debrisActive = true
      b.debrisTimer = b.enraged and 4 or 7
      -- Generate falling columns
      b.debrisColumns = {}
      local count = b.enraged and 6 or 4
      for i = 1, count do
        table.insert(b.debrisColumns, {
          x = math.random(80, screen.WIDTH - 80),
          y = -50,
          width = 30 + math.random(0, 20),
          speed = 200 + math.random(0, 100),
          active = true,
        })
      end
    end
  else
    local allDone = true
    for _, col in ipairs(b.debrisColumns) do
      if col.active then
        col.y = col.y + col.speed * dt
        if col.y > screen.HEIGHT + 50 then
          col.active = false
        else
          allDone = false
        end
      end
    end
    if allDone then
      b.debrisActive = false
      b.debrisTimer = b.enraged and 4 or 7
    end
  end
end

function M.updateCoreShield(dt, playerX, playerY)
  local b = M.boss
  if not b.coreShielded then return end

  -- Core shield is broken by dealing enough damage to it during Act III
  -- The shield absorbs hits until HP reaches 0, then exposes the core
  -- for massive bonus damage
end

------------------------------------------------------------------------
-- ATTACK STATE MACHINE
------------------------------------------------------------------------

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.headCrashPhase == "diving" or b.headCrashPhase == "telegraphing" then return end
  if b.thermalCharging or b.gravityActive then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1.0
  if b.phase >= 4 then attackSpeed = 1.2 end
  if b.phase >= 7 then attackSpeed = 1.5 end
  if b.enraged then attackSpeed = 2.0 end

  local baseCooldown = 2.8 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Simple aimed shots + RAM bolts
    M.fireAimedBurst(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: + data surges, memory leak zones
    if roll < 50 then
      M.fireAimedBurst(playerX, playerY)
    elseif roll < 80 then
      M.fireSpreadPattern(playerX, playerY)
    else
      b.dataSurgeActive = true
      b.dataSurgeTimer = 3
    end

  elseif b.phase == 3 then
    -- Phase 3: + overclock slam, teleport attacks
    if roll < 20 and not b.overclockCharging then
      b.overclockCharging = true
      b.overclockTimer = 2.0
    elseif roll < 50 then
      M.fireAimedBurst(playerX, playerY)
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: Sector sweep + seek arm
    if roll < 30 then
      M.fireSectorSweep(playerX, playerY)
    elseif roll < 60 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireAimedBurst(playerX, playerY)
    end

  elseif b.phase == 5 then
    -- Phase 5: + defrag beam
    if roll < 20 and not b.defragCharging then
      b.defragCharging = true
      b.defragTimer = 2.5
      b.defragTargetX = playerX
      b.defragTargetY = playerY
    elseif roll < 45 then
      M.fireSectorSweep(playerX, playerY)
    elseif roll < 70 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireAimedBurst(playerX, playerY)
    end

  elseif b.phase == 6 then
    -- Phase 6: + boulder sweep, combos
    b.comboCount = b.comboCount + 1
    if b.comboCount >= b.comboMax then
      b.comboCount = 0
      if not b.defragCharging then
        b.defragCharging = true
        b.defragTimer = 2.0
        b.defragTargetX = playerX
        b.defragTargetY = playerY
      end
    else
      if roll < 30 then
        M.fireSectorSweep(playerX, playerY)
      elseif roll < 60 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.fireAimedBurst(playerX, playerY)
      end
    end

  elseif b.phase == 7 then
    -- Phase 7: Core + spindle attacks
    if roll < 30 then
      M.fireSpindleBurst(playerX, playerY)
    elseif roll < 60 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireAimedBurst(playerX, playerY)
    end

  elseif b.phase == 8 then
    -- Phase 8: + head crash, gravity
    if roll < 15 and b.headCrashPhase == "idle" then
      b.headCrashPhase = "telegraphing"
      b.headCrashTimer = 1.5
      b.headCrashTargetX = playerX
      b.headCrashTargetY = playerY
    elseif roll < 40 then
      M.fireSpindleBurst(playerX, playerY)
    elseif roll < 70 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 9 then
    -- Phase 9: + magnetic pulse, debris
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      if roll < 50 and b.headCrashPhase == "idle" then
        b.headCrashPhase = "telegraphing"
        b.headCrashTimer = 1.2
        b.headCrashTargetX = playerX
        b.headCrashTargetY = playerY
      else
        M.fireSweepPattern(playerX, playerY)
      end
    else
      if roll < 30 then
        M.fireSpindleBurst(playerX, playerY)
      elseif roll < 55 then
        M.fireSweepPattern(playerX, playerY)
      else
        M.fireSpreadPattern(playerX, playerY)
      end
    end

  else
    -- Phase 10: CORE MELTDOWN - everything, combos, thermal events
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 2 then
      b.comboCount = 0
      if roll < 25 and not b.thermalCharging then
        M.startThermalEvent(playerX, playerY)
      elseif roll < 50 and b.headCrashPhase == "idle" then
        b.headCrashPhase = "telegraphing"
        b.headCrashTimer = 0.8
        b.headCrashTargetX = playerX
        b.headCrashTargetY = playerY
      else
        M.fireSweepPattern(playerX, playerY)
      end
    else
      if roll < 25 then
        M.fireSpindleBurst(playerX, playerY)
      elseif roll < 50 then
        M.fireSweepPattern(playerX, playerY)
      elseif roll < 75 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.fireAimedBurst(playerX, playerY)
      end
    end
    b.attackTimer = 0.7  -- Relentless in rage
  end
end

------------------------------------------------------------------------
-- PROJECTILE PATTERNS
------------------------------------------------------------------------

function M.fireAimedBurst(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.ramBolt
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Three aimed shots
  for i = -1, 1 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.2
    table.insert(b.pendingProjectiles, {
      type = "aimed",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 320,
      damage = damage,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "aimed"
end

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.sectorSweep
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  local count = b.enraged and 9 or 6
  for i = 1, count do
    local angle = math.pi / 2 + ((i - (count + 1) / 2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 280,
      damage = damage,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSectorSweep(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.sectorSweep
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Horizontal sweep of projectiles
  for i = 0, 7 do
    table.insert(b.pendingProjectiles, {
      type = "sectorSweep",
      x = b.x - 100 + i * 30,
      y = b.y + 60,
      angle = math.pi / 2 + (i - 3.5) * 0.08,
      speed = 300,
      damage = damage,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "sectorSweep"
end

function M.fireSpindleBurst(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.spindleLaser
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Ring burst from center
  local count = b.enraged and 16 or 10
  for i = 1, count do
    local angle = (i - 1) * (math.pi * 2 / count) + b.spindleLaserAngle
    table.insert(b.pendingProjectiles, {
      type = "spindleBurst",
      x = b.x,
      y = b.y,
      angle = angle,
      speed = 250,
      damage = damage,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "spindleBurst"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.magneticPulse
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Wide sweep beam (12 projectiles in sequence)
  for i = 0, 11 do
    local angle = math.pi / 2 - 0.7 + (i * 0.12)
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 380,
      damage = damage,
      delay = i * 0.06,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "sweep"
end

------------------------------------------------------------------------
-- DAMAGE INTERFACE
------------------------------------------------------------------------

function M.damage(amount)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Core shield absorbs in Act III (unless staggered or shield broken)
  if b.act == 3 and b.coreShielded and not b.puzzleStagger then
    b.coreShieldHP = b.coreShieldHP - amount
    if b.coreShieldHP <= 0 then
      b.coreShielded = false
      b.coreShieldHP = 0
    end
    return false
  end

  -- Bonus damage during stagger
  if b.puzzleStagger then
    amount = amount * 2
  end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

------------------------------------------------------------------------
-- ENVIRONMENT DAMAGE CHECKS (called from init.lua)
------------------------------------------------------------------------

-- Check if player is in a memory leak zone (Act I)
function M.checkMemoryLeakDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or b.act ~= 1 then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.memoryLeakZones) do
    local dx = playerX - zone.x
    local dy = playerY - zone.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
      zone.damageTimer = 0.5
      totalDamage = totalDamage + DAMAGE.memoryLeak
    end
  end
  return totalDamage
end

-- Check if player is in a bad sector zone (Act II)
function M.checkBadSectorDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or b.act ~= 2 then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.badSectorZones) do
    local dx = playerX - zone.x
    local dy = playerY - zone.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
      zone.damageTimer = 0.5
      totalDamage = totalDamage + DAMAGE.badSector
    end
  end
  return totalDamage
end

-- Check if player is hit by seek arm (Act II)
function M.checkSeekArmHit(playerX, playerY, playerW, playerH)
  local b = M.boss
  if not b or not b.seekArmActive then return 0 end

  -- Seek arm is a tall vertical bar at seekArmX
  if math.abs(playerX - b.seekArmX) < (30 + playerW) / 2 then
    return DAMAGE.seekArmCrush
  end
  return 0
end

-- Check if player is hit by boulder sweep (Act II)
function M.checkBoulderSweepHit(playerX, playerY, playerW, playerH)
  local b = M.boss
  if not b or not b.boulderSweepActive then return 0 end

  if math.abs(playerY - b.boulderSweepY) < (20 + playerH) / 2 then
    return DAMAGE.seekArmCrush
  end
  return 0
end

-- Check spindle laser hit (Act III)
function M.checkSpindleLaserHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.spindleLaserActive then return 0 end

  local cx, cy = b.x, b.y
  for i = 0, b.spindleLaserCount - 1 do
    local angle = b.spindleLaserAngle + i * (math.pi * 2 / b.spindleLaserCount)
    -- Line from center outward
    local len = 400
    local lx = cx + math.cos(angle) * len
    local ly = cy + math.sin(angle) * len

    -- Point-to-line distance
    local dx = lx - cx
    local dy = ly - cy
    local px = playerX - cx
    local py = playerY - cy
    local t = math.max(0, math.min(1, (px * dx + py * dy) / (dx * dx + dy * dy)))
    local closestX = cx + t * dx
    local closestY = cy + t * dy
    local distSq = (playerX - closestX) ^ 2 + (playerY - closestY) ^ 2

    if distSq < (playerRadius + 8) ^ 2 then
      return DAMAGE.spindleLaser
    end
  end
  return 0
end

-- Check magnetic pulse hit (Act III)
function M.checkMagneticPulseHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.magneticPulseActive then return 0 end

  local dist = math.sqrt((playerX - b.x) ^ 2 + (playerY - b.y) ^ 2)
  local ringWidth = 25
  if math.abs(dist - b.magneticPulseRadius) < (ringWidth + playerRadius) then
    return DAMAGE.magneticPulse
  end
  return 0
end

-- Check platter edge hit (Act III)
function M.checkPlatterHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or b.act ~= 3 then return 0 end

  local cx, cy = screen.WIDTH / 2, screen.HEIGHT / 2

  for _, platter in ipairs(b.platters) do
    local dist = math.sqrt((playerX - cx) ^ 2 + (playerY - cy) ^ 2)
    if math.abs(dist - platter.radius) < (platter.thickness + playerRadius) / 2 then
      -- Check if player is NOT in the gap
      local angle = math.atan2(playerY - cy, playerX - cx)
      local relAngle = (angle - platter.gapAngle) % (math.pi * 2)
      if relAngle > platter.gapSize then
        return DAMAGE.platterSpin
      end
    end
  end
  return 0
end

-- Check actuator arm hit (Act III)
function M.checkActuatorArmHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or b.act ~= 3 then return 0 end

  for _, arm in ipairs(b.actuatorArms) do
    if arm.active then
      local endX = arm.pivotX + math.cos(arm.angle) * arm.length
      local endY = arm.pivotY + math.sin(arm.angle) * arm.length

      -- Point-to-line segment distance
      local dx = endX - arm.pivotX
      local dy = endY - arm.pivotY
      local px = playerX - arm.pivotX
      local py = playerY - arm.pivotY
      local lenSq = dx * dx + dy * dy
      if lenSq > 0 then
        local t = math.max(0, math.min(1, (px * dx + py * dy) / lenSq))
        local closestX = arm.pivotX + t * dx
        local closestY = arm.pivotY + t * dy
        local distSq = (playerX - closestX) ^ 2 + (playerY - closestY) ^ 2
        if distSq < (playerRadius + 10) ^ 2 then
          return DAMAGE.seekArmCrush
        end
      end
    end
  end
  return 0
end

-- Check debris hit (Act III)
function M.checkDebrisHit(playerX, playerY, playerW, playerH)
  local b = M.boss
  if not b or not b.debrisActive then return 0 end

  for _, col in ipairs(b.debrisColumns) do
    if col.active then
      if math.abs(playerX - col.x) < (col.width + playerW) / 2 and
         math.abs(playerY - col.y) < (40 + playerH) / 2 then
        return DAMAGE.seekArmCrush
      end
    end
  end
  return 0
end

-- Check data surge hit (Act I)
function M.checkDataSurgeHit(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.dataSurgeActive then return 0 end

  -- Data surge is a horizontal beam sweeping vertically
  local surgeY = screen.HEIGHT / 2 + math.sin(b.dataSurgeAngle) * (screen.HEIGHT / 3)
  if math.abs(playerY - surgeY) < (15 + playerRadius) then
    return DAMAGE.dataSurge
  end
  return 0
end

------------------------------------------------------------------------
-- QUERY FUNCTIONS
------------------------------------------------------------------------

function M.getGravityPull()
  local b = M.boss
  if not b or not b.gravityActive then
    return 0, 0, 0
  end
  return b.x, b.y, b.gravityPullStrength
end

function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.thermalCharging then
    return "THERMAL EVENT", b.thermalTimer / b.thermalDuration
  elseif b.gravityActive then
    return "GRAVITY WELL", b.gravityTimer / 3.5
  elseif b.overclockCharging then
    return "OVERCLOCK SLAM", b.overclockTimer / 2.0
  elseif b.defragCharging then
    return "DEFRAG BEAM", b.defragTimer / 2.5
  elseif b.headCrashPhase == "telegraphing" then
    return "HEAD CRASH", b.headCrashTimer / 1.5
  elseif b.magneticPulseActive then
    return "MAGNETIC PULSE", 1 - (b.magneticPulseRadius / screen.WIDTH)
  end

  return nil
end

return M
