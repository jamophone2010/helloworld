-- raidboss.lua: "The Logician" - CPU Die Boss
-- Elden Ring style multi-phase boss fight on the CPU die itself.
-- Indiana Jones style obstacles: rolling capacitor boulders, collapsing traces,
-- pit traps (via holes opening beneath), dart-like projectile barrages.
-- Tron Legacy Lightcycles aesthetic: neon trails, disc attacks, derezzification.

local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- =============================================
-- DAMAGE VALUES (Elden Ring: punish mistakes hard)
-- =============================================
local DAMAGE = {
  discSlash      = 12,   -- Identity Disc throw (Phase 1)
  lightwall      = 8,    -- Lightcycle wall trail DOT (Phase 2)
  gridStrike     = 18,   -- Grid floor slam (Phase 3)
  boulderCrush   = 30,   -- Rolling capacitor boulder (Phase 4, Indiana Jones)
  dartBarrage    = 10,   -- Precision dart needles (Phase 5)
  derezBeam      = 20,   -- Derez beam sweep (Phase 6)
  pitTrap        = 15,   -- Via pit trap DOT (Phase 7)
  overclockPulse = 25,   -- Overclock EMP pulse (Phase 8)
  cacheFlood     = 14,   -- L1 Cache data flood (Phase 9)
  singularity    = 40,   -- Core meltdown singularity (Phase 10)
  threadLance    = 16,   -- Thread execution lance (all phases)
  pipelineBurst  = 22,   -- Pipeline burst (late phases)
}

-- Phase HP thresholds (out of 600 total - raid boss)
local PHASE_THRESHOLDS = {600, 540, 470, 400, 330, 260, 195, 135, 75, 30}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -200,
    width = 200,
    height = 160,
    health = 600,
    maxHealth = 600,
    score = 30000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 90,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport / Lightcycle Dash
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 6,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 90,
    fadeAlpha = 1,
    fadeIn = false,

    -- Lightcycle trail (Phase 2+)
    lightTrails = {},
    trailTimer = 0,
    trailActive = false,
    trailColor = {0, 0.9, 1},

    -- Attack state
    attackTimer = 3,
    attackPhase = 0,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Phase 1: Identity Disc (Tron disc throw)
    discActive = false,
    discX = 0, discY = 0,
    discAngle = 0,
    discReturning = false,
    discSpeed = 400,

    -- Phase 2: Lightcycle Walls
    lightWalls = {},
    wallSpawnTimer = 0,

    -- Phase 3: Grid Floor Slam (AoE zones)
    gridZones = {},
    gridSlamTimer = 0,

    -- Phase 4: Indiana Jones Boulders (rolling capacitor cylinders)
    boulders = {},
    boulderTimer = 0,

    -- Phase 5: Dart Barrage (precision needle projectiles)
    dartBarrageActive = false,
    dartCount = 0,
    dartMaxCount = 12,
    dartTimer = 0,

    -- Phase 6: Derez Beam (sweeping laser)
    derezBeamActive = false,
    derezBeamAngle = 0,
    derezBeamSweepDir = 1,
    derezBeamTimer = 0,

    -- Phase 7: Via Pit Traps
    pitTraps = {},
    pitSpawnTimer = 0,

    -- Phase 8: Overclock EMP Pulse
    overclockCharging = false,
    overclockTimer = 0,
    overclockDuration = 3,
    overclockRadius = 0,

    -- Phase 9: Cache Flood (data stream walls)
    cacheFloodActive = false,
    cacheStreams = {},
    cacheTimer = 0,

    -- Phase 10: Core Meltdown (everything intensifies)
    meltdownActive = false,
    meltdownTimer = 0,
    meltdownPulse = 0,

    -- Thread Execution Lances (persistent mechanic)
    threadLances = {},
    threadTimer = 0,

    -- Pipeline Burst (Phase 7+)
    pipelineCharging = false,
    pipelineTimer = 0,

    -- Gravity / Pull (Phase 8+)
    gravityActive = false,
    gravityTimer = 0,
    gravityCooldown = 10,
    gravityPullStrength = 0,

    -- Visual state
    coreGlow = 0,
    diePattern = {},

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during phase transitions
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Indiana Jones specific
    collapsingTraces = {},
    swingingBlades = {},
  }

  -- Generate die pattern (visual - looks like a real CPU die)
  M.generateDiePattern()
end

function M.generateDiePattern()
  local b = M.boss
  b.diePattern = {}
  -- Generate cache blocks, ALU regions, register files
  local regions = {
    {name = "L1$", x = -80, y = -60, w = 40, h = 30},
    {name = "L2$", x = -80, y = -20, w = 40, h = 40},
    {name = "ALU", x = -30, y = -50, w = 60, h = 40},
    {name = "FPU", x = -30, y = 0, w = 60, h = 30},
    {name = "REG", x = 40, y = -60, w = 40, h = 35},
    {name = "BPU", x = 40, y = -15, w = 40, h = 30},
    {name = "ROB", x = -80, y = 30, w = 55, h = 25},
    {name = "I/O", x = 40, y = 25, w = 40, h = 30},
    {name = "μOP", x = -15, y = 35, w = 45, h = 25},
  }
  for _, r in ipairs(regions) do
    table.insert(b.diePattern, r)
  end
end

function M.isActive()
  return M.boss ~= nil and M.boss.active
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

-- =============================================
-- UPDATE
-- =============================================

function M.update(dt, playerX, playerY)
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
    b.coreGlow = 1  -- Max glow during transition
    if b.transitionTimer <= 0 then
      b.phaseTransitioning = false
      M.onPhaseStart()
    end
    return
  end

  b.coreGlow = math.max(0, b.coreGlow - dt * 0.5)

  M.updatePhase()
  M.updateTeleport(dt, playerX, playerY)
  M.updateDisc(dt, playerX, playerY)
  M.updateLightTrails(dt)
  M.updateLightWalls(dt)
  M.updateGridZones(dt)
  M.updateBoulders(dt, playerX, playerY)
  M.updateDartBarrage(dt, playerX, playerY)
  M.updateDerezBeam(dt, playerX, playerY)
  M.updatePitTraps(dt)
  M.updateOverclock(dt, playerX, playerY)
  M.updateCacheFlood(dt, playerX, playerY)
  M.updateThreadLances(dt, playerX, playerY)
  M.updatePipeline(dt, playerX, playerY)
  M.updateGravity(dt, playerX, playerY)
  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
  M.updateIndyObstacles(dt)

  -- Meltdown visual
  if b.meltdownActive then
    b.meltdownPulse = b.meltdownPulse + dt * 8
  end
end

-- =============================================
-- PHASE MANAGEMENT
-- =============================================

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
    b.transitionTimer = 1.8
    b.coreGlow = 1

    -- Cancel active attacks on phase change
    b.discActive = false
    b.dartBarrageActive = false
    b.derezBeamActive = false
    b.overclockCharging = false
    b.cacheFloodActive = false
    b.pipelineCharging = false
    b.gravityActive = false
    b.trailActive = false

    -- Spawn Indiana Jones collapsing traces on later phase transitions
    if b.phase >= 4 then
      M.spawnCollapsingTraces()
    end
    if b.phase >= 6 then
      M.spawnSwingingBlades()
    end
  end
end

function M.onPhaseStart()
  local b = M.boss
  b.attackTimer = 1.5

  if b.phase == 10 then
    b.meltdownActive = true
  end
