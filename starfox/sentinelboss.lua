local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- Phase damage values (Elden Ring style - high-tech sentinel guardian)
local DAMAGE = {
  scanBeam = 10,           -- Phase 1: Scanning beam arcs
  lockOnMissile = 14,      -- Phase 2: Targeted lock-on missiles
  empPulse = 8,            -- Phase 3: EMP zone DOT per tick
  droneStrike = 16,        -- Phase 4: Orbital drone lance fire
  singularityBlast = 22,   -- Phase 5: Singularity protocol attacks
  overrideSweep = 28,      -- Phase 5: Override sweep beam
}

-- Phase HP thresholds (out of 300 total, 5 phases)
local PHASE_THRESHOLDS = {300, 240, 175, 110, 50}

-- Drone shield health
local DRONE_SHIELD_MAX = 35

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -160,
    width = 150,
    height = 115,
    health = 300,
    maxHealth = 300,
    score = 14000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 95,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Phase Warp)
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 5.5,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 95,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack states
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Phase 1: Scan Beam - sweeping laser arcs
    scanActive = false,
    scanAngle = 0,
    scanSweeps = 0,

    -- Phase 2: Lock-On Missiles - tracking projectiles
    lockOnTimer = 0,
    lockOnTargetX = 0,
    lockOnTargetY = 0,
    lockOnCharging = false,
    lockOnChargeDuration = 1.8,

    -- Phase 3: EMP Zones - disabling field areas
    empZones = {},
    empSpawnTimer = 0,

    -- Phase 4: Orbital Drones - circling attack units
    drones = {},
    droneTimer = 0,
    droneCooldown = 6,

    -- Phase 5: Singularity Protocol - overcharged mode
    singularity = false,
    rageMultiplier = 1.7,
    singularityPulse = 0,
    gravityWellActive = false,
    gravityTimer = 0,
    gravityCooldown = 8,
    gravityPullStrength = 0,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Drone shields (must destroy to expose core)
    leftGuard = {health = DRONE_SHIELD_MAX, x = -60, destroyed = false},
    rightGuard = {health = DRONE_SHIELD_MAX, x = 60, destroyed = false},
    guardsDown = false,
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
    b.y = b.y + 75 * dt
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
  M.updateEmpZones(dt)
  M.updateDrones(dt, playerX, playerY)
  M.updateLockOn(dt, playerX, playerY)
  M.updateGravity(dt, playerX, playerY)
  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
end

function M.updatePhase()
  local b = M.boss
  local oldPhase = b.phase

  for i = 5, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      b.phase = i
      break
    end
  end

  if b.phase > oldPhase then
    b.phaseTransitioning = true
    b.transitionTimer = 1.5
    -- Cancel active attacks
    b.scanActive = false
    b.lockOnCharging = false
    b.gravityWellActive = false
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 5 then
    b.singularity = true
  end

  -- Reset attack timer
  b.attackTimer = 1.5
end

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end

  local speed = 1.3
  if b.phase >= 3 then speed = 1.9 end
  if b.phase >= 4 then speed = 2.3 end
  if b.singularity then speed = 3.0 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 130 + (b.phase * 22)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Clamp to screen
  b.x = math.max(b.width / 2, math.min(screen.WIDTH - b.width / 2, b.x))

  -- Vertical hover bob in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.6) * 30
  end

  -- Singularity pulse
  if b.singularity then
    b.singularityPulse = b.singularityPulse + dt * 8
  end
end

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.gravityWellActive then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 4.5
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      -- Fire lock-on missiles on reappear
      if b.phase >= 2 then
        b.shouldAttack = true
        b.currentAttack = "lockOnMissile"
        table.insert(b.pendingProjectiles, {
          type = "lockOnMissile",
          x = b.x,
          y = b.y + 55,
          targetX = playerX,
          targetY = playerY,
          damage = DAMAGE.lockOnMissile
        })
      end
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 4.5
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    local cooldown = b.teleportCooldown
    if b.singularity then cooldown = cooldown * 0.4 end

    if b.teleportTimer <= 0 then
      M.startTeleport(playerX, playerY)
      b.teleportTimer = cooldown
    end
  end
end

