local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- ============================================================
-- THE MACHINE — 21-Phase Ultimate Final Boss Raid
-- An ancient cosmic construct at the edge of the nebula.
-- Elden Ring difficulty: every phase adds new lethal mechanics.
-- Defeating adds grants health + missile regen.
-- ============================================================

-- Damage values (extremely punishing — Elden Ring philosophy)
local DAMAGE = {
  -- Act I: The Awakening (Phases 1-7)
  grindBlade = 15,          -- Rotating blade slash projectiles
  pistonStrike = 22,        -- Piston slam shockwave
  steamVent = 10,           -- Steam vent DOT per tick
  gearCrush = 30,           -- Gear crush grab attack
  chainSaw = 14,            -- Chain saw sweeping arc
  drillLance = 25,          -- Drill lance piercing charge
  overclockBurst = 18,      -- Overclock burst rapid shots

  -- Act II: The Forge (Phases 8-14)
  moltenSlag = 12,          -- Molten slag DOT zones
  hydraulicRam = 28,        -- Hydraulic ram charge
  arcWelder = 16,           -- Arc welder beam sweep
  magnetPull = 8,           -- Magnetic pull DOT
  factoryLine = 20,         -- Factory line conveyor trap
  turbineBlade = 35,        -- Turbine blade instant kill zone
  pressureBlow = 24,        -- Pressure blow area attack

  -- Act III: The Singularity (Phases 15-21)
  quantumShear = 30,        -- Quantum shear reality cuts
  timeDilation = 10,        -- Time dilation slow field DOT
  assemblySwarm = 12,       -- Nano assembly swarm per hit
  coreBeam = 55,            -- Core beam near-instant kill
  dimensionRift = 18,       -- Dimension rift projectiles
  annihilationPulse = 40,   -- Annihilation pulse screen blast
  godMachine = 22           -- God Machine final phase attacks
}

-- Phase HP thresholds (out of 2100 total — 100 per phase)
local PHASE_THRESHOLDS = {}
for i = 1, 21 do
  PHASE_THRESHOLDS[i] = 2100 - (i - 1) * 100
end

-- Phase names for HUD display
local PHASE_NAMES = {
  "IGNITION",           -- 1
  "PISTON DRIVE",       -- 2
  "STEAM WORKS",        -- 3
  "GEAR ASSEMBLY",      -- 4
  "CHAIN DRIVE",        -- 5
  "DRILL CORE",         -- 6
  "OVERCLOCK",          -- 7
  "MOLTEN FORGE",       -- 8
  "HYDRAULIC FURY",     -- 9
  "ARC FOUNDRY",        -- 10
  "MAGNETIC STORM",     -- 11
  "ASSEMBLY LINE",      -- 12
  "TURBINE HEART",      -- 13
  "PRESSURE VESSEL",    -- 14
  "QUANTUM ENGINE",     -- 15
  "TIME FRACTURE",      -- 16
  "NANO SWARM",         -- 17
  "CORE MELTDOWN",      -- 18
  "DIMENSION BREACH",   -- 19
  "ANNIHILATION",       -- 20
  "GOD MACHINE"         -- 21
}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -200,
    width = 200,
    height = 150,
    health = 2100,
    maxHealth = 2100,
    score = 50000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 90,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Phase 2+)
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
    comboMax = 3,

    -- Grind Blades (Phase 1) - rotating blade projectiles
    bladeAngle = 0,
    bladeSpinSpeed = 2,

    -- Piston Strike (Phase 2) - slam shockwave
    pistonCharging = false,
    pistonTimer = 0,
    pistonTargetX = 0,
    pistonTargetY = 0,

    -- Steam Vents (Phase 3) - DOT zones
    steamVents = {},
    steamSpawnTimer = 0,

    -- Gear Crush (Phase 4) - gears that orbit and close in
    gears = {},
    gearSpawnTimer = 0,

    -- Chain Saw (Phase 5) - sweeping chain arc
    chainSawActive = false,
    chainSawAngle = 0,
    chainSawTimer = 0,

    -- Drill Lance (Phase 6) - charge attack
    drillCharging = false,
    drillTimer = 0,
    drillDuration = 2.0,
    drillTargetX = 0,
    drillTargetY = 0,

    -- Overclock (Phase 7) - burst fire mode
    overclockActive = false,
    overclockTimer = 0,
    overclockBursts = 0,

    -- Molten Slag Zones (Phase 8) - like rot zones but fire
    slagZones = {},
    slagSpawnTimer = 0,

    -- Hydraulic Ram (Phase 9) - charge dash
    ramCharging = false,
    ramActive = false,
    ramTimer = 0,
    ramStartX = 0,
    ramStartY = 0,
    ramTargetX = 0,
    ramTargetY = 0,
    ramCooldown = 0,

    -- Arc Welder (Phase 10) - beam sweep
    arcWelderActive = false,
    arcWelderAngle = 0,
    arcWelderTimer = 0,
    arcWelderSweepDir = 1,

    -- Magnetic Pull (Phase 11) - gravity well
    magnetActive = false,
    magnetTimer = 0,
    magnetCooldown = 10,
    magnetPullStrength = 0,

    -- Factory Line (Phase 12) - conveyor traps
    conveyors = {},
    conveyorSpawnTimer = 0,

    -- Turbine Blades (Phase 13) - instant-kill zones
    turbines = {},
    turbineSpawnTimer = 0,

    -- Pressure Blow (Phase 14) - area explosion
    pressureCharging = false,
    pressureTimer = 0,
    pressureDuration = 2.5,

    -- Quantum Shear (Phase 15) - reality cuts
    quantumCuts = {},
    quantumCutTimer = 0,

    -- Time Dilation (Phase 16) - slow fields
    timeFields = {},
    timeFieldTimer = 0,

    -- Nano Swarm (Phase 17) - tracking swarm projectiles
    nanoSwarmActive = false,
    nanoSwarmTimer = 0,
    nanoSwarmHits = 0,
    nanoSwarmMaxHits = 12,
    nanoSwarmTargetX = 0,
    nanoSwarmTargetY = 0,

    -- Core Beam (Phase 18) - instant kill charge
    coreBeamCharging = false,
    coreBeamTimer = 0,
    coreBeamDuration = 3.0,
    coreBeamTargetX = 0,
    coreBeamTargetY = 0,

    -- Dimension Rift (Phase 19) - rift portals that fire
    rifts = {},
    riftSpawnTimer = 0,

    -- Annihilation Pulse (Phase 20) - screen-wide blast with safe zone
    annihilationCharging = false,
    annihilationTimer = 0,
    annihilationDuration = 3.5,
    annihilationSafeX = 0,
    annihilationSafeY = 0,
    annihilationSafeRadius = 80,

    -- God Machine (Phase 21) - all attacks combined, rage mode
    enraged = false,
    rageMultiplier = 2.0,

    -- Sub-entities: Adds
    adds = {},
    addSpawnTimer = 5,
    addSpawnCooldown = 8,
    maxAdds = 4,

    -- Obstacle: Spinning barriers
    barriers = {},
    barrierSpawnTimer = 0,

    -- Armor plating (Phases 1-4 only, must be destroyed)
    leftArmor = { health = 40, maxHealth = 40, destroyed = false },
    rightArmor = { health = 40, maxHealth = 40, destroyed = false },

    -- Shield Generator (Phases 8-10, must destroy to damage core)
    shieldGenerator = { health = 60, maxHealth = 60, destroyed = false, active = false },

    -- Projectile tracking
    pendingProjectiles = {},

    -- Phase transition invulnerability
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Background: Nebula glow and Hometown Station
    nebulaAngle = 0,
    stationOrbitAngle = 0,

    -- Track total time for visual effects
    totalTime = 0
  }