end

-- =============================================
-- MOVEMENT
-- =============================================

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end
  if b.dartBarrageActive or b.derezBeamActive then return end

  local speed = 1.2
  if b.phase >= 4 then speed = 1.8 end
  if b.phase >= 7 then speed = 2.5 end
  if b.phase >= 10 then speed = 3.5 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 120 + (b.phase * 15)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.7) * 25
  end
  if b.phase >= 8 then
    b.y = b.targetY + math.sin(b.moveAngle * 1.3) * 40
  end

  -- Leave lightcycle trail when moving in Phase 2+
  if b.phase >= 2 then
    b.trailTimer = b.trailTimer + dt
    if b.trailTimer > 0.05 then
      b.trailTimer = 0
      table.insert(b.lightTrails, {
        x = b.x,
        y = b.y + b.height/2,
        life = 2.0,
        maxLife = 2.0,
      })
    end
  end
end

-- =============================================
-- TELEPORT (Shadow Step / Lightcycle Rez-In)
-- =============================================

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 5
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true
      b.shouldAttack = true
      b.currentAttack = "rezIn"
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 5
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    local cooldown = b.teleportCooldown
    if b.phase >= 7 then cooldown = cooldown * 0.5 end
    if b.phase >= 10 then cooldown = cooldown * 0.3 end

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
  local dist = 100 + math.random() * 60
  b.teleportTargetX = math.max(100, math.min(screen.WIDTH - 100, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(200, playerY - 60 - math.random() * 40))
end

-- =============================================
-- PHASE 1: IDENTITY DISC (Tron disc throw)
-- =============================================

function M.updateDisc(dt, playerX, playerY)
  local b = M.boss
  if not b.discActive then return end

  b.discAngle = b.discAngle + dt * 15

  if not b.discReturning then
    -- Fly toward target
    local dx = playerX - b.discX
    local dy = playerY - b.discY
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 5 then
      b.discX = b.discX + (dx/dist) * b.discSpeed * dt
      b.discY = b.discY + (dy/dist) * b.discSpeed * dt
    end

    -- Switch to returning after a distance or near player
    if dist < 30 or (math.abs(b.discX - b.x) > 400) then
      b.discReturning = true
    end
  else
    -- Return to boss
    local dx = b.x - b.discX
    local dy = b.y - b.discY
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 20 then
      b.discX = b.discX + (dx/dist) * (b.discSpeed * 1.3) * dt
      b.discY = b.discY + (dy/dist) * (b.discSpeed * 1.3) * dt
    else
      b.discActive = false
    end
  end

  -- Disc projectile
  table.insert(b.pendingProjectiles, {
    type = "disc",
    x = b.discX,
    y = b.discY,
    damage = DAMAGE.discSlash,
    radius = 18,
  })
end

function M.startDisc(playerX, playerY)
  local b = M.boss
  b.discActive = true
  b.discX = b.x
  b.discY = b.y + 30
  b.discReturning = false
  b.discAngle = 0
  b.discSpeed = 350 + b.phase * 20
end

-- =============================================
-- PHASE 2: LIGHTCYCLE WALLS (Tron light trails)
-- =============================================

function M.updateLightWalls(dt)
  local b = M.boss
  if b.phase < 2 then return end

  -- Spawn walls periodically
  b.wallSpawnTimer = b.wallSpawnTimer - dt
  local wallRate = b.phase >= 8 and 3 or 5

  if b.wallSpawnTimer <= 0 and #b.lightWalls < 4 then
    b.wallSpawnTimer = wallRate
    M.spawnLightWall()
  end

  -- Update walls
  for i = #b.lightWalls, 1, -1 do
    local wall = b.lightWalls[i]
    wall.lifetime = wall.lifetime - dt
    wall.glowPhase = wall.glowPhase + dt * 4

    if wall.lifetime <= 0 then
      table.remove(b.lightWalls, i)
    end
  end
end

function M.spawnLightWall()
  local b = M.boss
  local wallType = math.random(3)

  if wallType == 1 then
    -- Horizontal wall
    table.insert(b.lightWalls, {
      x1 = math.random(50, screen.WIDTH/2 - 50),
      y1 = math.random(200, screen.HEIGHT - 100),
      x2 = math.random(screen.WIDTH/2 + 50, screen.WIDTH - 50),
      y2 = 0,  -- set below
      horizontal = true,
      lifetime = 5 + math.random() * 3,
      glowPhase = 0,
      damage = DAMAGE.lightwall,
    })
    b.lightWalls[#b.lightWalls].y2 = b.lightWalls[#b.lightWalls].y1
  elseif wallType == 2 then
    -- Vertical wall
    local wx = math.random(100, screen.WIDTH - 100)
    table.insert(b.lightWalls, {
      x1 = wx, y1 = 150,
      x2 = wx, y2 = screen.HEIGHT - 50,
      horizontal = false,
      lifetime = 4 + math.random() * 3,
      glowPhase = 0,
      damage = DAMAGE.lightwall,
    })
  else
    -- Diagonal wall
    table.insert(b.lightWalls, {
      x1 = math.random(50, screen.WIDTH/3),
      y1 = math.random(200, screen.HEIGHT/2),
      x2 = math.random(screen.WIDTH*2/3, screen.WIDTH - 50),
      y2 = math.random(screen.HEIGHT/2, screen.HEIGHT - 50),
      horizontal = false,
      lifetime = 4 + math.random() * 2,
      glowPhase = 0,
      damage = DAMAGE.lightwall,
    })
  end
end

-- =============================================
-- PHASE 3: GRID FLOOR SLAM (AoE zones)
-- =============================================

function M.updateGridZones(dt)
  local b = M.boss
  if b.phase < 3 then return end

  b.gridSlamTimer = b.gridSlamTimer - dt
  local slamRate = b.phase >= 8 and 2.5 or 4

  if b.gridSlamTimer <= 0 and #b.gridZones < 6 then
    b.gridSlamTimer = slamRate
    -- Telegraph then damage
    table.insert(b.gridZones, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(250, screen.HEIGHT - 80),
      radius = 50 + math.random(30),
      telegraphTimer = 1.2,
      damageTimer = 0,
      lifetime = 3,
      damage = DAMAGE.gridStrike,
      active = false,  -- becomes active after telegraph
    })
  end

  for i = #b.gridZones, 1, -1 do
    local zone = b.gridZones[i]
    if zone.telegraphTimer > 0 then
      zone.telegraphTimer = zone.telegraphTimer - dt
      if zone.telegraphTimer <= 0 then
        zone.active = true
      end
    else
      zone.lifetime = zone.lifetime - dt
      zone.damageTimer = zone.damageTimer - dt
    end
    if zone.lifetime <= 0 then
      table.remove(b.gridZones, i)
    end
  end
end

-- =============================================
-- PHASE 4: INDIANA JONES BOULDERS
-- (Rolling capacitor cylinders across the screen)
-- =============================================

function M.updateBoulders(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  b.boulderTimer = b.boulderTimer - dt
  local boulderRate = b.phase >= 8 and 3 or 5

  if b.boulderTimer <= 0 then
    b.boulderTimer = boulderRate
    M.spawnBoulder()
  end

  for i = #b.boulders, 1, -1 do
    local boulder = b.boulders[i]
    boulder.x = boulder.x + boulder.vx * dt
    boulder.y = boulder.y + boulder.vy * dt
    boulder.rotation = boulder.rotation + boulder.rotSpeed * dt

    -- Remove if off screen
    if boulder.x < -100 or boulder.x > screen.WIDTH + 100 or
       boulder.y < -100 or boulder.y > screen.HEIGHT + 100 then
      table.remove(b.boulders, i)
    end
  end
end

function M.spawnBoulder()
  local b = M.boss
  local side = math.random(4)
  local boulder = {
    radius = 25 + math.random(15),
    rotation = 0,
    rotSpeed = 3 + math.random() * 4,
    damage = DAMAGE.boulderCrush,
    -- Visual: looks like a rolling capacitor
    colorBands = math.random(2, 4),
  }

  if side == 1 then -- from left
    boulder.x = -50
    boulder.y = math.random(200, screen.HEIGHT - 100)
    boulder.vx = 120 + math.random() * 80
    boulder.vy = (math.random() - 0.5) * 60
  elseif side == 2 then -- from right
    boulder.x = screen.WIDTH + 50
    boulder.y = math.random(200, screen.HEIGHT - 100)
    boulder.vx = -(120 + math.random() * 80)
    boulder.vy = (math.random() - 0.5) * 60
  elseif side == 3 then -- from top
    boulder.x = math.random(100, screen.WIDTH - 100)
    boulder.y = -50
    boulder.vx = (math.random() - 0.5) * 80
    boulder.vy = 100 + math.random() * 60
  else -- diagonal
    boulder.x = math.random() > 0.5 and -50 or (screen.WIDTH + 50)
    boulder.y = -50
    boulder.vx = boulder.x < 0 and (100 + math.random() * 50) or -(100 + math.random() * 50)
    boulder.vy = 80 + math.random() * 60
  end

  table.insert(b.boulders, boulder)
end

-- =============================================
-- PHASE 5: DART BARRAGE (precision needles)
-- =============================================

function M.updateDartBarrage(dt, playerX, playerY)
  local b = M.boss
  if not b.dartBarrageActive then return end

  b.dartTimer = b.dartTimer - dt
  if b.dartTimer <= 0 and b.dartCount < b.dartMaxCount then
    b.dartCount = b.dartCount + 1
    b.dartTimer = 0.12

    -- Fire precision darts at player with slight spread
    local spread = (math.random() - 0.5) * 0.3
    local angle = math.atan2(playerY - b.y, playerX - b.x) + spread
    table.insert(b.pendingProjectiles, {
      type = "dart",
      x = b.x,
      y = b.y + 60,
      angle = angle,
      speed = 450,
      damage = DAMAGE.dartBarrage,
    })
    b.shouldAttack = true
    b.currentAttack = "dartBarrage"
  end

  if b.dartCount >= b.dartMaxCount then
    b.dartBarrageActive = false
  end
end

function M.startDartBarrage()
  local b = M.boss
  b.dartBarrageActive = true
  b.dartCount = 0
  b.dartTimer = 0.5  -- Wind-up
  b.dartMaxCount = b.phase >= 9 and 18 or 12
end

-- =============================================
-- PHASE 6: DEREZ BEAM (sweeping laser)
-- =============================================

function M.updateDerezBeam(dt, playerX, playerY)
  local b = M.boss
  if not b.derezBeamActive then return end

  b.derezBeamTimer = b.derezBeamTimer - dt
  b.derezBeamAngle = b.derezBeamAngle + b.derezBeamSweepDir * dt * 1.5

  -- Clamp sweep range
  if b.derezBeamAngle > math.pi * 0.8 then
    b.derezBeamSweepDir = -1
  elseif b.derezBeamAngle < math.pi * 0.2 then
    b.derezBeamSweepDir = 1
  end

  if b.derezBeamTimer <= 0 then
    b.derezBeamActive = false
  end
end

function M.startDerezBeam()
  local b = M.boss
  b.derezBeamActive = true
  b.derezBeamAngle = math.pi * 0.3
  b.derezBeamSweepDir = 1
  b.derezBeamTimer = 3 + (b.phase >= 9 and 2 or 0)
end

-- =============================================
-- PHASE 7: VIA PIT TRAPS (holes open in floor)
-- =============================================

function M.updatePitTraps(dt)
  local b = M.boss
  if b.phase < 7 then return end

  b.pitSpawnTimer = b.pitSpawnTimer - dt
  local spawnRate = b.phase >= 9 and 2.5 or 4

  if b.pitSpawnTimer <= 0 and #b.pitTraps < 5 then
    b.pitSpawnTimer = spawnRate
    table.insert(b.pitTraps, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(300, screen.HEIGHT - 80),
      radius = 35 + math.random(20),
      openTimer = 0.8,  -- Warning before fully open
      lifetime = 4,
      damage = DAMAGE.pitTrap,
      damageTimer = 0,
      open = false,
    })
  end

  for i = #b.pitTraps, 1, -1 do
    local pit = b.pitTraps[i]
    if pit.openTimer > 0 then
      pit.openTimer = pit.openTimer - dt
      if pit.openTimer <= 0 then
        pit.open = true
      end
    else
      pit.lifetime = pit.lifetime - dt
      pit.damageTimer = pit.damageTimer - dt
    end
    if pit.lifetime <= 0 then
      table.remove(b.pitTraps, i)
    end
  end
end

-- =============================================
-- PHASE 8: OVERCLOCK EMP PULSE
-- =============================================

function M.updateOverclock(dt, playerX, playerY)
  local b = M.boss
  if not b.overclockCharging then return end

  b.overclockTimer = b.overclockTimer - dt
  b.overclockRadius = (1 - b.overclockTimer / b.overclockDuration) * 400

  if b.overclockTimer <= 0 then
    b.overclockCharging = false
    b.overclockRadius = 0
    -- The damage is dealt when the pulse reaches the player (checked externally)
  end
end

function M.startOverclock()
  local b = M.boss
  b.overclockCharging = true
  b.overclockTimer = b.overclockDuration
  b.overclockRadius = 0
end

-- =============================================
-- PHASE 9: CACHE FLOOD (data stream walls)
-- =============================================

function M.updateCacheFlood(dt, playerX, playerY)
  local b = M.boss
  if not b.cacheFloodActive then return end

  b.cacheTimer = b.cacheTimer - dt

  -- Spawn data streams that scroll across
  if math.random() < dt * 3 then
    local horizontal = math.random() > 0.5
    table.insert(b.cacheStreams, {
      x = horizontal and -50 or math.random(80, screen.WIDTH - 80),
      y = horizontal and math.random(200, screen.HEIGHT - 80) or -50,
      vx = horizontal and (200 + math.random() * 100) or 0,
      vy = horizontal and 0 or (180 + math.random() * 80),
      width = horizontal and 300 or 15,
      height = horizontal and 15 or 250,
      damage = DAMAGE.cacheFlood,
      life = 3,
    })
  end

  -- Update streams
  for i = #b.cacheStreams, 1, -1 do
    local stream = b.cacheStreams[i]
    stream.x = stream.x + stream.vx * dt
    stream.y = stream.y + stream.vy * dt
    stream.life = stream.life - dt
    if stream.life <= 0 or stream.x > screen.WIDTH + 100 or stream.y > screen.HEIGHT + 100 then
      table.remove(b.cacheStreams, i)
    end
  end

  if b.cacheTimer <= 0 then
    b.cacheFloodActive = false
    b.cacheStreams = {}
  end
end

function M.startCacheFlood()
  local b = M.boss
  b.cacheFloodActive = true
  b.cacheTimer = 5
  b.cacheStreams = {}
end

-- =============================================
-- THREAD EXECUTION LANCES (persistent, all phases)
-- =============================================

function M.updateThreadLances(dt, playerX, playerY)
  local b = M.boss

  b.threadTimer = b.threadTimer - dt
  local lanceRate = 3 - (b.phase * 0.15)
  if lanceRate < 1 then lanceRate = 1 end

  if b.threadTimer <= 0 then
    b.threadTimer = lanceRate
    -- Fire thread lance (fast, narrow projectile)
    local angle = math.atan2(playerY - b.y, playerX - b.x)
    table.insert(b.pendingProjectiles, {
      type = "threadLance",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 380,
      damage = DAMAGE.threadLance,
    })
  end
end

-- =============================================
-- PIPELINE BURST (Phase 7+)
-- =============================================

function M.updatePipeline(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 7 then return end

  if b.pipelineCharging then
    b.pipelineTimer = b.pipelineTimer - dt
    if b.pipelineTimer <= 0 then
      b.pipelineCharging = false
      -- Fire pipeline burst: ring of projectiles
      local count = b.phase >= 9 and 16 or 12
      for i = 1, count do
        local angle = (i / count) * math.pi * 2
        table.insert(b.pendingProjectiles, {
          type = "pipelineBurst",
          x = b.x,
          y = b.y,
          angle = angle,
          speed = 280,
          damage = DAMAGE.pipelineBurst,
        })
      end
      b.shouldAttack = true
      b.currentAttack = "pipelineBurst"
    end
  end
end

function M.startPipeline()
  local b = M.boss
  b.pipelineCharging = true
  b.pipelineTimer = 1.5
end

-- =============================================
-- GRAVITY PULL (Phase 8+)
-- =============================================

function M.updateGravity(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 8 then return end

  if b.gravityActive then
    b.gravityTimer = b.gravityTimer - dt
    b.gravityPullStrength = 180 + (b.phase * 25)

    if b.gravityTimer <= 0 then
      b.gravityActive = false
      b.gravityCooldown = b.phase >= 10 and 6 or 10
    end
  else
    b.gravityCooldown = b.gravityCooldown - dt
    if b.gravityCooldown <= 0 and not b.overclockCharging and not b.cacheFloodActive then
      b.gravityActive = true
      b.gravityTimer = 3.5
    end
  end
end

-- =============================================
-- LIGHT TRAIL (Tron Lightcycle)
-- =============================================

function M.updateLightTrails(dt)
  local b = M.boss
  for i = #b.lightTrails, 1, -1 do
    local trail = b.lightTrails[i]
    trail.life = trail.life - dt
    if trail.life <= 0 then
      table.remove(b.lightTrails, i)
    end
  end
end

-- =============================================
-- INDIANA JONES OBSTACLES
-- =============================================

function M.spawnCollapsingTraces()
  local b = M.boss
  -- Traces that collapse after a warning, leaving gaps
  for i = 1, 3 do
    table.insert(b.collapsingTraces, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(300, screen.HEIGHT - 100),
      width = 80 + math.random(60),
      warningTimer = 2,
      collapseTimer = 1.5,
      collapsed = false,
      damage = 12,
    })
  end
end

function M.spawnSwingingBlades()
  local b = M.boss
  -- Pendulum blades that swing across the screen (like Temple of Doom)
  for i = 1, 2 do
    table.insert(b.swingingBlades, {
      pivotX = math.random(200, screen.WIDTH - 200),
      pivotY = 150,
      length = 180 + math.random(60),
      angle = math.random() * math.pi,
      speed = 2 + math.random() * 1.5,
      bladeWidth = 20,
      damage = 18,
      lifetime = 15,
    })
  end
end

function M.updateIndyObstacles(dt)
  local b = M.boss

  -- Update collapsing traces
  for i = #b.collapsingTraces, 1, -1 do
    local trace = b.collapsingTraces[i]
    if trace.warningTimer > 0 then
      trace.warningTimer = trace.warningTimer - dt
    elseif not trace.collapsed then
      trace.collapseTimer = trace.collapseTimer - dt
      if trace.collapseTimer <= 0 then
        trace.collapsed = true
      end
    else
      -- Remove after collapse animation
      trace.collapseTimer = trace.collapseTimer - dt
      if trace.collapseTimer < -2 then
        table.remove(b.collapsingTraces, i)
      end
    end
  end

  -- Update swinging blades
  for i = #b.swingingBlades, 1, -1 do
    local blade = b.swingingBlades[i]
    blade.angle = blade.angle + blade.speed * dt
    blade.lifetime = blade.lifetime - dt
    if blade.lifetime <= 0 then
      table.remove(b.swingingBlades, i)
    end
  end
end

-- =============================================
-- ATTACK SELECTION (Elden Ring style)
-- =============================================

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.dartBarrageActive or b.derezBeamActive or b.overclockCharging or b.cacheFloodActive then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 5 then attackSpeed = 1.3 end
  if b.phase >= 8 then attackSpeed = 1.6 end
  if b.phase >= 10 then attackSpeed = 2.0 end

  local baseCooldown = 2.5 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Identity Disc only
    M.startDisc(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: Disc + Teleport
    if roll < 60 then
      M.startDisc(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: + Grid Slam
    if roll < 40 then
      M.startDisc(playerX, playerY)
    elseif roll < 70 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: + Boulders (Indiana Jones)
    if roll < 30 then
      M.startDisc(playerX, playerY)
    elseif roll < 55 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 75 then
      M.spawnBoulder()
      M.spawnBoulder()  -- Double boulder!
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 5 then
    -- Phase 5: + Dart Barrage
    if roll < 25 then
      M.startDartBarrage()
    elseif roll < 45 then
      M.startDisc(playerX, playerY)
    elseif roll < 70 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 6 then
    -- Phase 6: + Derez Beam
    if roll < 20 then
      M.startDerezBeam()
    elseif roll < 40 then
      M.startDartBarrage()
    elseif roll < 60 then
      M.startDisc(playerX, playerY)
    elseif roll < 80 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 7 then
    -- Phase 7: + Pit Traps + Pipeline Burst
    if roll < 15 then
      M.startPipeline()
    elseif roll < 30 then
      M.startDerezBeam()
    elseif roll < 45 then
      M.startDartBarrage()
    elseif roll < 60 then
      M.startDisc(playerX, playerY)
    elseif roll < 80 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 8 then
    -- Phase 8: + Overclock EMP + Gravity
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      M.startOverclock()
    else
      if roll < 20 then
        M.startPipeline()
      elseif roll < 35 then
        M.startDerezBeam()
      elseif roll < 50 then
        M.startDartBarrage()
      elseif roll < 65 then
        M.startDisc(playerX, playerY)
      elseif roll < 85 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.startTeleport(playerX, playerY)
      end
    end

  elseif b.phase == 9 then
    -- Phase 9: + Cache Flood
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 4 then
      b.comboCount = 0
      if math.random() > 0.5 then
        M.startCacheFlood()
      else
        M.startOverclock()
      end
    else
      if roll < 15 then
        M.startPipeline()
      elseif roll < 30 then
        M.startDerezBeam()
      elseif roll < 45 then
        M.startDartBarrage()
      elseif roll < 60 then
        M.startDisc(playerX, playerY)
      elseif roll < 80 then
        M.fireSweepPattern(playerX, playerY)
      else
        M.startTeleport(playerX, playerY)
      end
    end

  else
    -- Phase 10: CORE MELTDOWN - all attacks, faster, combos
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 2 then
      b.comboCount = 0
      local bigRoll = math.random(4)
      if bigRoll == 1 then M.startOverclock()
      elseif bigRoll == 2 then M.startCacheFlood()
      elseif bigRoll == 3 then M.startDerezBeam()
      else M.startPipeline()
      end
    else
      if roll < 20 then
        M.startDartBarrage()
      elseif roll < 40 then
        M.startDisc(playerX, playerY)
      elseif roll < 60 then
        M.fireSweepPattern(playerX, playerY)
      elseif roll < 80 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.startTeleport(playerX, playerY)
      end
    end
    b.attackTimer = 0.7  -- Relentless
  end
end

-- =============================================
-- PROJECTILE PATTERNS
-- =============================================

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local count = 5 + math.floor(b.phase / 2)
  for i = 1, count do
    local angle = math.pi/2 + ((i - (count+1)/2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 60,
      angle = angle,
      speed = 300,
      damage = DAMAGE.threadLance,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  for i = 0, 11 do
    local angle = math.pi/2 - 0.7 + (i * 0.13)
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 60,
      angle = angle,
      speed = 380,
      damage = DAMAGE.threadLance,
    })
  end
  b.shouldAttack = true
  b.currentAttack = "sweep"
end

-- =============================================
-- DAMAGE
-- =============================================

function M.damage(amount)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  b.health = b.health - amount
  b.coreGlow = math.min(1, b.coreGlow + 0.3)

  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- =============================================
-- EXTERNAL QUERIES
-- =============================================

function M.getGravityPull()
  local b = M.boss
  if not b or not b.gravityActive then
    return 0, 0, 0
  end
  return b.x, b.y, b.gravityPullStrength
end

function M.checkGridZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.gridZones) do
    if zone.active then
      local dx = playerX - zone.x
      local dy = playerY - zone.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
        zone.damageTimer = 0.5
        totalDamage = totalDamage + zone.damage
      end
    end
  end

  return totalDamage
end

function M.checkLightWallDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, wall in ipairs(b.lightWalls) do
    -- Point-to-line-segment distance
    local dx = wall.x2 - wall.x1
    local dy = wall.y2 - wall.y1
    local len2 = dx*dx + dy*dy
    if len2 > 0 then
      local t = math.max(0, math.min(1, ((playerX - wall.x1)*dx + (playerY - wall.y1)*dy) / len2))
      local nearX = wall.x1 + t * dx
      local nearY = wall.y1 + t * dy
      local dist = math.sqrt((playerX - nearX)^2 + (playerY - nearY)^2)
      if dist < playerRadius + 8 then
        totalDamage = totalDamage + wall.damage
      end
    end
  end

  return totalDamage
end

function M.checkBoulderDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, boulder in ipairs(b.boulders) do
    local dist = math.sqrt((playerX - boulder.x)^2 + (playerY - boulder.y)^2)
    if dist < boulder.radius + playerRadius then
      totalDamage = totalDamage + boulder.damage
    end
  end

  return totalDamage
end

function M.checkPitTrapDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, pit in ipairs(b.pitTraps) do
    if pit.open and pit.damageTimer <= 0 then
      local dist = math.sqrt((playerX - pit.x)^2 + (playerY - pit.y)^2)
      if dist < pit.radius + playerRadius then
        pit.damageTimer = 0.4
        totalDamage = totalDamage + pit.damage
      end
    end
  end

  return totalDamage
end

function M.checkOverclockDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.overclockCharging then return 0 end

  local dist = math.sqrt((playerX - b.x)^2 + (playerY - b.y)^2)
  local innerEdge = math.max(0, b.overclockRadius - 30)
  if dist > innerEdge and dist < b.overclockRadius + playerRadius then
    return DAMAGE.overclockPulse
  end
  return 0
end

function M.checkCacheFloodDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.cacheFloodActive then return 0 end

  local totalDamage = 0
  for _, stream in ipairs(b.cacheStreams) do
    if playerX > stream.x - stream.width/2 - playerRadius and
       playerX < stream.x + stream.width/2 + playerRadius and
       playerY > stream.y - stream.height/2 - playerRadius and
       playerY < stream.y + stream.height/2 + playerRadius then
      totalDamage = totalDamage + stream.damage
    end
  end

  return totalDamage
end

function M.checkDerezBeamDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.derezBeamActive then return 0 end

  -- Beam is a line from boss extending at derezBeamAngle
  local beamLen = screen.HEIGHT
  local bx = b.x + math.cos(b.derezBeamAngle) * beamLen
  local by = b.y + math.sin(b.derezBeamAngle) * beamLen

  -- Point to line distance
  local dx = bx - b.x
  local dy = by - b.y
  local len2 = dx*dx + dy*dy
  if len2 > 0 then
    local t = math.max(0, math.min(1, ((playerX - b.x)*dx + (playerY - b.y)*dy) / len2))
    local nearX = b.x + t * dx
    local nearY = b.y + t * dy
    local dist = math.sqrt((playerX - nearX)^2 + (playerY - nearY)^2)
    if dist < playerRadius + 12 then
      return DAMAGE.derezBeam
    end
  end

  return 0
end

function M.checkBladeCollision(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, blade in ipairs(b.swingingBlades) do
    -- Blade tip position
    local tipX = blade.pivotX + math.sin(blade.angle) * blade.length
    local tipY = blade.pivotY + math.cos(blade.angle) * blade.length

    -- Check along blade length
    for t = 0.3, 1.0, 0.1 do
      local bx = blade.pivotX + math.sin(blade.angle) * blade.length * t
      local by = blade.pivotY + math.cos(blade.angle) * blade.length * t
      local dist = math.sqrt((playerX - bx)^2 + (playerY - by)^2)
      if dist < playerRadius + blade.bladeWidth/2 then
        totalDamage = totalDamage + blade.damage
        break
      end
    end
  end

  return totalDamage
end

function M.checkDiscDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.discActive then return 0 end

  local dist = math.sqrt((playerX - b.discX)^2 + (playerY - b.discY)^2)
  if dist < 18 + playerRadius then
    return DAMAGE.discSlash
  end
  return 0
end

function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.overclockCharging then
    return "OVERCLOCK EMP", b.overclockTimer / b.overclockDuration
  elseif b.derezBeamActive then
    return "DEREZ BEAM", b.derezBeamTimer / (3 + (b.phase >= 9 and 2 or 0))
  elseif b.dartBarrageActive and b.dartCount == 0 then
    return "DART BARRAGE", 1
  elseif b.cacheFloodActive then
    return "CACHE FLOOD", b.cacheTimer / 5
  elseif b.pipelineCharging then
    return "PIPELINE BURST", b.pipelineTimer / 1.5
  elseif b.gravityActive then
    return "GRAVITY WELL", b.gravityTimer / 3.5
  end

  return nil
end

-- =============================================
-- DRAWING
-- =============================================

function M.draw()
  local b = M.boss
  if not b or not b.active then return end

  local time = love.timer.getTime()
  local alpha = b.fadeAlpha or 1

  -- Draw light trails first (behind everything)
  M.drawLightTrails()

  -- Draw hazard zones
  M.drawGridZones()
  M.drawLightWallsVisual()
  M.drawBoulders()
  M.drawPitTraps()
  M.drawOverclockVisual()
  M.drawCacheFloodVisual()
  M.drawDerezBeamVisual()
  M.drawIndyObstacles()

  -- Draw boss body
  love.graphics.push()
  love.graphics.translate(b.x, b.y)

  -- === CPU DIE BODY ===
  -- Die substrate (dark silicon)
  love.graphics.setColor(0.04 * alpha, 0.04 * alpha, 0.06 * alpha, alpha)
  love.graphics.rectangle("fill", -b.width/2, -b.height/2, b.width, b.height)

  -- Die edge (gold bond pads)
  love.graphics.setColor(0.7 * alpha, 0.55 * alpha, 0.15 * alpha, alpha * 0.6)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", -b.width/2, -b.height/2, b.width, b.height)

  -- Bond pads along edges
  for i = 0, 12 do
    local padSize = 4
    local t = i / 12
    -- Top edge
    love.graphics.rectangle("fill", -b.width/2 + 8 + t * (b.width - 20), -b.height/2 - 2, padSize, padSize)
    -- Bottom edge
    love.graphics.rectangle("fill", -b.width/2 + 8 + t * (b.width - 20), b.height/2 - 2, padSize, padSize)
    -- Left edge
    love.graphics.rectangle("fill", -b.width/2 - 2, -b.height/2 + 8 + t * (b.height - 20), padSize, padSize)
    -- Right edge
    love.graphics.rectangle("fill", b.width/2 - 2, -b.height/2 + 8 + t * (b.height - 20), padSize, padSize)
  end

  -- Die regions (internal blocks - looks like a real die shot)
  local phaseColors = {
    {0, 0.8, 1},      -- Phase 1: Tron cyan
    {0, 0.9, 1},      -- Phase 2: Bright cyan
    {1, 0.5, 0},      -- Phase 3: Orange
    {1, 0.7, 0},      -- Phase 4: Gold
    {1, 0.2, 0.3},    -- Phase 5: Red
    {0.8, 0.2, 1},    -- Phase 6: Purple
    {1, 0.4, 0},      -- Phase 7: Dark orange
    {0.2, 0.4, 1},    -- Phase 8: Blue
    {1, 0.1, 0.1},    -- Phase 9: Crimson
    {1, 1, 0.3},      -- Phase 10: White-gold (meltdown)
  }
  local phaseColor = phaseColors[b.phase] or phaseColors[1]

  for _, region in ipairs(b.diePattern) do
    -- Region block (functional unit)
    local blockPulse = 0.15 + math.sin(time * 2 + region.x * 0.1) * 0.08
    love.graphics.setColor(phaseColor[1] * blockPulse * alpha,
                           phaseColor[2] * blockPulse * alpha,
                           phaseColor[3] * blockPulse * alpha, alpha * 0.7)
    love.graphics.rectangle("fill", region.x, region.y, region.w, region.h)

    -- Region border (Tron glow)
    local borderGlow = 0.3 + math.sin(time * 3 + region.y * 0.05) * 0.2
    love.graphics.setColor(phaseColor[1] * alpha, phaseColor[2] * alpha, phaseColor[3] * alpha, borderGlow * alpha)
    love.graphics.rectangle("line", region.x, region.y, region.w, region.h)

    -- Region label
    love.graphics.setColor(phaseColor[1] * alpha, phaseColor[2] * alpha, phaseColor[3] * alpha, 0.4 * alpha)
    love.graphics.setFont(love.graphics.newFont(7))
    love.graphics.printf(region.name, region.x, region.y + region.h/2 - 4, region.w, "center")
  end

  -- Internal interconnect traces
  love.graphics.setColor(phaseColor[1] * alpha, phaseColor[2] * alpha, phaseColor[3] * alpha, 0.15 * alpha)
  love.graphics.setLineWidth(1)
  for i = 1, 8 do
    local tx = -b.width/2 + 15 + (i / 9) * (b.width - 30)
    love.graphics.line(tx, -b.height/2 + 5, tx, b.height/2 - 5)
  end
  for i = 1, 6 do
    local ty = -b.height/2 + 15 + (i / 7) * (b.height - 30)
    love.graphics.line(-b.width/2 + 5, ty, b.width/2 - 5, ty)
  end

  -- === CENTRAL CORE (main damage point) ===
  local corePulse = 0.5 + math.sin(time * 5) * 0.3
  if b.phase >= 10 then
    corePulse = 0.3 + math.abs(math.sin(time * 12)) * 0.7
  end

  -- Core glow (outer)
  love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3],
                         (corePulse * 0.3 + b.coreGlow * 0.4) * alpha)
  love.graphics.circle("fill", 0, 0, 45)

  -- Core ring
  love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3], corePulse * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", 0, 0, 35)

  -- Core inner
  love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3], (corePulse * 0.8 + 0.2) * alpha)
  love.graphics.circle("fill", 0, 0, 20)

  -- Core white hot center
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, (0.5 + b.coreGlow * 0.5) * alpha)
  love.graphics.circle("fill", 0, 0, 10)

  -- Phase transition glow
  if b.phaseTransitioning then
    local transGlow = math.abs(math.sin(time * 10))
    love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3], transGlow * 0.6 * alpha)
    love.graphics.circle("fill", 0, 0, 80)
  end

  -- Meltdown effect (Phase 10)
  if b.meltdownActive then
    local meltPulse = math.abs(math.sin(b.meltdownPulse))
    love.graphics.setColor(1, 0.3, 0, meltPulse * 0.4 * alpha)
    love.graphics.circle("fill", 0, 0, 100 + meltPulse * 30)

    -- Sparking
    for i = 1, 4 do
      local sx = math.sin(time * 7 + i) * 70
      local sy = math.cos(time * 5 + i * 1.5) * 50
      love.graphics.setColor(1, 1, 0.5, meltPulse * 0.8)
      love.graphics.circle("fill", sx, sy, 3)
    end
  end

  love.graphics.pop()

  -- Draw disc (if active)
  M.drawDisc()

  -- Draw gravity indicator
  M.drawGravityVisual()

  -- Draw attack warning
  M.drawAttackWarning()

  -- Draw health bar
  M.drawHealthBar()
