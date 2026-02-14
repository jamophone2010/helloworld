local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- Phase damage values (Elden Ring style - punishing but fair)
local DAMAGE = {
  wardenSlash = 12,        -- Phase 1: Sweeping blade arcs
  chainLightning = 8,      -- Phase 2: Chained lightning bolts
  voidPrison = 10,         -- Phase 3: Prison zones DOT per tick
  sentinelStrike = 18,     -- Phase 4: Summoned sentinel lances
  wardenWrath = 25,        -- Phase 5: Enraged full combo
}

-- Phase HP thresholds (out of 250 total, 5 phases)
local PHASE_THRESHOLDS = {250, 200, 140, 80, 30}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -150,
    width = 140,
    height = 110,
    health = 250,
    maxHealth = 250,
    score = 10000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 100,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Warden Phase Shift)
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 6,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 100,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack states
    attackTimer = 3,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Phase 1: Warden Slash - sweeping blade arcs
    slashActive = false,
    slashAngle = 0,
    slashSweeps = 0,

    -- Phase 2: Chain Lightning - branching bolt chains
    lightningChains = {},
    lightningTimer = 0,

    -- Phase 3: Void Prison - trapping zones
    prisonZones = {},
    prisonSpawnTimer = 0,

    -- Phase 4: Sentinel Summon - ghostly lances
    sentinels = {},
    sentinelTimer = 0,
    sentinelCooldown = 7,

    -- Phase 5: Warden's Wrath - enraged mode
    enraged = false,
    rageMultiplier = 1.6,
    wrathPulse = 0,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0,

    -- Shield arms (must destroy to expose core)
    leftGuard = {health = 30, x = -55, destroyed = false},
    rightGuard = {health = 30, x = 55, destroyed = false},
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
    b.y = b.y + 80 * dt
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
  M.updatePrisonZones(dt)
  M.updateSentinels(dt, playerX, playerY)
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
    b.slashActive = false
    b.lightningChains = {}
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 5 then
    b.enraged = true
  end

  -- Reset attack timer
  b.attackTimer = 1.5
end

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn then return end

  local speed = 1.2
  if b.phase >= 3 then speed = 2.0 end
  if b.enraged then speed = 3.0 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 120 + (b.phase * 25)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Vertical bob in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.6) * 35
  end

  -- Wrath pulse in phase 5
  if b.enraged then
    b.wrathPulse = b.wrathPulse + dt * 8
  end
end

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
        b.currentAttack = "chainLightning"
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
    if b.enraged then cooldown = cooldown * 0.5 end

    if b.teleportTimer <= 0 then
      M.startTeleport(playerX, playerY)
      b.teleportTimer = cooldown
    end
  end
end

function M.startTeleport(playerX, playerY)
  local b = M.boss
  b.teleporting = true

  -- Warden phases behind player's flank
  local angle = math.random() * math.pi * 2
  local dist = 130
  b.teleportTargetX = math.max(80, math.min(screen.WIDTH - 80, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(250, playerY - 90))
end

function M.updatePrisonZones(dt)
  local b = M.boss
  if b.phase < 3 then return end

  -- Spawn prison zones periodically
  b.prisonSpawnTimer = b.prisonSpawnTimer - dt
  local spawnRate = b.enraged and 2.5 or 4.5

  if b.prisonSpawnTimer <= 0 and #b.prisonZones < 4 then
    b.prisonSpawnTimer = spawnRate
    table.insert(b.prisonZones, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(200, screen.HEIGHT - 100),
      radius = 55,
      lifetime = 7,
      damage = DAMAGE.voidPrison,
      damageTimer = 0,
      pulsePhase = math.random() * math.pi * 2,
    })
  end

  -- Update zones
  for i = #b.prisonZones, 1, -1 do
    local zone = b.prisonZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt

    if zone.lifetime <= 0 then
      table.remove(b.prisonZones, i)
    end
  end
end

