-- Distant Dynamo: Power Supply Overlord
-- 8-phase Elden Ring style boss with Indiana Jones obstacles
-- Theme: Flying through power supply cables to the PSU box at the end
-- Orange color scheme throughout
local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- Phase damage values (Elden Ring style - punishing but fair)
local DAMAGE = {
  cableWhip = 10,          -- Phase 1: Sweeping cable lash arcs
  surgeStrike = 14,        -- Phase 2: Electrical surge bolts
  capacitorTrap = 9,       -- Phase 3: Capacitor field DOT per tick
  inductorSpin = 16,       -- Phase 4: Spinning inductor blades
  arcFlash = 20,           -- Phase 5: Arc flash bursts (Indiana Jones boulder equivalent)
  shortCircuit = 12,       -- Phase 6: Short circuit chain lightning
  overloadPulse = 30,      -- Phase 7: Overload pulse wave
  meltdown = 22,           -- Phase 8: Total meltdown - everything at once
}

-- Phase HP thresholds (out of 400 total, 8 phases)
local PHASE_THRESHOLDS = {400, 360, 310, 255, 200, 145, 85, 35}

-- Cable obstacle definitions (Indiana Jones style)
local CABLE_TYPES = {
  horizontal = {damage = 8, speed = 120, width = screen.WIDTH * 0.7},
  swinging = {damage = 10, speed = 0, radius = 150},
  sparking = {damage = 15, speed = 80, width = 200},
  crushing = {damage = 25, speed = 200, width = 100},
}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -180,
    width = 170,
    height = 130,
    health = 400,
    maxHealth = 400,
    score = 20000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 90,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Phase Shift / Power Reroute)
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 5.5,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 90,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack states
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,
    comboChain = 0,

    -- Phase 1: Cable Whip - sweeping cable lash arcs
    cableWhipActive = false,
    cableAngle = 0,
    cableSweeps = 0,

    -- Phase 2: Surge Strike - electrical surge bolts
    surgeChains = {},
    surgeTimer = 0,

    -- Phase 3: Capacitor Trap - trapping electrified zones
    capacitorZones = {},
    capacitorSpawnTimer = 0,

    -- Phase 4: Inductor Spin - spinning blade hazards (Indiana Jones style)
    inductorBlades = {},
    inductorTimer = 0,
    inductorCooldown = 6,

    -- Phase 5: Arc Flash - massive rolling energy waves (boulder run!)
    arcFlashActive = false,
    arcFlashTimer = 0,
    arcFlashCooldown = 10,
    arcFlashWaves = {},

    -- Phase 6: Short Circuit - branching chain lightning
    shortCircuitActive = false,
    shortCircuitNodes = {},
    shortCircuitTimer = 0,

    -- Phase 7: Overload Pulse - expanding shockwave rings
    overloadCharging = false,
    overloadTimer = 0,
    overloadDuration = 2.0,
    overloadPulses = {},

    -- Phase 8: Meltdown - enraged mode, everything faster
    enraged = false,
    rageMultiplier = 1.7,
    meltdownPulse = 0,
    meltdownSparks = {},

    -- Cable obstacles (Indiana Jones style - persist throughout fight)
    cables = {},
    cableSpawnTimer = 0,
    cableSpawnRate = 4.0,

    -- Puzzle mechanics: Circuit breaker switches
    circuitBreakers = {},
    breakerSpawnTimer = 0,
    breakersActive = false,
    breakersSolved = 0,
    breakerSequence = {},
    breakerCurrentIndex = 0,
    puzzleActive = false,
    puzzleCooldown = 25,
    puzzleTimer = 0,
    vulnerableFromPuzzle = false,
    vulnerableTimer = 0,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Shield arms (power regulator nodes - must destroy to expose core)
    leftRegulator = {health = 40, x = -65, destroyed = false},
    rightRegulator = {health = 40, x = 65, destroyed = false},
    regulatorsDown = false,

    -- Gravity/magnet pull (Phase 5+)
    magnetActive = false,
    magnetTimer = 0,
    magnetCooldown = 8,
    magnetPullStrength = 0,
  }
end

function M.isActive()
  return M.boss ~= nil and M.boss.active
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

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

  M.updatePhase()
  M.updateTeleport(dt, playerX, playerY)
  M.updateCapacitorZones(dt)
  M.updateInductorBlades(dt, playerX, playerY)
  M.updateArcFlash(dt, playerX, playerY)
  M.updateShortCircuit(dt, playerX, playerY)
  M.updateOverload(dt, playerX, playerY)
  M.updateCables(dt, playerX, playerY)
  M.updatePuzzle(dt, playerX, playerY)
  M.updateMagnet(dt, playerX, playerY)
  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
  M.updateMeltdownSparks(dt)