end

-- =============================================
-- VISUAL SUB-DRAWS
-- =============================================

function M.drawLightTrails()
  local b = M.boss
  local phaseColors = {
    {0, 0.9, 1}, {0, 0.9, 1}, {1, 0.55, 0}, {1, 0.7, 0}, {1, 0.3, 0.3},
    {0.8, 0.2, 1}, {1, 0.4, 0}, {0.3, 0.5, 1}, {1, 0.1, 0.1}, {1, 1, 0.3}
  }
  local trailColor = phaseColors[b.phase] or phaseColors[1]

  for _, trail in ipairs(b.lightTrails) do
    local alpha = trail.life / trail.maxLife
    -- Outer glow
    love.graphics.setColor(trailColor[1], trailColor[2], trailColor[3], alpha * 0.2)
    love.graphics.circle("fill", trail.x, trail.y, 8)
    -- Core
    love.graphics.setColor(trailColor[1], trailColor[2], trailColor[3], alpha * 0.6)
    love.graphics.circle("fill", trail.x, trail.y, 3)
  end
end

function M.drawGridZones()
  local b = M.boss
  local time = love.timer.getTime()

  for _, zone in ipairs(b.gridZones) do
    if zone.telegraphTimer > 0 then
      -- Telegraph (warning circle)
      local warnAlpha = 0.3 + math.sin(time * 8) * 0.2
      love.graphics.setColor(1, 0.3, 0, warnAlpha)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", zone.x, zone.y, zone.radius)
      love.graphics.setColor(1, 0.3, 0, warnAlpha * 0.2)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      love.graphics.setLineWidth(1)
    elseif zone.active then
      -- Active damage zone (Tron grid)
      local gridPulse = 0.4 + math.sin(time * 6) * 0.2
      love.graphics.setColor(1, 0.5, 0, gridPulse * 0.5)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      love.graphics.setColor(1, 0.8, 0.2, gridPulse)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", zone.x, zone.y, zone.radius)

      -- Grid lines inside
      love.graphics.setColor(1, 0.7, 0, gridPulse * 0.3)
      for gx = zone.x - zone.radius, zone.x + zone.radius, 15 do
        love.graphics.line(gx, zone.y - zone.radius, gx, zone.y + zone.radius)
      end
      love.graphics.setLineWidth(1)
    end
  end