function M.updateSentinels(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  -- Update existing sentinels
  for i = #b.sentinels, 1, -1 do
    local s = b.sentinels[i]
    s.timer = s.timer - dt
    s.angle = s.angle + s.rotSpeed * dt

    -- Sentinel fires lance toward player
    s.attackTimer = s.attackTimer - dt
    if s.attackTimer <= 0 then
      s.attackTimer = b.enraged and 1.2 or 2.0
      table.insert(b.pendingProjectiles, {
        type = "sentinelLance",
        x = s.x,
        y = s.y,
        targetX = playerX,
        targetY = playerY,
        damage = DAMAGE.sentinelStrike
      })
      b.shouldAttack = true
      b.currentAttack = "sentinelStrike"
    end

    if s.timer <= 0 then
      table.remove(b.sentinels, i)
    end
  end

  -- Spawn new sentinels
  b.sentinelTimer = b.sentinelTimer - dt
  if b.sentinelTimer <= 0 and #b.sentinels < 3 then
    b.sentinelTimer = b.enraged and 4 or b.sentinelCooldown
    local sx = math.random(100, screen.WIDTH - 100)
    local sy = math.random(80, 200)
    table.insert(b.sentinels, {
      x = sx,
      y = sy,
      angle = 0,
      rotSpeed = 2 + math.random() * 2,
      timer = 6,
      attackTimer = 1.5,
    })
  end
end

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 3 then attackSpeed = 1.3 end
  if b.enraged then attackSpeed = 1.8 end

  local baseCooldown = 2.2 / attackSpeed

  if b.attackTimer <= 0 then
    b.attackTimer = baseCooldown
    M.chooseAttack(playerX, playerY)
  end
end

function M.chooseAttack(playerX, playerY)
  local b = M.boss
  local roll = math.random(100)

  if b.phase == 1 then
    -- Phase 1: Warden Slash only (sweeping arcs)
    M.fireSlashPattern(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: Slash + Chain Lightning
    if roll < 50 then
      M.fireSlashPattern(playerX, playerY)
    else
      M.fireChainLightning(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: + Void Prison zones (passive) + spread
    if roll < 40 then
      M.fireSlashPattern(playerX, playerY)
    elseif roll < 70 then
      M.fireChainLightning(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: + Sentinel Summons
    if roll < 30 then
      M.fireSlashPattern(playerX, playerY)
    elseif roll < 55 then
      M.fireChainLightning(playerX, playerY)
    elseif roll < 80 then
      M.fireSpreadPattern(playerX, playerY)
    else
      M.fireSweepPattern(playerX, playerY)
    end

  else
    -- Phase 5: Warden's Wrath - everything faster, combos
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      -- Wrath combo: rapid chain + sweep
      M.fireChainLightning(playerX, playerY)
      M.fireSweepPattern(playerX, playerY)
    else
      if roll < 35 then
        M.fireSlashPattern(playerX, playerY)
      elseif roll < 60 then
        M.fireChainLightning(playerX, playerY)
      elseif roll < 85 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.fireSweepPattern(playerX, playerY)
      end
    end
    b.attackTimer = 0.7  -- Faster in wrath
  end
end

function M.fireSlashPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.wardenSlash
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Three blade arcs (sweeping crescent)
  for i = -1, 1 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.35
    table.insert(b.pendingProjectiles, {
      type = "slash",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 320,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "slash"
end

function M.fireChainLightning(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.chainLightning
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Chain of 3-5 bolts in rapid succession
  local count = b.enraged and 5 or 3
  for i = 1, count do
    local spreadAngle = ((i - (count+1)/2) * 0.2)
    local angle = math.atan2(playerY - b.y, playerX - b.x) + spreadAngle
    table.insert(b.pendingProjectiles, {
      type = "lightning",
      x = b.x + (i - (count+1)/2) * 15,
      y = b.y + 40,
      angle = angle,
      speed = 380,
      damage = damage,
      delay = (i - 1) * 0.06,
    })
  end

  b.shouldAttack = true
  b.currentAttack = "chainLightning"
end

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.wardenSlash
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- 5-way fan spread
  local count = b.enraged and 7 or 5
  for i = 1, count do
    local angle = math.pi/2 + ((i - (count+1)/2) * 0.25)
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
  local damage = DAMAGE.wardenWrath

  -- Sweep beam (8 projectiles in quick sequence)
  for i = 0, 7 do
    local delay = i * 0.07
    local angle = math.pi/2 - 0.5 + (i * 0.14)
    table.insert(b.pendingProjectiles, {
      type = "sweep",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 370,
      damage = damage,
      delay = delay
    })
  end

  b.shouldAttack = true
  b.currentAttack = "sweep"
end

function M.damage(amount, hitArm)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  -- Phase 1: Must destroy guard arms first
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

-- Check if player is in prison zone
function M.checkPrisonZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.prisonZones) do
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
  end

  return nil
end

-- Get phase name for display
function M.getPhaseName()
  local b = M.boss
  if not b then return "" end

  local names = {
    "IRON VIGIL",
    "STORM CHAIN",
    "VOID PRISON",
    "SENTINEL CALL",
    "WARDEN'S WRATH"
  }
  return names[b.phase] or ""
end

return M