end

function M.isActive()
  return M.boss ~= nil and M.boss.active
end

function M.isDefeated()
  return M.boss ~= nil and not M.boss.active and M.boss.health <= 0
end

function M.getAct()
  local b = M.boss
  if not b then return 1 end
  if b.phase <= 7 then return 1
  elseif b.phase <= 14 then return 2
  else return 3 end
end

function M.getPhaseName()
  local b = M.boss
  if not b then return "" end
  return PHASE_NAMES[b.phase] or "UNKNOWN"
end

-- ============================================================
-- MAIN UPDATE
-- ============================================================

function M.update(dt, playerX, playerY)
  local b = M.boss
  if not b or not b.active then return end

  b.shouldAttack = false
  b.pendingProjectiles = {}
  b.totalTime = b.totalTime + dt

  -- Entry animation
  if b.entering then
    b.y = b.y + 60 * dt
    if b.y >= b.targetY then
      b.y = b.targetY
      b.entering = false
    end
    return
  end

  -- Phase transition invulnerability
  if b.phaseTransitioning then
    b.transitionTimer = b.transitionTimer - dt
    if b.transitionTimer <= 0 then
      b.phaseTransitioning = false
      M.onPhaseStart()
    end
    return
  end

  -- Background animation
  b.nebulaAngle = b.nebulaAngle + dt * 0.1
  b.stationOrbitAngle = b.stationOrbitAngle + dt * 0.15

  M.updatePhase()
  M.updateAdds(dt, playerX, playerY)
  M.updateBarriers(dt)
  M.updateTeleport(dt, playerX, playerY)
  M.updateSteamVents(dt)
  M.updateGears(dt, playerX, playerY)
  M.updateChainSaw(dt, playerX, playerY)
  M.updateDrill(dt, playerX, playerY)
  M.updateOverclock(dt, playerX, playerY)
  M.updateSlagZones(dt)
  M.updateHydraulicRam(dt, playerX, playerY)
  M.updateArcWelder(dt, playerX, playerY)
  M.updateMagnet(dt, playerX, playerY)
  M.updateConveyors(dt)
  M.updateTurbines(dt)
  M.updatePressure(dt, playerX, playerY)
  M.updateQuantumCuts(dt, playerX, playerY)
  M.updateTimeFields(dt)
  M.updateNanoSwarm(dt, playerX, playerY)
  M.updateCoreBeam(dt, playerX, playerY)
  M.updateRifts(dt, playerX, playerY)
  M.updateAnnihilation(dt, playerX, playerY)
  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
end

-- ============================================================
-- PHASE MANAGEMENT
-- ============================================================

function M.updatePhase()
  local b = M.boss
  local oldPhase = b.phase

  for i = 21, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      b.phase = i
      break
    end
  end

  if b.phase > oldPhase then
    b.phaseTransitioning = true
    b.transitionTimer = 1.5
    -- Cancel active attacks
    b.chainSawActive = false
    b.drillCharging = false
    b.overclockActive = false
    b.ramActive = false
    b.ramCharging = false
    b.arcWelderActive = false
    b.magnetActive = false
    b.pressureCharging = false
    b.nanoSwarmActive = false
    b.coreBeamCharging = false
    b.annihilationCharging = false
    b.pistonCharging = false

    -- Activate shield generator in Act II
    if b.phase == 8 and not b.shieldGenerator.destroyed then
      b.shieldGenerator.active = true
    end
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 21 then
    b.enraged = true
    b.comboMax = 2  -- Attacks faster in god mode
  elseif b.phase >= 15 then
    b.comboMax = 3
  end

  -- Spawn barriers at key phase transitions
  if b.phase == 5 or b.phase == 10 or b.phase == 15 or b.phase == 20 then
    M.spawnBarrier()
  end

  -- Reset attack timer for new phase
  b.attackTimer = 1.0
end

-- ============================================================
-- MOVEMENT
-- ============================================================

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end
  if b.ramActive or b.nanoSwarmActive then return end

  local speed = 1.0 + b.phase * 0.12
  if b.enraged then speed = speed * 1.5 end

  b.moveAngle = b.moveAngle + speed * dt

  -- Movement pattern depends on act
  local act = M.getAct()
  if act == 1 then
    -- Simple sinusoidal
    local range = 120 + b.phase * 15
    b.x = b.baseX + math.sin(b.moveAngle) * range
    if b.phase >= 3 then
      b.y = b.targetY + math.sin(b.moveAngle * 0.7) * 25
    end
  elseif act == 2 then
    -- Figure-8 pattern
    local range = 150 + (b.phase - 7) * 20
    b.x = b.baseX + math.sin(b.moveAngle) * range
    b.y = b.targetY + math.sin(b.moveAngle * 2) * 40
  else
    -- Erratic multi-axis
    local range = 200 + (b.phase - 14) * 15
    b.x = b.baseX + math.sin(b.moveAngle * 1.3) * range + math.cos(b.moveAngle * 2.1) * 50
    b.y = b.targetY + math.sin(b.moveAngle * 0.8) * 50 + math.cos(b.moveAngle * 1.7) * 25
  end

  -- Clamp to screen
  b.x = math.max(100, math.min(screen.WIDTH - 100, b.x))
  b.y = math.max(60, math.min(250, b.y))
end