function M.startTeleport(playerX, playerY)
  local b = M.boss
  b.teleporting = true

  -- Sentinel warps to strategic overwatch positions
  local angle = math.random() * math.pi * 2
  local dist = 140
  b.teleportTargetX = math.max(80, math.min(screen.WIDTH - 80, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(55, math.min(230, playerY - 100))
end

function M.updateEmpZones(dt)
  local b = M.boss
  if b.phase < 3 then return end

  -- Spawn EMP zones periodically
  b.empSpawnTimer = b.empSpawnTimer - dt
  local spawnRate = b.singularity and 2.0 or 4.0

  if b.empSpawnTimer <= 0 and #b.empZones < 5 then
    b.empSpawnTimer = spawnRate
    table.insert(b.empZones, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(250, screen.HEIGHT - 80),
      radius = 50,
      lifetime = 7.5,
      damage = DAMAGE.empPulse,
      damageTimer = 0,
      pulsePhase = math.random() * math.pi * 2,
    })
  end

  -- Update zones
  for i = #b.empZones, 1, -1 do
    local zone = b.empZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt

    if zone.lifetime <= 0 then
      table.remove(b.empZones, i)
    end
  end
end

function M.updateDrones(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  -- Update existing drones
  for i = #b.drones, 1, -1 do
    local d = b.drones[i]
    d.timer = d.timer - dt
    d.orbitAngle = d.orbitAngle + d.orbitSpeed * dt

    -- Drones orbit the boss
    d.x = b.x + math.cos(d.orbitAngle) * d.orbitRadius
    d.y = b.y + math.sin(d.orbitAngle) * d.orbitRadius * 0.6

    -- Drone fires at player
    d.attackTimer = d.attackTimer - dt
    if d.attackTimer <= 0 then
      d.attackTimer = b.singularity and 1.0 or 1.8
      table.insert(b.pendingProjectiles, {
        type = "droneStrike",
        x = d.x,
        y = d.y,
        targetX = playerX,
        targetY = playerY,
        damage = DAMAGE.droneStrike
      })
      b.shouldAttack = true
      b.currentAttack = "droneStrike"
    end

    if d.timer <= 0 then
      table.remove(b.drones, i)
    end
  end

  -- Spawn new drones
  b.droneTimer = b.droneTimer - dt
  if b.droneTimer <= 0 and #b.drones < 4 then
    b.droneTimer = b.singularity and 3.5 or b.droneCooldown
    table.insert(b.drones, {
      x = b.x,
      y = b.y,
      orbitAngle = math.random() * math.pi * 2,
      orbitSpeed = 1.5 + math.random() * 1.5,
      orbitRadius = 100 + math.random() * 50,
      timer = 7,
      attackTimer = 1.2,
    })
  end
end

function M.updateLockOn(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end

  if b.lockOnCharging then
    b.lockOnTimer = b.lockOnTimer - dt
    -- Track player position during charge
    b.lockOnTargetX = playerX
    b.lockOnTargetY = playerY

    if b.lockOnTimer <= 0 then
      b.lockOnCharging = false
      -- Fire burst of lock-on missiles
      local count = b.singularity and 5 or 3
      for i = 1, count do
        local spreadAngle = ((i - (count + 1) / 2) * 0.15)
        table.insert(b.pendingProjectiles, {
          type = "lockOnMissile",
          x = b.x + (i - (count + 1) / 2) * 20,
          y = b.y + 45,
          targetX = b.lockOnTargetX + (math.random() - 0.5) * 30,
          targetY = b.lockOnTargetY + (math.random() - 0.5) * 30,
          damage = DAMAGE.lockOnMissile
        })
      end
      b.shouldAttack = true
      b.currentAttack = "lockOnMissile"
    end
  end
end

function M.startLockOn(playerX, playerY)
  local b = M.boss
  b.lockOnCharging = true
  b.lockOnTimer = b.singularity and 1.0 or b.lockOnChargeDuration
  b.lockOnTargetX = playerX
  b.lockOnTargetY = playerY
end

function M.updateGravity(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then return end

  if b.gravityWellActive then
    b.gravityTimer = b.gravityTimer - dt
    b.gravityPullStrength = 180 + (b.phase * 25)

    if b.gravityTimer <= 0 then
      b.gravityWellActive = false
      b.gravityCooldown = 7
      -- Singularity slam at end
      b.shouldAttack = true
      b.currentAttack = "singularitySlam"
    end
  else
    b.gravityCooldown = b.gravityCooldown - dt
    if b.gravityCooldown <= 0 and not b.lockOnCharging then
      b.gravityWellActive = true
      b.gravityTimer = 2.5
    end
  end
end

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.lockOnCharging or b.gravityWellActive then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 3 then attackSpeed = 1.3 end
  if b.phase >= 4 then attackSpeed = 1.5 end
  if b.singularity then attackSpeed = 2.0 end

  local baseCooldown = 2.4 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Perimeter Scan - scan beam arcs only
    if roll < 60 then
      M.fireScanBeam(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 2 then
    -- Phase 2: Threat Analysis - scan + lock-on missiles
    if roll < 40 then
      M.fireScanBeam(playerX, playerY)
    elseif roll < 70 then
      M.startLockOn(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: Containment Protocol - EMP zones + all attacks
    if roll < 35 then
      M.fireScanBeam(playerX, playerY)
    elseif roll < 55 then
      M.startLockOn(playerX, playerY)
    elseif roll < 75 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: Override Mode - orbital drones + sweeps
    if roll < 25 then
      M.fireScanBeam(playerX, playerY)
    elseif roll < 45 then
      M.startLockOn(playerX, playerY)
    elseif roll < 65 then
      M.fireSpreadPattern(playerX, playerY)
    elseif roll < 80 then
      M.fireSweepPattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  else
    -- Phase 5: Singularity Protocol - everything faster, gravity, combos
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      -- Singularity combo: lock-on + sweep barrage
      M.startLockOn(playerX, playerY)
    else
      if roll < 25 then
        M.fireScanBeam(playerX, playerY)
      elseif roll < 45 then
        M.fireSpreadPattern(playerX, playerY)
      elseif roll < 65 then
        M.fireSweepPattern(playerX, playerY)
      elseif roll < 80 then
        M.fireSingularityBurst(playerX, playerY)
      else
        M.startTeleport(playerX, playerY)
      end
    end
    b.attackTimer = 0.6  -- Relentless in singularity
  end
end

-- Phase 1+: Scan Beam - 3 arcing laser sweeps
function M.fireScanBeam(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.scanBeam
  if b.singularity then damage = math.floor(damage * b.rageMultiplier) end

  local count = b.singularity and 5 or 3
  for i = 1, count do
    local offset = (i - (count + 1) / 2) * 0.3
    local angle = math.atan2(playerY - b.y, playerX - b.x) + offset
    table.insert(b.pendingProjectiles, {
      type = "scanBeam",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 340,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "scanBeam"
end

-- Phase 1+: Spread pattern - 5-way fan
function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.scanBeam
  if b.singularity then damage = math.floor(damage * b.rageMultiplier) end

  local count = b.singularity and 8 or 5
  for i = 1, count do
    local angle = math.pi / 2 + ((i - (count + 1) / 2) * 0.22)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 290,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "spread"
end

-- Phase 4+: Sweep beam - rapid sequential bolts
function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.singularityBlast

  local count = b.singularity and 12 or 8
  for i = 0, count - 1 do
    local delay = i * 0.06
    local angle = math.pi / 2 - 0.55 + (i * (1.1 / (count - 1)))
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 400,
      damage = damage,
      delay = delay
    })
  end

  b.shouldAttack = true
  b.currentAttack = "overrideSweep"
end

-- Phase 5: Singularity Burst - omnidirectional explosion of projectiles
function M.fireSingularityBurst(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.singularityBlast

  -- 16 projectiles in all directions
  for i = 0, 15 do
    local angle = (i / 16) * math.pi * 2
    table.insert(b.pendingProjectiles, {
      type = "singularityBurst",
      x = b.x,
      y = b.y,
      angle = angle,
      speed = 260,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "singularityBurst"
end

function M.damage(amount, hitArm)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Drone shields absorb damage if not destroyed
  if not b.guardsDown then
    if hitArm == "left" and not b.leftGuard.destroyed then
      b.leftGuard.health = b.leftGuard.health - amount
      if b.leftGuard.health <= 0 then
        b.leftGuard.destroyed = true
      end
      if b.leftGuard.destroyed and b.rightGuard.destroyed then
        b.guardsDown = true
      end
      return false
    elseif hitArm == "right" and not b.rightGuard.destroyed then
      b.rightGuard.health = b.rightGuard.health - amount
      if b.rightGuard.health <= 0 then
        b.rightGuard.destroyed = true
      end
      if b.leftGuard.destroyed and b.rightGuard.destroyed then
        b.guardsDown = true
      end
      return false
    end
    return false
  end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- Check if player is in EMP zone
function M.checkEmpZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.empZones) do
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

-- Get gravity pull vector for player (Phase 5)
function M.getGravityPull()
  local b = M.boss
  if not b or not b.gravityWellActive then
    return 0, 0, 0
  end
  return b.x, b.y, b.gravityPullStrength
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
    return "PHASE SHIFT", b.transitionTimer / 1.5
  elseif b.lockOnCharging then
    local duration = b.singularity and 1.0 or b.lockOnChargeDuration
    return "LOCK-ON ACQUIRED", b.lockOnTimer / duration
  elseif b.gravityWellActive then
    return "GRAVITY WELL", b.gravityTimer / 2.5
  elseif b.teleporting then
    return "PHASE WARP", b.fadeAlpha
  end

  return nil
end

-- Get phase name for display
function M.getPhaseName()
  local b = M.boss
  if not b then return "" end

  local names = {
    "PERIMETER SCAN",
    "THREAT ANALYSIS",
    "CONTAINMENT",
    "OVERRIDE MODE",
    "SINGULARITY"
  }
  return names[b.phase] or ""
end

return M