end

function M.updatePhase()
  local b = M.boss
  local oldPhase = b.phase

  for i = 8, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      b.phase = i
      break
    end
  end

  if b.phase > oldPhase then
    b.phaseTransitioning = true
    b.transitionTimer = 1.8
    -- Cancel active attacks
    b.cableWhipActive = false
    b.surgeChains = {}
    b.arcFlashActive = false
    b.shortCircuitActive = false
    b.overloadCharging = false
    b.overloadPulses = {}
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 8 then
    b.enraged = true
    b.cableSpawnRate = 1.5  -- Cables come much faster in meltdown
  end

  -- Spawn puzzle at certain phase transitions
  if b.phase == 3 or b.phase == 5 or b.phase == 7 then
    M.startPuzzle()
  end

  -- Reset attack timer
  b.attackTimer = 1.2
end

-- ==================== MOVEMENT ====================

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end

  local speed = 1.3
  if b.phase >= 4 then speed = 2.2 end
  if b.phase >= 6 then speed = 2.8 end
  if b.enraged then speed = 3.5 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 130 + (b.phase * 22)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Vertical bob in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.7) * 30
  end
  if b.phase >= 6 then
    b.y = b.targetY + math.sin(b.moveAngle * 1.2) * 45
  end

  -- Meltdown pulse in phase 8
  if b.enraged then
    b.meltdownPulse = b.meltdownPulse + dt * 10
  end
end

-- ==================== TELEPORT ====================

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 4
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      -- Strike on reappear
      if b.phase >= 2 then
        b.shouldAttack = true
        b.currentAttack = "surgeStrike"
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
  local dist = 140
  b.teleportTargetX = math.max(100, math.min(screen.WIDTH - 100, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(220, playerY - 100))
end

-- ==================== CAPACITOR TRAP ZONES (Phase 3+) ====================

function M.updateCapacitorZones(dt)
  local b = M.boss
  if b.phase < 3 then return end

  b.capacitorSpawnTimer = b.capacitorSpawnTimer - dt
  local spawnRate = b.enraged and 2.0 or 4.0
  local maxZones = b.enraged and 6 or 4

  if b.capacitorSpawnTimer <= 0 and #b.capacitorZones < maxZones then
    b.capacitorSpawnTimer = spawnRate
    table.insert(b.capacitorZones, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(200, screen.HEIGHT - 100),
      radius = 50 + math.random(0, 20),
      lifetime = b.enraged and 5 or 7,
      damage = DAMAGE.capacitorTrap,
      damageTimer = 0,
      pulsePhase = math.random() * math.pi * 2,
      sparkAngle = math.random() * math.pi * 2,
    })
  end

  for i = #b.capacitorZones, 1, -1 do
    local zone = b.capacitorZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt
    zone.sparkAngle = zone.sparkAngle + dt * 3

    if zone.lifetime <= 0 then
      table.remove(b.capacitorZones, i)
    end
  end
end

-- ==================== INDUCTOR BLADES (Phase 4+ - Indiana Jones spinning blades) ====================