-- ============================================================
-- TELEPORT (Phase 2+)
-- ============================================================

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.ramActive or b.nanoSwarmActive then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 3.5
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      -- Strike on appear
      b.shouldAttack = true
      b.currentAttack = "pistonStrike"
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 3.5
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    local cooldown = b.teleportCooldown - b.phase * 0.15
    if b.enraged then cooldown = cooldown * 0.4 end
    cooldown = math.max(1.5, cooldown)

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
  b.teleportTargetX = math.max(100, math.min(screen.WIDTH - 100, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(250, playerY - 90))
end

-- ============================================================
-- ADDS SYSTEM — Defeating adds grants health + missile regen
-- ============================================================

function M.updateAdds(dt, playerX, playerY)
  local b = M.boss
  b.addSpawnTimer = b.addSpawnTimer - dt

  local maxAdds = b.maxAdds
  if b.phase >= 8 then maxAdds = maxAdds + 1 end
  if b.phase >= 15 then maxAdds = maxAdds + 1 end
  if b.enraged then maxAdds = maxAdds + 2 end

  local cooldown = b.addSpawnCooldown - b.phase * 0.2
  if b.enraged then cooldown = cooldown * 0.5 end
  cooldown = math.max(3, cooldown)

  if b.addSpawnTimer <= 0 and #b.adds < maxAdds then
    b.addSpawnTimer = cooldown
    M.spawnAdd()
  end

  -- Update adds
  for i = #b.adds, 1, -1 do
    local add = b.adds[i]
    add.lifetime = add.lifetime - dt
    add.attackTimer = add.attackTimer - dt

    -- Movement: orbit around boss
    add.orbitAngle = add.orbitAngle + add.orbitSpeed * dt
    add.x = b.x + math.cos(add.orbitAngle) * add.orbitRadius
    add.y = b.y + math.sin(add.orbitAngle) * add.orbitRadius + 80

    -- Clamp to screen
    add.x = math.max(20, math.min(screen.WIDTH - 20, add.x))
    add.y = math.max(20, math.min(screen.HEIGHT - 20, add.y))

    -- Shoot at player
    if add.attackTimer <= 0 then
      add.attackTimer = add.attackCooldown
      local angle = math.atan2(playerY - add.y, playerX - add.x)
      table.insert(b.pendingProjectiles, {
        type = "addShot",
        x = add.x,
        y = add.y + 15,
        angle = angle,
        speed = 250,
        damage = 8
      })
    end

    -- Remove if lifetime expired
    if add.lifetime <= 0 then
      table.remove(b.adds, i)
    end
  end
end

function M.spawnAdd()
  local b = M.boss
  local side = math.random() > 0.5 and 1 or -1
  local hp = 3
  if b.phase >= 8 then hp = 5 end
  if b.phase >= 15 then hp = 7 end

  table.insert(b.adds, {
    x = b.x + side * 100,
    y = b.y,
    width = 30,
    height = 24,
    health = hp,
    maxHealth = hp,
    orbitAngle = math.random() * math.pi * 2,
    orbitRadius = 120 + math.random() * 80,
    orbitSpeed = 1.5 + math.random() * 1.0,
    attackTimer = 1.5 + math.random(),
    attackCooldown = 2.0 - b.phase * 0.05,
    lifetime = 15 + math.random() * 5
  })
end

-- Damage an add — returns healthRegen, missileRegen if killed
function M.damageAdd(addIndex, amount)
  local b = M.boss
  if not b or addIndex < 1 or addIndex > #b.adds then return false, 0, 0 end

  local add = b.adds[addIndex]
  add.health = add.health - amount

  if add.health <= 0 then
    -- Add killed! Grant regen rewards
    local healthRegen = 8 + b.phase  -- More regen in later phases (need it!)
    local missileRegen = 1
    if b.phase >= 15 then missileRegen = 2 end
    table.remove(b.adds, addIndex)
    return true, healthRegen, missileRegen
  end

  return false, 0, 0
end

-- ============================================================
-- OBSTACLES: Spinning Barriers
-- ============================================================

function M.updateBarriers(dt)
  local b = M.boss
  b.barrierSpawnTimer = b.barrierSpawnTimer - dt

  for i = #b.barriers, 1, -1 do
    local bar = b.barriers[i]
    bar.lifetime = bar.lifetime - dt
    bar.angle = bar.angle + bar.spinSpeed * dt
    bar.y = bar.y + bar.scrollSpeed * dt

    if bar.lifetime <= 0 or bar.y > screen.HEIGHT + 50 then
      table.remove(b.barriers, i)
    end
  end
end

function M.spawnBarrier()
  local b = M.boss
  local side = math.random(1, 3)
  local bx
  if side == 1 then bx = screen.WIDTH * 0.25
  elseif side == 2 then bx = screen.WIDTH * 0.5
  else bx = screen.WIDTH * 0.75 end

  table.insert(b.barriers, {
    x = bx,
    y = -30,
    width = 120,
    height = 12,
    angle = math.random() * math.pi,
    spinSpeed = 2 + math.random() * 2,
    scrollSpeed = 40 + b.phase * 3,
    lifetime = 12
  })
end

-- ============================================================
-- STEAM VENTS (Phase 3+) - DOT zones
-- ============================================================

function M.updateSteamVents(dt)
  local b = M.boss
  if b.phase < 3 then return end

  b.steamSpawnTimer = b.steamSpawnTimer - dt
  local spawnRate = b.enraged and 2 or 4
  local maxVents = 4 + math.floor(b.phase / 4)

  if b.steamSpawnTimer <= 0 and #b.steamVents < maxVents then
    b.steamSpawnTimer = spawnRate
    table.insert(b.steamVents, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(250, screen.HEIGHT - 80),
      radius = 50 + math.random() * 20,
      lifetime = 7 + math.random() * 3,
      damage = DAMAGE.steamVent,
      damageTimer = 0
    })
  end

  for i = #b.steamVents, 1, -1 do
    local vent = b.steamVents[i]
    vent.lifetime = vent.lifetime - dt
    vent.damageTimer = vent.damageTimer - dt
    if vent.lifetime <= 0 then
      table.remove(b.steamVents, i)
    end
  end
end

-- ============================================================
-- GEAR CRUSH (Phase 4+) - orbiting gears that close in
-- ============================================================