end

function M.drawLightWallsVisual()
  local b = M.boss
  local time = love.timer.getTime()

  local phaseColors = {
    {0, 0.9, 1}, {0, 0.9, 1}, {1, 0.55, 0}, {1, 0.7, 0}, {1, 0.3, 0.3},
    {0.8, 0.2, 1}, {1, 0.4, 0}, {0.3, 0.5, 1}, {1, 0.1, 0.1}, {1, 1, 0.3}
  }
  local wallColor = phaseColors[b.phase] or phaseColors[1]

  for _, wall in ipairs(b.lightWalls) do
    local wallPulse = 0.6 + math.sin(wall.glowPhase) * 0.3

    -- Glow
    love.graphics.setColor(wallColor[1], wallColor[2], wallColor[3], wallPulse * 0.15)
    love.graphics.setLineWidth(12)
    love.graphics.line(wall.x1, wall.y1, wall.x2, wall.y2)

    -- Core line
    love.graphics.setColor(wallColor[1], wallColor[2], wallColor[3], wallPulse * 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.line(wall.x1, wall.y1, wall.x2, wall.y2)

    -- Hot center
    love.graphics.setColor(1, 1, 1, wallPulse * 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(wall.x1, wall.y1, wall.x2, wall.y2)

    love.graphics.setLineWidth(1)
  end
end

function M.drawBoulders()
  local b = M.boss
  local time = love.timer.getTime()

  for _, boulder in ipairs(b.boulders) do
    love.graphics.push()
    love.graphics.translate(boulder.x, boulder.y)
    love.graphics.rotate(boulder.rotation)

    -- Capacitor body (cylindrical rolled look)
    love.graphics.setColor(0.08, 0.08, 0.12, 0.9)
    love.graphics.circle("fill", 0, 0, boulder.radius)

    -- Capacitor bands
    for i = 1, boulder.colorBands do
      local bandAngle = (i / boulder.colorBands) * math.pi * 2
      local bx = math.cos(bandAngle) * boulder.radius * 0.5
      local by = math.sin(bandAngle) * boulder.radius * 0.5
      love.graphics.setColor(0.5, 0.3, 0.1, 0.6)
      love.graphics.circle("fill", bx, by, boulder.radius * 0.3)
    end

    -- Neon outline (Tron)
    love.graphics.setColor(1, 0.5, 0, 0.6 + math.sin(time * 4 + boulder.rotation) * 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, boulder.radius)

    -- Danger glow
    love.graphics.setColor(1, 0.3, 0, 0.15)
    love.graphics.circle("fill", 0, 0, boulder.radius + 8)

    love.graphics.setLineWidth(1)
    love.graphics.pop()
  end
end

function M.drawPitTraps()
  local b = M.boss
  local time = love.timer.getTime()

  for _, pit in ipairs(b.pitTraps) do
    if pit.openTimer > 0 then
      -- Warning phase (cracking)
      local crackAlpha = 0.3 + math.sin(time * 10) * 0.3
      love.graphics.setColor(1, 0.2, 0, crackAlpha)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", pit.x, pit.y, pit.radius)
      -- Crack lines
      for i = 1, 4 do
        local ca = (i / 4) * math.pi * 2 + time
        love.graphics.line(pit.x, pit.y,
          pit.x + math.cos(ca) * pit.radius * 0.7,
          pit.y + math.sin(ca) * pit.radius * 0.7)
      end
      love.graphics.setLineWidth(1)
    elseif pit.open then
      -- Open pit (via hole - dark void)
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.circle("fill", pit.x, pit.y, pit.radius)

      -- Via ring
      love.graphics.setColor(0.6, 0.3, 0, 0.6)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", pit.x, pit.y, pit.radius)

      -- Inner glow
      love.graphics.setColor(1, 0.2, 0, 0.3 + math.sin(time * 4) * 0.2)
      love.graphics.circle("line", pit.x, pit.y, pit.radius * 0.5)
      love.graphics.setLineWidth(1)
    end
  end
end

function M.drawOverclockVisual()
  local b = M.boss
  if not b.overclockCharging then return end
  local time = love.timer.getTime()

  -- Expanding EMP ring
  local ringAlpha = 0.5 + math.sin(time * 8) * 0.3
  love.graphics.setColor(0.2, 0.5, 1, ringAlpha * 0.3)
  love.graphics.circle("fill", b.x, b.y, b.overclockRadius)

  love.graphics.setColor(0.3, 0.7, 1, ringAlpha)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", b.x, b.y, b.overclockRadius)
  love.graphics.circle("line", b.x, b.y, b.overclockRadius * 0.7)
  love.graphics.setLineWidth(1)

  -- Charging sparks at boss
  love.graphics.setColor(0.5, 0.8, 1, ringAlpha)
  for i = 1, 6 do
    local sa = time * 5 + i
    local sr = 30 + math.sin(time * 8 + i) * 15
    love.graphics.circle("fill", b.x + math.cos(sa) * sr, b.y + math.sin(sa) * sr, 3)
  end
end

function M.drawCacheFloodVisual()
  local b = M.boss
  if not b.cacheFloodActive then return end
  local time = love.timer.getTime()

  for _, stream in ipairs(b.cacheStreams) do
    -- Data stream visualization (binary text)
    love.graphics.setColor(0, 0.8, 0.2, 0.4)
    love.graphics.rectangle("fill", stream.x - stream.width/2, stream.y - stream.height/2,
                            stream.width, stream.height)

    -- Neon border
    love.graphics.setColor(0, 1, 0.3, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", stream.x - stream.width/2, stream.y - stream.height/2,
                            stream.width, stream.height)
    love.graphics.setLineWidth(1)

    -- Binary text inside (decorative)
    love.graphics.setColor(0, 1, 0.3, 0.5)
    love.graphics.setFont(love.graphics.newFont(8))
    local binaryStr = "10110010"
    love.graphics.printf(binaryStr, stream.x - stream.width/2, stream.y - 4, stream.width, "center")
  end
end

function M.drawDerezBeamVisual()
  local b = M.boss
  if not b.derezBeamActive then return end
  local time = love.timer.getTime()

  local beamLen = screen.HEIGHT * 1.5
  local bx = b.x + math.cos(b.derezBeamAngle) * beamLen
  local by = b.y + math.sin(b.derezBeamAngle) * beamLen

  -- Beam glow
  love.graphics.setColor(0.8, 0.2, 1, 0.15)
  love.graphics.setLineWidth(24)
  love.graphics.line(b.x, b.y + 40, bx, by)

  -- Beam core
  love.graphics.setColor(0.9, 0.3, 1, 0.6 + math.sin(time * 10) * 0.3)
  love.graphics.setLineWidth(6)
  love.graphics.line(b.x, b.y + 40, bx, by)

  -- White center
  love.graphics.setColor(1, 1, 1, 0.4)
  love.graphics.setLineWidth(2)
  love.graphics.line(b.x, b.y + 40, bx, by)

  love.graphics.setLineWidth(1)

  -- Derez particles along beam
  for i = 0, 10 do
    local t = i / 10
    local px = b.x + (bx - b.x) * t
    local py = (b.y + 40) + (by - b.y - 40) * t
    if px > 0 and px < screen.WIDTH and py > 0 and py < screen.HEIGHT then
      love.graphics.setColor(0.9, 0.3, 1, 0.3 + math.sin(time * 8 + i) * 0.2)
      local sx = (math.random() - 0.5) * 20
      local sy = (math.random() - 0.5) * 20
      love.graphics.rectangle("fill", px + sx - 2, py + sy - 2, 4, 4)
    end
  end
end

function M.drawIndyObstacles()
  local b = M.boss
  local time = love.timer.getTime()

  -- Collapsing traces
  for _, trace in ipairs(b.collapsingTraces) do
    if trace.warningTimer > 0 then
      -- Warning: flashing trace about to collapse
      local warnAlpha = 0.3 + math.sin(time * 8) * 0.3
      love.graphics.setColor(1, 0.8, 0, warnAlpha)
      love.graphics.rectangle("fill", trace.x - trace.width/2, trace.y - 4, trace.width, 8)
      love.graphics.setColor(1, 0.3, 0, warnAlpha)
      love.graphics.setFont(love.graphics.newFont(8))
      love.graphics.printf("WARNING", trace.x - trace.width/2, trace.y - 16, trace.width, "center")
    elseif not trace.collapsed then
      -- Crumbling animation
      local crumble = trace.collapseTimer / 1.5
      love.graphics.setColor(0.5, 0.3, 0, crumble)
      for i = 0, 5 do
        local sx = trace.x - trace.width/2 + (i / 5) * trace.width
        local sy = trace.y + (1 - crumble) * math.random(-10, 10)
        love.graphics.rectangle("fill", sx, sy, trace.width/6, 6)
      end
    end
  end

  -- Swinging blades (Temple of Doom pendulums)
  for _, blade in ipairs(b.swingingBlades) do
    local tipX = blade.pivotX + math.sin(blade.angle) * blade.length
    local tipY = blade.pivotY + math.cos(blade.angle) * blade.length

    -- Blade glow
    love.graphics.setColor(1, 0.2, 0.1, 0.15)
    love.graphics.setLineWidth(blade.bladeWidth)
    love.graphics.line(blade.pivotX, blade.pivotY, tipX, tipY)

    -- Blade core
    love.graphics.setColor(0.8, 0.15, 0.05, 0.8)
    love.graphics.setLineWidth(blade.bladeWidth * 0.5)
    love.graphics.line(blade.pivotX, blade.pivotY, tipX, tipY)

    -- Neon edge
    love.graphics.setColor(1, 0.3, 0, 0.6 + math.sin(time * 5) * 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(blade.pivotX, blade.pivotY, tipX, tipY)

    -- Pivot
    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    love.graphics.circle("fill", blade.pivotX, blade.pivotY, 6)

    love.graphics.setLineWidth(1)
  end
end

function M.drawDisc()
  local b = M.boss
  if not b or not b.discActive then return end
  local time = love.timer.getTime()

  love.graphics.push()
  love.graphics.translate(b.discX, b.discY)
  love.graphics.rotate(b.discAngle)

  -- Disc glow
  love.graphics.setColor(0, 0.9, 1, 0.3)
  love.graphics.circle("fill", 0, 0, 22)

  -- Disc outer ring
  love.graphics.setColor(0, 0.9, 1, 0.9)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", 0, 0, 18)

  -- Disc inner
  love.graphics.setColor(1, 1, 1, 0.5)
  love.graphics.circle("fill", 0, 0, 8)

  -- Disc cross
  love.graphics.setColor(0, 0.9, 1, 0.7)
  love.graphics.line(-18, 0, 18, 0)
  love.graphics.line(0, -18, 0, 18)

  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

function M.drawGravityVisual()
  local b = M.boss
  if not b or not b.gravityActive then return end
  local time = love.timer.getTime()

  local wellPulse = 0.3 + math.abs(math.sin(time * 4)) * 0.4
  love.graphics.setColor(0.3, 0.2, 0.8, wellPulse * 0.2)
  love.graphics.circle("fill", b.x, b.y, 200)
  love.graphics.setColor(0.4, 0.3, 1, wellPulse * 0.5)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", b.x, b.y, 180)
  love.graphics.circle("line", b.x, b.y, 120)
  love.graphics.circle("line", b.x, b.y, 60)
  love.graphics.setLineWidth(1)
end

function M.drawAttackWarning()
  local warning, progress = M.getAttackWarning()
  if not warning then return end

  love.graphics.setColor(1, 0.2, 0.2, 0.8)
  love.graphics.setFont(love.graphics.newFont(16))
  love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")

  -- Warning bar
  love.graphics.setColor(0.3, 0.1, 0.1, 0.8)
  love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200, 10)
  love.graphics.setColor(1, 0.3, 0.1)
  love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200 * progress, 10)
end

function M.drawHealthBar()
  local b = M.boss
  if not b then return end

  local healthPct = b.health / b.maxHealth
  local barWidth = 350
  local barX = screen.WIDTH/2 - barWidth/2
  local barY = 30

  local phaseColors = {
    {0, 0.8, 1},      {0, 0.9, 1},      {1, 0.5, 0},
    {1, 0.7, 0},      {1, 0.2, 0.3},    {0.8, 0.2, 1},
    {1, 0.4, 0},      {0.2, 0.4, 1},    {1, 0.1, 0.1},
    {1, 1, 0.3},
  }

  -- Background
  love.graphics.setColor(0.06, 0.06, 0.08, 0.9)
  love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, 18)

  -- Health segments (10 phases)
  for i = 1, 10 do
    local segStart = (i - 1) / 10
    local segEnd = i / 10
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local pc = phaseColors[i]
      love.graphics.setColor(pc[1], pc[2], pc[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 14)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 10) * barWidth - 1, barY, 2, 14)
  end

  -- Border
  love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
  love.graphics.rectangle("line", barX - 2, barY - 2, barWidth + 4, 18)

  -- Phase indicator
  love.graphics.setColor(1, 0.8, 0.4)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. b.phase .. "/10", barX, barY + 16, barWidth, "center")

  -- Boss name
  local bossName = "THE LOGICIAN"
  if b.phase >= 10 then bossName = "THE LOGICIAN — CORE MELTDOWN" end
  love.graphics.setColor(0, 0.9, 1)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(bossName, barX, barY - 22, barWidth, "center")
end

return M