function M.updateInductorBlades(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  -- Update existing blades
  for i = #b.inductorBlades, 1, -1 do
    local blade = b.inductorBlades[i]
    blade.timer = blade.timer - dt
    blade.angle = blade.angle + blade.rotSpeed * dt

    -- Move blade toward player slowly (like a rolling boulder)
    local dx = playerX - blade.x
    local dy = playerY - blade.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 1 then
      blade.x = blade.x + (dx / dist) * blade.moveSpeed * dt
      blade.y = blade.y + (dy / dist) * blade.moveSpeed * dt
    end

    -- Blade fires sparks periodically
    blade.sparkTimer = blade.sparkTimer - dt
    if blade.sparkTimer <= 0 then
      blade.sparkTimer = b.enraged and 0.8 or 1.5
      local sparkAngle = math.atan2(playerY - blade.y, playerX - blade.x)
      table.insert(b.pendingProjectiles, {
        type = "spread",
        x = blade.x,
        y = blade.y,
        angle = sparkAngle,
        speed = 250,
        damage = DAMAGE.inductorSpin,
      })
    end

    if blade.timer <= 0 then
      table.remove(b.inductorBlades, i)
    end
  end

  -- Spawn new blades
  b.inductorTimer = b.inductorTimer - dt
  if b.inductorTimer <= 0 and #b.inductorBlades < (b.enraged and 4 or 2) then
    b.inductorTimer = b.enraged and 3 or b.inductorCooldown
    local spawnSide = math.random(1, 4)
    local sx, sy
    if spawnSide == 1 then     -- Left
      sx, sy = 50, math.random(100, 400)
    elseif spawnSide == 2 then -- Right
      sx, sy = screen.WIDTH - 50, math.random(100, 400)
    elseif spawnSide == 3 then -- Top
      sx, sy = math.random(100, screen.WIDTH - 100), 80
    else                       -- Behind boss
      sx, sy = b.x + (math.random() - 0.5) * 200, b.y + 30
    end
    table.insert(b.inductorBlades, {
      x = sx,
      y = sy,
      angle = 0,
      rotSpeed = 4 + math.random() * 3,
      moveSpeed = 40 + math.random() * 30,
      timer = 8,
      radius = 30 + math.random(0, 15),
      sparkTimer = 1.0,
    })
  end
end

-- ==================== ARC FLASH (Phase 5+ - Indiana Jones boulder run) ====================

function M.updateArcFlash(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then return end

  -- Update existing waves
  for i = #b.arcFlashWaves, 1, -1 do
    local wave = b.arcFlashWaves[i]
    wave.y = wave.y + wave.speed * dt
    wave.lifetime = wave.lifetime - dt
    wave.pulsePhase = wave.pulsePhase + dt * 8

    if wave.lifetime <= 0 or wave.y > screen.HEIGHT + 50 then
      table.remove(b.arcFlashWaves, i)
    end
  end

  -- Spawn arc flash waves (rolling energy walls - dodge or die!)
  b.arcFlashTimer = b.arcFlashTimer - dt
  local cooldown = b.enraged and 4 or b.arcFlashCooldown

  if b.arcFlashTimer <= 0 then
    b.arcFlashTimer = cooldown

    -- Spawn a series of waves with gaps (must find the gap!)
    local gapCount = b.enraged and 1 or 2
    local segmentWidth = screen.WIDTH / 6
    local gaps = {}

    for g = 1, gapCount do
      gaps[math.random(1, 6)] = true
    end

    for seg = 1, 6 do
      if not gaps[seg] then
        table.insert(b.arcFlashWaves, {
          x = (seg - 1) * segmentWidth,
          y = b.y + 60,
          width = segmentWidth,
          height = 25,
          speed = 180 + (b.phase * 15),
          damage = DAMAGE.arcFlash,
          lifetime = 5,
          pulsePhase = 0,
        })
      end
    end
  end
end

-- ==================== SHORT CIRCUIT (Phase 6+ - chain lightning) ====================

function M.updateShortCircuit(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 6 then return end

  -- Update existing nodes
  for i = #b.shortCircuitNodes, 1, -1 do
    local node = b.shortCircuitNodes[i]
    node.timer = node.timer - dt
    node.pulsePhase = node.pulsePhase + dt * 6

    -- Nodes shoot at player periodically
    node.attackTimer = node.attackTimer - dt
    if node.attackTimer <= 0 then
      node.attackTimer = b.enraged and 0.6 or 1.2
      table.insert(b.pendingProjectiles, {
        type = "sweep",
        x = node.x,
        y = node.y,
        angle = math.atan2(playerY - node.y, playerX - node.x),
        speed = 320,
        damage = DAMAGE.shortCircuit,
      })
    end

    if node.timer <= 0 then
      table.remove(b.shortCircuitNodes, i)
    end
  end

  -- Spawn chain of nodes (forms a circuit pattern)
  b.shortCircuitTimer = b.shortCircuitTimer - dt
  if b.shortCircuitTimer <= 0 and #b.shortCircuitNodes < 5 then
    b.shortCircuitTimer = b.enraged and 3 or 6
    local nodeCount = b.enraged and 4 or 3

    -- Spawn in a circuit pattern around the arena
    for i = 1, nodeCount do
      local angle = (i / nodeCount) * math.pi * 2 + math.random() * 0.5
      local dist = 150 + math.random() * 100
      table.insert(b.shortCircuitNodes, {
        x = screen.WIDTH / 2 + math.cos(angle) * dist,
        y = screen.HEIGHT / 2 + math.sin(angle) * dist * 0.5,
        timer = 6,
        attackTimer = 0.5 + math.random() * 0.5,
        pulsePhase = math.random() * math.pi * 2,
        radius = 15,
        connectedTo = i < nodeCount and i + 1 or 1,
      })
    end
  end
end

-- ==================== OVERLOAD PULSE (Phase 7+ - expanding shockwave) ====================

function M.updateOverload(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 7 then return end

  -- Update existing pulses
  for i = #b.overloadPulses, 1, -1 do
    local pulse = b.overloadPulses[i]
    pulse.radius = pulse.radius + pulse.expandSpeed * dt
    pulse.lifetime = pulse.lifetime - dt

    if pulse.lifetime <= 0 or pulse.radius > 600 then
      table.remove(b.overloadPulses, i)
    end
  end

  -- Charge overload
  if b.overloadCharging then
    b.overloadTimer = b.overloadTimer - dt
    if b.overloadTimer <= 0 then
      b.overloadCharging = false
      -- Release the overload pulse!
      table.insert(b.overloadPulses, {
        x = b.x,
        y = b.y,
        radius = 20,
        expandSpeed = 250,
        damage = DAMAGE.overloadPulse,
        lifetime = 3,
        thickness = 15,
      })
      -- Second ring slightly delayed
      table.insert(b.overloadPulses, {
        x = b.x,
        y = b.y,
        radius = 10,
        expandSpeed = 200,
        damage = DAMAGE.overloadPulse * 0.6,
        lifetime = 3.5,
        thickness = 10,
      })
    end
  end
end

-- ==================== CABLE OBSTACLES (Indiana Jones style - throughout fight) ====================

function M.updateCables(dt, playerX, playerY)
  local b = M.boss

  -- Update existing cables
  for i = #b.cables, 1, -1 do
    local cable = b.cables[i]
    cable.lifetime = cable.lifetime - dt

    if cable.cableType == "horizontal" then
      -- Scrolls downward like terrain
      cable.y = cable.y + cable.speed * dt
    elseif cable.cableType == "swinging" then
      -- Swings back and forth (pendulum)
      cable.swingAngle = cable.swingAngle + cable.swingSpeed * dt
      cable.tipX = cable.anchorX + math.sin(cable.swingAngle) * cable.swingRadius
      cable.tipY = cable.anchorY + math.abs(math.cos(cable.swingAngle)) * cable.swingRadius * 0.5
    elseif cable.cableType == "sparking" then
      -- Moves horizontally, sparks
      cable.x = cable.x + cable.speed * cable.direction * dt
      if cable.x < 50 or cable.x > screen.WIDTH - 50 then
        cable.direction = -cable.direction
      end
      cable.sparkTimer = cable.sparkTimer - dt
      if cable.sparkTimer <= 0 then
        cable.sparkTimer = 0.8
        table.insert(b.pendingProjectiles, {
          type = "spread",
          x = cable.x,
          y = cable.y,
          angle = math.pi / 2 + (math.random() - 0.5) * 0.5,
          speed = 150,
          damage = cable.damage,
        })
      end
    elseif cable.cableType == "crushing" then
      -- Slams down from above (trap!)
      if cable.slamPhase == "warning" then
        cable.warningTimer = cable.warningTimer - dt
        if cable.warningTimer <= 0 then
          cable.slamPhase = "slamming"
          cable.slamSpeed = 500
        end
      elseif cable.slamPhase == "slamming" then
        cable.y = cable.y + cable.slamSpeed * dt
        if cable.y >= cable.targetY then
          cable.y = cable.targetY
          cable.slamPhase = "grounded"
          cable.groundTimer = 1.5
        end
      elseif cable.slamPhase == "grounded" then
        cable.groundTimer = cable.groundTimer - dt
        if cable.groundTimer <= 0 then
          cable.slamPhase = "retracting"
        end
      elseif cable.slamPhase == "retracting" then
        cable.y = cable.y - 200 * dt
        if cable.y < -50 then
          cable.lifetime = 0  -- Remove
        end
      end
    end

    if cable.lifetime <= 0 then
      table.remove(b.cables, i)
    end
  end

  -- Spawn cables based on phase
  if b.phase >= 1 then
    b.cableSpawnTimer = b.cableSpawnTimer - dt
    if b.cableSpawnTimer <= 0 then
      b.cableSpawnTimer = b.cableSpawnRate
      M.spawnCable()
    end
  end
end

function M.spawnCable()
  local b = M.boss
  local roll = math.random(100)

  if b.phase <= 2 then
    -- Only horizontal cables early on
    M.spawnHorizontalCable()
  elseif b.phase <= 4 then
    if roll < 40 then
      M.spawnHorizontalCable()
    elseif roll < 65 then
      M.spawnSwingingCable()
    elseif roll < 85 then
      M.spawnSparkingCable()
    else
      M.spawnCrushingCable()
    end
  else
    -- Late phases: all types, more dangerous
    if roll < 25 then
      M.spawnHorizontalCable()
    elseif roll < 45 then
      M.spawnSwingingCable()
    elseif roll < 65 then
      M.spawnSparkingCable()
    elseif roll < 85 then
      M.spawnCrushingCable()
    else
      -- Double cable!
      M.spawnHorizontalCable()
      M.spawnSparkingCable()
    end
  end
end

function M.spawnHorizontalCable()
  local b = M.boss
  local gapX = math.random(200, screen.WIDTH - 200)
  local gapWidth = b.enraged and 100 or 150

  table.insert(b.cables, {
    cableType = "horizontal",
    x = 0,
    y = b.y + 60,
    speed = 100 + b.phase * 12,
    damage = CABLE_TYPES.horizontal.damage,
    lifetime = 10,
    gapX = gapX,
    gapWidth = gapWidth,
    height = 12,
  })
end

function M.spawnSwingingCable()
  local b = M.boss
  local anchorX = math.random(150, screen.WIDTH - 150)

  table.insert(b.cables, {
    cableType = "swinging",
    anchorX = anchorX,
    anchorY = 50,
    tipX = anchorX,
    tipY = 50,
    swingAngle = math.random() * math.pi,
    swingSpeed = 2 + math.random() * 1.5,
    swingRadius = 120 + math.random() * 60,
    damage = CABLE_TYPES.swinging.damage,
    lifetime = 10,
    thickness = 6,
  })
end

function M.spawnSparkingCable()
  local b = M.boss
  table.insert(b.cables, {
    cableType = "sparking",
    x = math.random(100, screen.WIDTH - 100),
    y = math.random(250, screen.HEIGHT - 150),
    speed = CABLE_TYPES.sparking.speed + b.phase * 10,
    direction = math.random() < 0.5 and -1 or 1,
    damage = CABLE_TYPES.sparking.damage,
    lifetime = 8,
    width = CABLE_TYPES.sparking.width,
    height = 8,
    sparkTimer = 0.5,
  })
end

function M.spawnCrushingCable()
  local b = M.boss
  local targetX = math.random(100, screen.WIDTH - 100)

  table.insert(b.cables, {
    cableType = "crushing",
    x = targetX,
    y = -30,
    targetY = math.random(300, screen.HEIGHT - 100),
    damage = CABLE_TYPES.crushing.damage,
    lifetime = 12,
    width = CABLE_TYPES.crushing.width,
    height = 20,
    slamPhase = "warning",
    warningTimer = 1.2,
    slamSpeed = 0,
    groundTimer = 0,
  })
end

-- ==================== PUZZLE MECHANICS (Circuit Breaker) ====================

function M.startPuzzle()
  local b = M.boss

  -- Generate a sequence of circuit breaker positions
  -- Player must fly through them in order to create a vulnerability window
  b.puzzleActive = true
  b.breakersSolved = 0
  b.breakerCurrentIndex = 1
  b.circuitBreakers = {}

  local count = 3 + math.floor(b.phase / 2)  -- More switches in later phases
  if count > 6 then count = 6 end

  for i = 1, count do
    table.insert(b.circuitBreakers, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(200, screen.HEIGHT - 80),
      radius = 25,
      active = (i == 1),  -- Only first one is active
      solved = false,
      index = i,
      pulsePhase = math.random() * math.pi * 2,
    })
  end
end

function M.updatePuzzle(dt, playerX, playerY)
  local b = M.boss
  if not b.puzzleActive then
    -- Check cooldown for next puzzle
    if b.phase >= 3 then
      b.puzzleTimer = b.puzzleTimer - dt
      if b.puzzleTimer <= 0 then
        b.puzzleTimer = b.puzzleCooldown
        M.startPuzzle()
      end
    end
    return
  end

  -- Vulnerability window
  if b.vulnerableFromPuzzle then
    b.vulnerableTimer = b.vulnerableTimer - dt
    if b.vulnerableTimer <= 0 then
      b.vulnerableFromPuzzle = false
      b.puzzleActive = false
    end
    return
  end

  -- Check if player touches the active breaker
  for _, breaker in ipairs(b.circuitBreakers) do
    if breaker.active and not breaker.solved then
      local dx = playerX - breaker.x
      local dy = playerY - breaker.y
      local dist = math.sqrt(dx * dx + dy * dy)

      if dist < breaker.radius + 20 then
        breaker.solved = true
        breaker.active = false
        b.breakersSolved = b.breakersSolved + 1
        b.breakerCurrentIndex = b.breakerCurrentIndex + 1

        -- Activate next breaker
        if b.breakerCurrentIndex <= #b.circuitBreakers then
          b.circuitBreakers[b.breakerCurrentIndex].active = true
        end

        -- Check if all solved
        if b.breakersSolved >= #b.circuitBreakers then
          -- Puzzle complete! Boss becomes vulnerable
          b.vulnerableFromPuzzle = true
          b.vulnerableTimer = 4.0  -- 4 second vulnerability window
          -- Clear capacitor zones as reward
          b.capacitorZones = {}
        end
      end
    end
  end
end

-- ==================== MAGNET PULL (Phase 5+) ====================

function M.updateMagnet(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then
    b.magnetPullStrength = 0
    return
  end

  if b.magnetActive then
    b.magnetTimer = b.magnetTimer - dt
    local baseStrength = b.enraged and 180 or 120
    b.magnetPullStrength = baseStrength

    if b.magnetTimer <= 0 then
      b.magnetActive = false
      b.magnetPullStrength = 0
      b.magnetTimer = b.magnetCooldown
    end
  else
    b.magnetTimer = b.magnetTimer - dt
    b.magnetPullStrength = 0
    if b.magnetTimer <= 0 then
      b.magnetActive = true
      b.magnetTimer = 4  -- Pull lasts 4 seconds
    end
  end
end

-- ==================== MELTDOWN SPARKS (Phase 8) ====================

function M.updateMeltdownSparks(dt)
  local b = M.boss
  if not b.enraged then return end

  -- Spawn random sparks from the boss
  if math.random() < 0.3 then
    table.insert(b.meltdownSparks, {
      x = b.x + (math.random() - 0.5) * b.width,
      y = b.y + (math.random() - 0.5) * b.height,
      vx = (math.random() - 0.5) * 200,
      vy = math.random() * 150 + 50,
      lifetime = 0.5 + math.random() * 0.5,
      size = 2 + math.random() * 4,
    })
  end

  for i = #b.meltdownSparks, 1, -1 do
    local spark = b.meltdownSparks[i]
    spark.x = spark.x + spark.vx * dt
    spark.y = spark.y + spark.vy * dt
    spark.lifetime = spark.lifetime - dt
    if spark.lifetime <= 0 then
      table.remove(b.meltdownSparks, i)
    end
  end
end

-- ==================== ATTACK LOGIC ====================

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 3 then attackSpeed = 1.3 end
  if b.phase >= 5 then attackSpeed = 1.5 end
  if b.phase >= 7 then attackSpeed = 1.8 end
  if b.enraged then attackSpeed = 2.2 end

  local baseCooldown = 2.0 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Cable Whip only
    M.fireCableWhip(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: Cable Whip + Surge Strike
    if roll < 50 then
      M.fireCableWhip(playerX, playerY)
    else
      M.fireSurgeStrike(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: + Capacitor Traps (passive) + spread
    if roll < 35 then
      M.fireCableWhip(playerX, playerY)
    elseif roll < 65 then
      M.fireSurgeStrike(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: + Inductor Blades
    if roll < 25 then
      M.fireCableWhip(playerX, playerY)
    elseif roll < 50 then
      M.fireSurgeStrike(playerX, playerY)
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end

  elseif b.phase == 5 then
    -- Phase 5: + Arc Flash waves + magnet pull
    if roll < 20 then
      M.fireCableWhip(playerX, playerY)
    elseif roll < 40 then
      M.fireSurgeStrike(playerX, playerY)
    elseif roll < 60 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 80 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.fireArcBurst(playerX, playerY)
    end

  elseif b.phase == 6 then
    -- Phase 6: + Short Circuit nodes
    if roll < 18 then
      M.fireCableWhip(playerX, playerY)
    elseif roll < 35 then
      M.fireSurgeStrike(playerX, playerY)
    elseif roll < 52 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 68 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 84 then
      M.fireArcBurst(playerX, playerY)
    else
      M.fireCircuitBarrage(playerX, playerY)
    end

  elseif b.phase == 7 then
    -- Phase 7: + Overload Pulse
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      -- Overload combo!
      b.overloadCharging = true
      b.overloadTimer = b.overloadDuration
      M.fireSweepPattern(playerX, playerY)
    else
      if roll < 20 then
        M.fireCableWhip(playerX, playerY)
      elseif roll < 40 then
        M.fireSurgeStrike(playerX, playerY)
      elseif roll < 55 then
        M.fireSpreadPattern(playerX, playerY)
      elseif roll < 70 then
        M.fireArcBurst(playerX, playerY)
      elseif roll < 85 then
        M.fireCircuitBarrage(playerX, playerY)
      else
        M.fireSweepPattern(playerX, playerY)
      end
    end

  else
    -- Phase 8: MELTDOWN - everything, faster, combos
    b.comboChain = b.comboChain + 1
    if b.comboChain >= 2 then
      b.comboChain = 0
      -- Meltdown combo: triple attack
      M.fireSurgeStrike(playerX, playerY)
      M.fireSweepPattern(playerX, playerY)
      M.fireCircuitBarrage(playerX, playerY)
      -- Also charge overload
      if not b.overloadCharging then
        b.overloadCharging = true
        b.overloadTimer = 1.5  -- Faster charge in meltdown
      end
    else
      if roll < 15 then
        M.fireCableWhip(playerX, playerY)
      elseif roll < 30 then
        M.fireSurgeStrike(playerX, playerY)
      elseif roll < 45 then
        M.fireSpreadPattern(playerX, playerY)
      elseif roll < 55 then
        M.fireArcBurst(playerX, playerY)
      elseif roll < 70 then
        M.fireCircuitBarrage(playerX, playerY)
      elseif roll < 85 then
        M.fireSweepPattern(playerX, playerY)
      else
        -- Emergency overload
        b.overloadCharging = true
        b.overloadTimer = 1.0
      end
    end
    b.attackTimer = 0.6  -- Much faster in meltdown
  end
end

-- ==================== ATTACK PATTERNS ====================

function M.fireCableWhip(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.cableWhip
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Three cable lash arcs (sweeping whip)
  for i = -1, 1 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.3
    table.insert(b.pendingProjectiles, {
      type = "slash",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 300,
      damage = damage,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "cableWhip"
end

function M.fireSurgeStrike(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.surgeStrike
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Chain of 3-6 surge bolts in rapid succession
  local count = b.enraged and 6 or (3 + math.floor(b.phase / 3))
  for i = 1, count do
    local spreadAngle = ((i - (count + 1) / 2) * 0.18)
    local angle = math.atan2(playerY - b.y, playerX - b.x) + spreadAngle
    table.insert(b.pendingProjectiles, {
      type = "lightning",
      x = b.x + (i - (count + 1) / 2) * 12,
      y = b.y + 45,
      angle = angle,
      speed = 360,
      damage = damage,
      delay = (i - 1) * 0.05,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "surgeStrike"
end

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.cableWhip
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Fan spread
  local count = b.enraged and 9 or (5 + math.floor(b.phase / 2))
  for i = 1, count do
    local angle = math.pi / 2 + ((i - (count + 1) / 2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 270,
      damage = damage,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.surgeStrike
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Sweep beam (10 projectiles in quick sequence)
  local count = b.enraged and 12 or 10
  for i = 0, count - 1 do
    local delay = i * 0.06
    local angle = math.pi / 2 - 0.6 + (i * (1.2 / count))
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 55,
      angle = angle,
      speed = 350,
      damage = damage,
      delay = delay,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "sweep"
end

function M.fireArcBurst(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.arcFlash
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Omnidirectional burst (circle of projectiles)
  local count = b.enraged and 16 or 12
  for i = 1, count do
    local angle = (i / count) * math.pi * 2
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y,
      angle = angle,
      speed = 220,
      damage = damage,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "arcBurst"
end

function M.fireCircuitBarrage(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.shortCircuit
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Rapid targeted burst (5 aimed shots with slight spread)
  for i = 1, 5 do
    local jitter = (math.random() - 0.5) * 0.4
    local angle = math.atan2(playerY - b.y, playerX - b.x) + jitter
    table.insert(b.pendingProjectiles, {
      type = "lightning",
      x = b.x + (math.random() - 0.5) * 40,
      y = b.y + 50,
      angle = angle,
      speed = 400,
      damage = damage,
      delay = i * 0.08,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "circuitBarrage"
end

-- ==================== DAMAGE ====================

function M.damage(amount, hitArm)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Must destroy power regulator nodes first
  if not b.regulatorsDown then
    if hitArm == "left" and not b.leftRegulator.destroyed then
      b.leftRegulator.health = b.leftRegulator.health - amount
      if b.leftRegulator.health <= 0 then
        b.leftRegulator.destroyed = true
      end
      if b.leftRegulator.destroyed and b.rightRegulator.destroyed then
        b.regulatorsDown = true
      end
      return false
    elseif hitArm == "right" and not b.rightRegulator.destroyed then
      b.rightRegulator.health = b.rightRegulator.health - amount
      if b.rightRegulator.health <= 0 then
        b.rightRegulator.destroyed = true
      end
      if b.leftRegulator.destroyed and b.rightRegulator.destroyed then
        b.regulatorsDown = true
      end
      return false
    end
    return false
  end

  -- Bonus damage during vulnerability window from puzzle
  if b.vulnerableFromPuzzle then
    amount = amount * 1.5
  end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- ==================== COLLISION CHECKS ====================

-- Check if player is in capacitor zone
function M.checkCapacitorZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.capacitorZones) do
    local dx = playerX - zone.x
    local dy = playerY - zone.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
      zone.damageTimer = 0.5
      totalDamage = totalDamage + zone.damage
    end
  end

  return totalDamage
end

-- Check if player collides with cable obstacles
function M.checkCableCollision(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, cable in ipairs(b.cables) do
    if cable.cableType == "horizontal" then
      -- Check if player is on the cable's Y level and NOT in the gap
      if math.abs(playerY - cable.y) < (cable.height / 2 + playerRadius) then
        if playerX < (cable.gapX - cable.gapWidth / 2) or playerX > (cable.gapX + cable.gapWidth / 2) then
          totalDamage = totalDamage + cable.damage
        end
      end
    elseif cable.cableType == "swinging" then
      -- Check distance from cable tip
      local dx = playerX - cable.tipX
      local dy = playerY - cable.tipY
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < cable.thickness + playerRadius + 15 then
        totalDamage = totalDamage + cable.damage
      end
    elseif cable.cableType == "sparking" then
      -- Rectangular check
      if math.abs(playerX - cable.x) < (cable.width / 2 + playerRadius) and
         math.abs(playerY - cable.y) < (cable.height / 2 + playerRadius) then
        totalDamage = totalDamage + cable.damage
      end
    elseif cable.cableType == "crushing" then
      if cable.slamPhase == "slamming" or cable.slamPhase == "grounded" then
        if math.abs(playerX - cable.x) < (cable.width / 2 + playerRadius) and
           math.abs(playerY - cable.y) < (cable.height / 2 + playerRadius) then
          totalDamage = totalDamage + cable.damage
        end
      end
    end
  end

  return totalDamage
end

-- Check if player collides with inductor blades
function M.checkInductorCollision(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, blade in ipairs(b.inductorBlades) do
    local dx = playerX - blade.x
    local dy = playerY - blade.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < blade.radius + playerRadius then
      totalDamage = totalDamage + DAMAGE.inductorSpin
    end
  end

  return totalDamage
end

-- Check if player is hit by arc flash waves
function M.checkArcFlashDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, wave in ipairs(b.arcFlashWaves) do
    if math.abs(playerY - wave.y) < (wave.height / 2 + playerRadius) and
       playerX >= wave.x and playerX <= wave.x + wave.width then
      totalDamage = totalDamage + wave.damage
    end
  end

  return totalDamage
end

-- Check if player is hit by overload pulse rings
function M.checkOverloadDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, pulse in ipairs(b.overloadPulses) do
    local dx = playerX - pulse.x
    local dy = playerY - pulse.y
    local dist = math.sqrt(dx * dx + dy * dy)
    -- Hit if player is within the ring (between inner and outer edge)
    if dist > pulse.radius - pulse.thickness / 2 - playerRadius and
       dist < pulse.radius + pulse.thickness / 2 + playerRadius then
      totalDamage = totalDamage + pulse.damage
    end
  end

  return totalDamage
end

-- Get gravity/magnet pull
function M.getGravityPull()
  local b = M.boss
  if not b or not b.magnetActive then return 0, 0, 0 end
  return b.x, b.y, b.magnetPullStrength
end

-- Get pending projectiles for weapons system
function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

-- Get current attack info for HUD warnings
function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.phaseTransitioning then
    return "POWER REROUTING", b.transitionTimer / 1.8
  end

  if b.overloadCharging then
    return "!! OVERLOAD IMMINENT !!", b.overloadTimer / b.overloadDuration
  end

  if b.vulnerableFromPuzzle then
    return "CIRCUIT BREACHED - ATTACK!", b.vulnerableTimer / 4.0
  end

  return nil
end

-- Get phase name for display
function M.getPhaseName()
  local b = M.boss
  if not b then return "" end

  local names = {
    "CABLE CONDUIT",
    "SURGE SECTOR",
    "CAPACITOR BANK",
    "INDUCTOR MAZE",
    "ARC FLASH CORRIDOR",
    "SHORT CIRCUIT",
    "OVERLOAD CHAMBER",
    "TOTAL MELTDOWN"
  }
  return names[b.phase] or ""
end

return M