function M.updateGears(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  b.gearSpawnTimer = b.gearSpawnTimer - dt
  local spawnRate = b.enraged and 3 or 6

  if b.gearSpawnTimer <= 0 and #b.gears < 3 then
    b.gearSpawnTimer = spawnRate
    local angle = math.random() * math.pi * 2
    table.insert(b.gears, {
      x = playerX + math.cos(angle) * 200,
      y = playerY + math.sin(angle) * 200,
      angle = angle,
      radius = 25,
      spinAngle = 0,
      closeSpeed = 40 + b.phase * 3,
      targetX = playerX,
      targetY = playerY,
      lifetime = 5
    })
  end

  for i = #b.gears, 1, -1 do
    local gear = b.gears[i]
    gear.lifetime = gear.lifetime - dt
    gear.spinAngle = gear.spinAngle + 8 * dt

    -- Move toward target position
    local dx = gear.targetX - gear.x
    local dy = gear.targetY - gear.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 5 then
      gear.x = gear.x + (dx / dist) * gear.closeSpeed * dt
      gear.y = gear.y + (dy / dist) * gear.closeSpeed * dt
    end

    if gear.lifetime <= 0 then
      table.remove(b.gears, i)
    end
  end
end

-- ============================================================
-- CHAIN SAW (Phase 5+) - sweeping arc
-- ============================================================

function M.updateChainSaw(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then return end

  if b.chainSawActive then
    b.chainSawTimer = b.chainSawTimer - dt
    b.chainSawAngle = b.chainSawAngle + 3 * dt

    -- Fire projectiles along the arc
    if math.floor(b.chainSawAngle * 10) % 3 == 0 then
      local angle = b.chainSawAngle
      table.insert(b.pendingProjectiles, {
        type = "chainSaw",
        x = b.x + math.cos(angle) * 80,
        y = b.y + math.sin(angle) * 80 + 50,
        angle = angle + math.pi / 2,
        speed = 300,
        damage = DAMAGE.chainSaw
      })
    end

    if b.chainSawTimer <= 0 then
      b.chainSawActive = false
    end
  end
end

function M.startChainSaw()
  local b = M.boss
  b.chainSawActive = true
  b.chainSawTimer = 2.0
  b.chainSawAngle = 0
end

-- ============================================================
-- DRILL LANCE (Phase 6+) - charged piercing attack
-- ============================================================

function M.updateDrill(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 6 then return end

  if b.drillCharging then
    b.drillTimer = b.drillTimer - dt
    if b.drillTimer <= 0 then
      b.drillCharging = false
      -- Fire massive drill projectile
      local angle = math.atan2(b.drillTargetY - b.y, b.drillTargetX - b.x)
      table.insert(b.pendingProjectiles, {
        type = "drillLance",
        x = b.x,
        y = b.y + 60,
        angle = angle,
        speed = 500,
        damage = DAMAGE.drillLance,
        width = 30
      })
      b.shouldAttack = true
      b.currentAttack = "drillLance"
    end
  end
end

function M.startDrill(playerX, playerY)
  local b = M.boss
  b.drillCharging = true
  b.drillTimer = b.drillDuration
  b.drillTargetX = playerX
  b.drillTargetY = playerY
end

-- ============================================================
-- OVERCLOCK (Phase 7+) - rapid burst fire
-- ============================================================

function M.updateOverclock(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 7 then return end

  if b.overclockActive then
    b.overclockTimer = b.overclockTimer - dt
    if b.overclockTimer <= 0 and b.overclockBursts < 8 then
      b.overclockBursts = b.overclockBursts + 1
      b.overclockTimer = 0.12

      local angle = math.atan2(playerY - b.y, playerX - b.x)
      local spread = (math.random() - 0.5) * 0.4
      table.insert(b.pendingProjectiles, {
        type = "overclockBurst",
        x = b.x,
        y = b.y + 50,
        angle = angle + spread,
        speed = 400,
        damage = DAMAGE.overclockBurst
      })
      b.shouldAttack = true
      b.currentAttack = "overclock"
    end

    if b.overclockBursts >= 8 then
      b.overclockActive = false
    end
  end
end

function M.startOverclock()
  local b = M.boss
  b.overclockActive = true
  b.overclockTimer = 0.5  -- Wind-up
  b.overclockBursts = 0
end

-- ============================================================
-- MOLTEN SLAG ZONES (Phase 8+) - fire DOT zones
-- ============================================================

function M.updateSlagZones(dt)
  local b = M.boss
  if b.phase < 8 then return end

  b.slagSpawnTimer = b.slagSpawnTimer - dt
  local spawnRate = b.enraged and 1.5 or 3
  local maxZones = 5 + math.floor((b.phase - 7) / 2)

  if b.slagSpawnTimer <= 0 and #b.slagZones < maxZones then
    b.slagSpawnTimer = spawnRate
    table.insert(b.slagZones, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(200, screen.HEIGHT - 80),
      radius = 55 + math.random() * 25,
      lifetime = 9,
      damage = DAMAGE.moltenSlag,
      damageTimer = 0
    })
  end

  for i = #b.slagZones, 1, -1 do
    local zone = b.slagZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt
    if zone.lifetime <= 0 then
      table.remove(b.slagZones, i)
    end
  end
end

-- ============================================================
-- HYDRAULIC RAM (Phase 9+) - charge dash at player
-- ============================================================

function M.updateHydraulicRam(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 9 then return end

  if b.ramCharging then
    b.ramTimer = b.ramTimer - dt
    if b.ramTimer <= 0 then
      b.ramCharging = false
      b.ramActive = true
      b.ramTimer = 1.0
      b.ramStartX = b.x
      b.ramStartY = b.y
      b.ramTargetX = playerX
      b.ramTargetY = math.min(playerY, screen.HEIGHT - 50)
    end
  elseif b.ramActive then
    b.ramTimer = b.ramTimer - dt
    local t = 1.0 - b.ramTimer
    b.x = b.ramStartX + (b.ramTargetX - b.ramStartX) * t
    b.y = b.ramStartY + (b.ramTargetY - b.ramStartY) * t

    -- Fire shockwave projectiles during charge
    if math.floor(t * 10) % 2 == 0 then
      for a = -1, 1 do
        table.insert(b.pendingProjectiles, {
          type = "hydraulicRam",
          x = b.x + a * 30,
          y = b.y + 60,
          angle = math.pi / 2 + a * 0.3,
          speed = 200,
          damage = DAMAGE.hydraulicRam
        })
      end
    end

    if b.ramTimer <= 0 then
      b.ramActive = false
      b.baseX = b.x
      b.ramCooldown = b.enraged and 4 or 7
      b.shouldAttack = true
      b.currentAttack = "hydraulicRam"
    end
  else
    b.ramCooldown = b.ramCooldown - dt
  end
end

function M.startHydraulicRam(playerX, playerY)
  local b = M.boss
  b.ramCharging = true
  b.ramTimer = 1.5  -- Telegraph
end

-- ============================================================
-- ARC WELDER (Phase 10+) - beam sweep across screen
-- ============================================================

function M.updateArcWelder(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 10 then return end

  if b.arcWelderActive then
    b.arcWelderTimer = b.arcWelderTimer - dt
    b.arcWelderAngle = b.arcWelderAngle + b.arcWelderSweepDir * 1.5 * dt

    -- Fire projectiles along beam path
    local beamEndX = b.x + math.cos(b.arcWelderAngle) * 600
    local beamEndY = b.y + math.sin(b.arcWelderAngle) * 600
    for seg = 1, 5 do
      local t = seg / 5
      table.insert(b.pendingProjectiles, {
        type = "arcWelder",
        x = b.x + (beamEndX - b.x) * t,
        y = b.y + (beamEndY - b.y) * t,
        angle = b.arcWelderAngle + math.pi / 2,
        speed = 50,
        damage = DAMAGE.arcWelder
      })
    end

    if b.arcWelderTimer <= 0 then
      b.arcWelderActive = false
    end
  end
end

function M.startArcWelder()
  local b = M.boss
  b.arcWelderActive = true
  b.arcWelderTimer = 2.5
  b.arcWelderAngle = math.pi / 4
  b.arcWelderSweepDir = math.random() > 0.5 and 1 or -1
end

-- ============================================================
-- MAGNETIC PULL (Phase 11+) - gravity well
-- ============================================================

function M.updateMagnet(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 11 then return end

  if b.magnetActive then
    b.magnetTimer = b.magnetTimer - dt
    b.magnetPullStrength = 180 + b.phase * 15
    if b.enraged then b.magnetPullStrength = b.magnetPullStrength * 1.5 end

    if b.magnetTimer <= 0 then
      b.magnetActive = false
      b.magnetCooldown = b.enraged and 5 or 8
      -- Slam at end
      b.shouldAttack = true
      b.currentAttack = "magnetSlam"
    end
  else
    b.magnetCooldown = b.magnetCooldown - dt
    if b.magnetCooldown <= 0 and not b.nanoSwarmActive and not b.coreBeamCharging and not b.annihilationCharging then
      b.magnetActive = true
      b.magnetTimer = 3.5
    end
  end
end

-- ============================================================
-- CONVEYORS (Phase 12+) - push player toward hazards
-- ============================================================

function M.updateConveyors(dt)
  local b = M.boss
  if b.phase < 12 then return end

  b.conveyorSpawnTimer = b.conveyorSpawnTimer - dt

  if b.conveyorSpawnTimer <= 0 and #b.conveyors < 3 then
    b.conveyorSpawnTimer = 8
    local dir = math.random() > 0.5 and 1 or -1
    table.insert(b.conveyors, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(300, screen.HEIGHT - 100),
      width = 200,
      height = 40,
      direction = dir,
      speed = 100 + b.phase * 8,
      lifetime = 10
    })
  end

  for i = #b.conveyors, 1, -1 do
    local conv = b.conveyors[i]
    conv.lifetime = conv.lifetime - dt
    if conv.lifetime <= 0 then
      table.remove(b.conveyors, i)
    end
  end
end

-- ============================================================
-- TURBINE BLADES (Phase 13+) - high damage spinning zones
-- ============================================================

function M.updateTurbines(dt)
  local b = M.boss
  if b.phase < 13 then return end

  b.turbineSpawnTimer = b.turbineSpawnTimer - dt

  if b.turbineSpawnTimer <= 0 and #b.turbines < 2 then
    b.turbineSpawnTimer = b.enraged and 4 or 7
    table.insert(b.turbines, {
      x = math.random(150, screen.WIDTH - 150),
      y = -20,
      radius = 45,
      spinAngle = 0,
      scrollSpeed = 50 + b.phase * 4,
      lifetime = 12
    })
  end

  for i = #b.turbines, 1, -1 do
    local turb = b.turbines[i]
    turb.lifetime = turb.lifetime - dt
    turb.spinAngle = turb.spinAngle + 10 * dt
    turb.y = turb.y + turb.scrollSpeed * dt

    if turb.lifetime <= 0 or turb.y > screen.HEIGHT + 60 then
      table.remove(b.turbines, i)
    end
  end
end

-- ============================================================
-- PRESSURE BLOW (Phase 14+) - area explosion
-- ============================================================

function M.updatePressure(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 14 then return end

  if b.pressureCharging then
    b.pressureTimer = b.pressureTimer - dt
    if b.pressureTimer <= 0 then
      b.pressureCharging = false
      -- Radial explosion
      for i = 0, 15 do
        local angle = (i / 16) * math.pi * 2
        table.insert(b.pendingProjectiles, {
          type = "pressureBlow",
          x = b.x,
          y = b.y + 30,
          angle = angle,
          speed = 350,
          damage = DAMAGE.pressureBlow
        })
      end
      b.shouldAttack = true
      b.currentAttack = "pressureBlow"
    end
  end
end

function M.startPressure()
  local b = M.boss
  b.pressureCharging = true
  b.pressureTimer = b.pressureDuration
end

-- ============================================================
-- QUANTUM SHEAR (Phase 15+) - reality cut lines
-- ============================================================

function M.updateQuantumCuts(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 15 then return end

  b.quantumCutTimer = b.quantumCutTimer - dt

  if b.quantumCutTimer <= 0 and #b.quantumCuts < 3 then
    b.quantumCutTimer = b.enraged and 2 or 4
    local isVertical = math.random() > 0.5
    table.insert(b.quantumCuts, {
      x = isVertical and math.random(100, screen.WIDTH - 100) or 0,
      y = isVertical and 0 or math.random(200, screen.HEIGHT - 100),
      isVertical = isVertical,
      width = isVertical and 6 or screen.WIDTH,
      height = isVertical and screen.HEIGHT or 6,
      lifetime = 3,
      warmup = 1.0,  -- Telegraph time
      damage = DAMAGE.quantumShear,
      damageTimer = 0
    })
  end

  for i = #b.quantumCuts, 1, -1 do
    local cut = b.quantumCuts[i]
    cut.lifetime = cut.lifetime - dt
    cut.warmup = cut.warmup - dt
    cut.damageTimer = cut.damageTimer - dt
    if cut.lifetime <= 0 then
      table.remove(b.quantumCuts, i)
    end
  end
end

-- ============================================================
-- TIME DILATION (Phase 16+) - slow fields
-- ============================================================

function M.updateTimeFields(dt)
  local b = M.boss
  if b.phase < 16 then return end

  b.timeFieldTimer = b.timeFieldTimer - dt

  if b.timeFieldTimer <= 0 and #b.timeFields < 2 then
    b.timeFieldTimer = b.enraged and 3 or 6
    table.insert(b.timeFields, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(250, screen.HEIGHT - 100),
      radius = 80,
      lifetime = 8,
      damage = DAMAGE.timeDilation,
      damageTimer = 0,
      slowFactor = 0.4  -- Player moves at 40% speed inside
    })
  end

  for i = #b.timeFields, 1, -1 do
    local field = b.timeFields[i]
    field.lifetime = field.lifetime - dt
    field.damageTimer = field.damageTimer - dt
    if field.lifetime <= 0 then
      table.remove(b.timeFields, i)
    end
  end
end

-- ============================================================
-- NANO SWARM (Phase 17+) - tracking flurry (like Waterfowl Dance)
-- ============================================================

function M.updateNanoSwarm(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 17 then return end

  if b.nanoSwarmActive then
    b.nanoSwarmTimer = b.nanoSwarmTimer - dt

    if b.nanoSwarmTimer <= 0 and b.nanoSwarmHits < b.nanoSwarmMaxHits then
      b.nanoSwarmHits = b.nanoSwarmHits + 1
      b.nanoSwarmTimer = 0.12

      -- Dash toward target
      local dx = b.nanoSwarmTargetX - b.x
      local dy = b.nanoSwarmTargetY - b.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 10 then
        b.x = b.x + (dx / dist) * 50
        b.y = b.y + (dy / dist) * 30
      end

      table.insert(b.pendingProjectiles, {
        type = "nanoSwarm",
        x = b.x,
        y = b.y + 50,
        angle = math.atan2(playerY - b.y, playerX - b.x) + (math.random() - 0.5) * 0.5,
        speed = 350,
        damage = DAMAGE.assemblySwarm
      })

      b.shouldAttack = true
      b.currentAttack = "nanoSwarm"
    end

    if b.nanoSwarmHits >= b.nanoSwarmMaxHits then
      b.nanoSwarmActive = false
      b.baseX = b.x
    end
  end
end

function M.startNanoSwarm(playerX, playerY)
  local b = M.boss
  b.nanoSwarmActive = true
  b.nanoSwarmHits = 0
  b.nanoSwarmTimer = 0.8  -- Wind-up telegraph
  b.nanoSwarmTargetX = playerX
  b.nanoSwarmTargetY = playerY
  b.nanoSwarmMaxHits = b.enraged and 16 or 12
end

-- ============================================================
-- CORE BEAM (Phase 18+) - near-instant kill charged beam
-- ============================================================

function M.updateCoreBeam(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 18 then return end

  if b.coreBeamCharging then
    b.coreBeamTimer = b.coreBeamTimer - dt
    if b.coreBeamTimer <= 0 then
      b.coreBeamCharging = false
      local angle = math.atan2(b.coreBeamTargetY - b.y, b.coreBeamTargetX - b.x)
      table.insert(b.pendingProjectiles, {
        type = "coreBeam",
        x = b.x,
        y = b.y + 60,
        angle = angle,
        speed = 600,
        damage = DAMAGE.coreBeam,
        width = 50
      })
      b.shouldAttack = true
      b.currentAttack = "coreBeam"
    end
  end
end

function M.startCoreBeam(playerX, playerY)
  local b = M.boss
  b.coreBeamCharging = true
  b.coreBeamTimer = b.coreBeamDuration
  b.coreBeamTargetX = playerX
  b.coreBeamTargetY = playerY
end

-- ============================================================
-- DIMENSION RIFTS (Phase 19+) - portals that fire at player
-- ============================================================

function M.updateRifts(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 19 then return end

  b.riftSpawnTimer = b.riftSpawnTimer - dt

  if b.riftSpawnTimer <= 0 and #b.rifts < 4 then
    b.riftSpawnTimer = b.enraged and 2 or 4
    table.insert(b.rifts, {
      x = math.random(80, screen.WIDTH - 80),
      y = math.random(150, screen.HEIGHT - 80),
      radius = 30,
      lifetime = 6,
      attackTimer = 1.0,
      attackCooldown = 1.2
    })
  end

  for i = #b.rifts, 1, -1 do
    local rift = b.rifts[i]
    rift.lifetime = rift.lifetime - dt
    rift.attackTimer = rift.attackTimer - dt

    if rift.attackTimer <= 0 then
      rift.attackTimer = rift.attackCooldown
      local angle = math.atan2(playerY - rift.y, playerX - rift.x)
      for spread = -1, 1 do
        table.insert(b.pendingProjectiles, {
          type = "dimensionRift",
          x = rift.x,
          y = rift.y,
          angle = angle + spread * 0.2,
          speed = 300,
          damage = DAMAGE.dimensionRift
        })
      end
    end

    if rift.lifetime <= 0 then
      table.remove(b.rifts, i)
    end
  end
end

-- ============================================================
-- ANNIHILATION PULSE (Phase 20+) - screen-wide blast with safe zone
-- ============================================================

function M.updateAnnihilation(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 20 then return end

  if b.annihilationCharging then
    b.annihilationTimer = b.annihilationTimer - dt
    if b.annihilationTimer <= 0 then
      b.annihilationCharging = false
      -- Screen-wide blast except safe zone
      table.insert(b.pendingProjectiles, {
        type = "annihilationPulse",
        x = b.x,
        y = b.y,
        damage = DAMAGE.annihilationPulse,
        safeX = b.annihilationSafeX,
        safeY = b.annihilationSafeY,
        safeRadius = b.annihilationSafeRadius
      })
      b.shouldAttack = true
      b.currentAttack = "annihilationPulse"
    end
  end
end

function M.startAnnihilation(playerX, playerY)
  local b = M.boss
  b.annihilationCharging = true
  b.annihilationTimer = b.annihilationDuration
  -- Safe zone is deliberately NOT at player position — must move to it
  b.annihilationSafeX = math.random(150, screen.WIDTH - 150)
  b.annihilationSafeY = math.random(300, screen.HEIGHT - 100)
  b.annihilationSafeRadius = b.enraged and 60 or 80
end

-- ============================================================
-- ATTACK SELECTION
-- ============================================================

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.nanoSwarmActive or b.magnetActive or b.coreBeamCharging then return end
  if b.annihilationCharging or b.ramActive or b.ramCharging then return end
  if b.drillCharging or b.overclockActive or b.chainSawActive then return end
  if b.arcWelderActive or b.pressureCharging then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1.0 + b.phase * 0.04
  if b.enraged then attackSpeed = attackSpeed * 1.8 end
  local baseCooldown = 2.2 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  -- ============ ACT I: THE AWAKENING (Phases 1-7) ============
  if b.phase == 1 then
    M.fireGrindBlades(playerX, playerY)

  elseif b.phase == 2 then
    if roll < 50 then
      M.fireGrindBlades(playerX, playerY)
    else
      M.firePistonStrike(playerX, playerY)
    end

  elseif b.phase == 3 then
    if roll < 40 then
      M.fireGrindBlades(playerX, playerY)
    elseif roll < 70 then
      M.firePistonStrike(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 4 then
    if roll < 30 then
      M.fireGrindBlades(playerX, playerY)
    elseif roll < 55 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.firePistonStrike(playerX, playerY)
    end

  elseif b.phase == 5 then
    if roll < 25 then
      M.startChainSaw()
    elseif roll < 50 then
      M.fireGrindBlades(playerX, playerY)
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.firePistonStrike(playerX, playerY)
    end

  elseif b.phase == 6 then
    if roll < 20 then
      M.startDrill(playerX, playerY)
    elseif roll < 40 then
      M.startChainSaw()
    elseif roll < 60 then
      M.fireGrindBlades(playerX, playerY)
    elseif roll < 80 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end

  elseif b.phase == 7 then
    if roll < 20 then
      M.startOverclock()
    elseif roll < 40 then
      M.startDrill(playerX, playerY)
    elseif roll < 55 then
      M.startChainSaw()
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end

  -- ============ ACT II: THE FORGE (Phases 8-14) ============
  elseif b.phase == 8 then
    if roll < 30 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 50 then
      M.startOverclock()
    elseif roll < 70 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.startDrill(playerX, playerY)
    end

  elseif b.phase == 9 then
    if roll < 25 and b.ramCooldown <= 0 then
      M.startHydraulicRam(playerX, playerY)
    elseif roll < 45 then
      M.startOverclock()
    elseif roll < 65 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end

  elseif b.phase == 10 then
    if roll < 20 then
      M.startArcWelder()
    elseif roll < 40 and b.ramCooldown <= 0 then
      M.startHydraulicRam(playerX, playerY)
    elseif roll < 60 then
      M.startOverclock()
    else
      M.fireSweepPattern(playerX, playerY)
    end

  elseif b.phase == 11 then
    if roll < 25 then
      M.startArcWelder()
    elseif roll < 45 and b.ramCooldown <= 0 then
      M.startHydraulicRam(playerX, playerY)
    elseif roll < 65 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startOverclock()
    end

  elseif b.phase == 12 then
    if roll < 20 then
      M.startArcWelder()
    elseif roll < 40 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 60 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startOverclock()
    end

  elseif b.phase == 13 then
    if roll < 20 then
      M.startArcWelder()
    elseif roll < 35 and b.ramCooldown <= 0 then
      M.startHydraulicRam(playerX, playerY)
    elseif roll < 55 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startDrill(playerX, playerY)
    end

  elseif b.phase == 14 then
    if roll < 20 then
      M.startPressure()
    elseif roll < 35 then
      M.startArcWelder()
    elseif roll < 50 and b.ramCooldown <= 0 then
      M.startHydraulicRam(playerX, playerY)
    elseif roll < 70 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.startOverclock()
    end

  -- ============ ACT III: THE SINGULARITY (Phases 15-21) ============
  elseif b.phase == 15 then
    if roll < 20 then
      M.startPressure()
    elseif roll < 40 then
      M.fireSweepPattern(playerX, playerY)
    elseif roll < 60 then
      M.startArcWelder()
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 16 then
    if roll < 20 then
      M.startPressure()
    elseif roll < 40 then
      M.startArcWelder()
    elseif roll < 55 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 17 then
    if roll < 25 then
      M.startNanoSwarm(playerX, playerY)
    elseif roll < 40 then
      M.startPressure()
    elseif roll < 55 then
      M.startArcWelder()
    elseif roll < 75 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 18 then
    if roll < 20 then
      M.startCoreBeam(playerX, playerY)
    elseif roll < 40 then
      M.startNanoSwarm(playerX, playerY)
    elseif roll < 55 then
      M.startPressure()
    elseif roll < 75 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.startArcWelder()
    end

  elseif b.phase == 19 then
    if roll < 20 then
      M.startCoreBeam(playerX, playerY)
    elseif roll < 35 then
      M.startNanoSwarm(playerX, playerY)
    elseif roll < 50 then
      M.startPressure()
    elseif roll < 70 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.startArcWelder()
    end

  elseif b.phase == 20 then
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      M.startAnnihilation(playerX, playerY)
    else
      if roll < 25 then
        M.startCoreBeam(playerX, playerY)
      elseif roll < 45 then
        M.startNanoSwarm(playerX, playerY)
      elseif roll < 65 then
        M.fireSweepPattern(playerX, playerY)
      else
        M.startPressure()
      end
    end

  else
    -- Phase 21: GOD MACHINE — Everything, combos, rage
    b.comboCount = b.comboCount + 1
    if b.comboCount >= b.comboMax then
      b.comboCount = 0
      if roll < 33 then
        M.startAnnihilation(playerX, playerY)
      elseif roll < 66 then
        M.startCoreBeam(playerX, playerY)
      else
        M.startNanoSwarm(playerX, playerY)
      end
    else
      if roll < 15 then
        M.startPressure()
      elseif roll < 30 then
        M.startArcWelder()
      elseif roll < 45 and b.ramCooldown <= 0 then
        M.startHydraulicRam(playerX, playerY)
      elseif roll < 60 then
        M.fireSweepPattern(playerX, playerY)
      elseif roll < 75 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.startOverclock()
      end
    end
    b.attackTimer = 0.6  -- Extremely fast in God Machine
  end
end

-- ============================================================
-- PROJECTILE PATTERNS
-- ============================================================

function M.fireGrindBlades(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.grindBlade
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  local count = 3 + math.floor(b.phase / 4)
  for i = 1, count do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + (i - (count + 1) / 2) * 0.25
    table.insert(b.pendingProjectiles, {
      type = "grindBlade",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 320,
      damage = damage
    })
  end
  b.shouldAttack = true
  b.currentAttack = "grindBlade"
end

function M.firePistonStrike(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.pistonStrike
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- 4 directional shockwave
  for i = 0, 3 do
    local angle = math.pi / 2 + i * (math.pi / 2)
    table.insert(b.pendingProjectiles, {
      type = "pistonStrike",
      x = b.x,
      y = b.y + 60,
      angle = angle,
      speed = 280,
      damage = damage
    })
  end
  b.shouldAttack = true
  b.currentAttack = "pistonStrike"
end

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.grindBlade
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  local count = b.enraged and 9 or (5 + math.floor(b.phase / 5))
  for i = 1, count do
    local angle = math.pi / 2 + ((i - (count + 1) / 2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 280,
      damage = damage
    })
  end
  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.overclockBurst
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  local count = 12 + math.floor(b.phase / 3)
  for i = 0, count - 1 do
    local angle = math.pi / 2 - 0.8 + (i * 1.6 / count)
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 380,
      damage = damage,
      delay = i * 0.06
    })
  end
  b.shouldAttack = true
  b.currentAttack = "sweep"
end

-- ============================================================
-- DAMAGE SYSTEM
-- ============================================================

function M.damage(amount, hitArm)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Phase 1-4: Armor plating must be destroyed first
  if b.phase <= 4 and not b.leftArmor.destroyed and not b.rightArmor.destroyed then
    if hitArm == "left" then
      b.leftArmor.health = b.leftArmor.health - amount
      if b.leftArmor.health <= 0 then
        b.leftArmor.destroyed = true
      end
      return false
    elseif hitArm == "right" then
      b.rightArmor.health = b.rightArmor.health - amount
      if b.rightArmor.health <= 0 then
        b.rightArmor.destroyed = true
      end
      return false
    end
    -- If no arm specified but armor up, reduced damage
    if not b.leftArmor.destroyed or not b.rightArmor.destroyed then
      amount = math.floor(amount * 0.3)
    end
  end

  -- Phase 8-10: Shield generator blocks damage
  if b.phase >= 8 and b.phase <= 10 and b.shieldGenerator.active and not b.shieldGenerator.destroyed then
    if hitArm == "shield" then
      b.shieldGenerator.health = b.shieldGenerator.health - amount
      if b.shieldGenerator.health <= 0 then
        b.shieldGenerator.destroyed = true
        b.shieldGenerator.active = false
      end
      return false
    end
    -- Reduced damage while shield up
    amount = math.floor(amount * 0.2)
  end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- ============================================================
-- QUERY FUNCTIONS FOR INIT.LUA COLLISION HANDLING
-- ============================================================

function M.getGravityPull()
  local b = M.boss
  if not b or not b.magnetActive then
    return 0, 0, 0
  end
  return b.x, b.y, b.magnetPullStrength
end

function M.checkSteamVentDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, vent in ipairs(b.steamVents) do
    local dx = playerX - vent.x
    local dy = playerY - vent.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < vent.radius + playerRadius and vent.damageTimer <= 0 then
      vent.damageTimer = 0.5
      totalDamage = totalDamage + vent.damage
    end
  end
  return totalDamage
end

function M.checkSlagZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.slagZones) do
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

function M.checkGearDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  for _, gear in ipairs(b.gears) do
    local dx = playerX - gear.x
    local dy = playerY - gear.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < gear.radius + playerRadius then
      return DAMAGE.gearCrush
    end
  end
  return 0
end

function M.checkTurbineDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  for _, turb in ipairs(b.turbines) do
    local dx = playerX - turb.x
    local dy = playerY - turb.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < turb.radius + playerRadius then
      return DAMAGE.turbineBlade
    end
  end
  return 0
end

function M.checkConveyorPush(playerX, playerY)
  local b = M.boss
  if not b then return 0, 0 end

  for _, conv in ipairs(b.conveyors) do
    if playerX > conv.x - conv.width / 2 and playerX < conv.x + conv.width / 2
       and playerY > conv.y - conv.height / 2 and playerY < conv.y + conv.height / 2 then
      return conv.direction * conv.speed, 0
    end
  end
  return 0, 0
end

function M.checkQuantumCutDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  for _, cut in ipairs(b.quantumCuts) do
    if cut.warmup <= 0 and cut.damageTimer <= 0 then
      local hit = false
      if cut.isVertical then
        if math.abs(playerX - cut.x) < cut.width / 2 + playerRadius then
          hit = true
        end
      else
        if math.abs(playerY - cut.y) < cut.height / 2 + playerRadius then
          hit = true
        end
      end
      if hit then
        cut.damageTimer = 0.3
        return cut.damage
      end
    end
  end
  return 0
end

function M.checkTimeFieldSlow(playerX, playerY)
  local b = M.boss
  if not b then return 1 end

  for _, field in ipairs(b.timeFields) do
    local dx = playerX - field.x
    local dy = playerY - field.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < field.radius then
      return field.slowFactor
    end
  end
  return 1
end

function M.checkTimeFieldDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, field in ipairs(b.timeFields) do
    local dx = playerX - field.x
    local dy = playerY - field.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < field.radius + playerRadius and field.damageTimer <= 0 then
      field.damageTimer = 1.0
      totalDamage = totalDamage + field.damage
    end
  end
  return totalDamage
end

function M.checkBarrierCollision(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return false end

  for _, bar in ipairs(b.barriers) do
    -- Rotated rectangle collision approximation
    local dx = playerX - bar.x
    local dy = playerY - bar.y
    local cos_a = math.cos(bar.angle)
    local sin_a = math.sin(bar.angle)
    local localX = math.abs(dx * cos_a + dy * sin_a)
    local localY = math.abs(-dx * sin_a + dy * cos_a)
    if localX < bar.width / 2 + playerRadius and localY < bar.height / 2 + playerRadius then
      return true
    end
  end
  return false
end

function M.getArmorPositions()
  local b = M.boss
  if not b then return {} end
  local positions = {}
  if not b.leftArmor.destroyed then
    table.insert(positions, {
      x = b.x - 80, y = b.y,
      width = 35, height = 80,
      idx = "left", health = b.leftArmor.health, maxHealth = b.leftArmor.maxHealth
    })
  end
  if not b.rightArmor.destroyed then
    table.insert(positions, {
      x = b.x + 80, y = b.y,
      width = 35, height = 80,
      idx = "right", health = b.rightArmor.health, maxHealth = b.rightArmor.maxHealth
    })
  end
  return positions
end

function M.getShieldPosition()
  local b = M.boss
  if not b or not b.shieldGenerator.active or b.shieldGenerator.destroyed then return nil end
  return {
    x = b.x, y = b.y - 50,
    width = 50, height = 30,
    health = b.shieldGenerator.health, maxHealth = b.shieldGenerator.maxHealth
  }
end

function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.coreBeamCharging then
    return "CORE BEAM", b.coreBeamTimer / b.coreBeamDuration
  elseif b.annihilationCharging then
    return "ANNIHILATION PULSE", b.annihilationTimer / b.annihilationDuration
  elseif b.drillCharging then
    return "DRILL LANCE", b.drillTimer / b.drillDuration
  elseif b.pressureCharging then
    return "PRESSURE BLOW", b.pressureTimer / b.pressureDuration
  elseif b.magnetActive then
    return "MAGNETIC STORM", b.magnetTimer / 3.5
  elseif b.nanoSwarmActive and b.nanoSwarmHits == 0 then
    return "NANO SWARM", 1
  elseif b.ramCharging then
    return "HYDRAULIC RAM", b.ramTimer / 1.5
  elseif b.arcWelderActive then
    return "ARC WELDER", b.arcWelderTimer / 2.5
  end

  return nil
end

return M
