local M = {}
local screen = require("starfox.screen")

M.boss = nil

-- Phase damage multipliers (Elden Ring: punish mistakes hard)
local DAMAGE = {
  blade = 15,         -- Blade Dance slash
  shadowStrike = 20,  -- Teleport backstab
  scarletRot = 8,     -- Void Waves DOT per tick
  gravitySlam = 25,   -- Gravity well slam
  waterfowl = 12,     -- Per hit of flurry
  deathBlight = 50,   -- Void Blight near-instant kill
  godSlayer = 18      -- Void Slayer final phase attacks
}

-- Phase HP thresholds (out of 350 total)
local PHASE_THRESHOLDS = {350, 300, 240, 180, 120, 60, 30}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = screen.WIDTH / 2,
    y = -150,
    width = 160,
    height = 120,
    health = 350,
    maxHealth = 350,
    score = 15000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 100,

    -- Movement
    baseX = screen.WIDTH / 2,
    moveAngle = 0,

    -- Teleport (Shadow Step)
    teleporting = false,
    teleportTimer = 0,
    teleportCooldown = 5,
    teleportTargetX = screen.WIDTH / 2,
    teleportTargetY = 100,
    fadeAlpha = 1,
    fadeIn = false,

    -- Attack states
    attackTimer = 3,
    attackPhase = 0,
    currentAttack = nil,
    shouldAttack = false,
    comboCount = 0,

    -- Blade Dance (Phase 1)
    bladeSwinging = false,
    bladeAngle = 0,
    bladeSwings = 0,

    -- Void Waves (Phase 3) - AOE zones
    rotZones = {},
    rotSpawnTimer = 0,

    -- Gravity Well (Phase 4)
    gravityActive = false,
    gravityTimer = 0,
    gravityCooldown = 8,
    gravityPullStrength = 0,

    -- Waterfowl Dance (Phase 5) - rapid flurry
    waterfowlActive = false,
    waterfowlHits = 0,
    waterfowlMaxHits = 9,
    waterfowlTimer = 0,
    waterfowlTargetX = 0,
    waterfowlTargetY = 0,

    -- Void Blight (Phase 6) - delayed high damage
    deathBlightCharging = false,
    deathBlightTimer = 0,
    deathBlightDuration = 2.5,
    deathBlightTargetX = 0,
    deathBlightTargetY = 0,

    -- Void sLAYER (Phase 7) - rage mode
    enraged = false,
    rageMultiplier = 1.5,

    -- Projectile tracking
    pendingProjectiles = {},

    -- Invuln during transitions
    phaseTransitioning = false,
    transitionTimer = 0
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
  M.updateRotZones(dt)
  M.updateGravity(dt, playerX, playerY)
  M.updateWaterfowl(dt, playerX, playerY)
  M.updateDeathBlight(dt, playerX, playerY)
  M.updateAttacks(dt, playerX, playerY)
  M.updateMovement(dt)
end

function M.updatePhase()
  local b = M.boss
  local oldPhase = b.phase

  for i = 7, 1, -1 do
    if b.health <= PHASE_THRESHOLDS[i] then
      b.phase = i
    end
  end

  if b.phase > oldPhase then
    b.phaseTransitioning = true
    b.transitionTimer = 1.5
    -- Cancel active attacks
    b.waterfowlActive = false
    b.gravityActive = false
    b.deathBlightCharging = false
    b.bladeSwinging = false
  end
end

function M.onPhaseStart()
  local b = M.boss

  if b.phase == 7 then
    b.enraged = true
  end

  -- Reset attack timer for new phase
  b.attackTimer = 1.5
end

function M.updateMovement(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.waterfowlActive then return end

  local speed = 1.5
  if b.phase >= 5 then speed = 2.5 end
  if b.enraged then speed = 3.5 end

  b.moveAngle = b.moveAngle + speed * dt
  local range = 150 + (b.phase * 20)
  b.x = b.baseX + math.sin(b.moveAngle) * range

  -- Slight vertical movement in later phases
  if b.phase >= 3 then
    b.y = b.targetY + math.sin(b.moveAngle * 0.7) * 30
  end
end

function M.updateTeleport(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.waterfowlActive or b.gravityActive then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 4
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.y = b.teleportTargetY
      b.baseX = b.x
      b.teleporting = false
      b.fadeIn = true

      -- Shadow strike on appear (backstab)
      if b.phase >= 2 then
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

  -- Teleport to flank player (Elden Ring backstab style)
  local angle = math.random() * math.pi * 2
  local dist = 120
  b.teleportTargetX = math.max(80, math.min(screen.WIDTH - 80, playerX + math.cos(angle) * dist))
  b.teleportTargetY = math.max(60, math.min(250, playerY - 80))
end

function M.updateRotZones(dt)
  local b = M.boss
  if b.phase < 3 then return end

  -- Spawn rot zones periodically
  b.rotSpawnTimer = b.rotSpawnTimer - dt
  local spawnRate = b.enraged and 2 or 4

  if b.rotSpawnTimer <= 0 and #b.rotZones < 5 then
    b.rotSpawnTimer = spawnRate
    table.insert(b.rotZones, {
      x = math.random(100, screen.WIDTH - 100),
      y = math.random(200, screen.HEIGHT - 100),
      radius = 60,
      lifetime = 8,
      damage = DAMAGE.scarletRot,
      damageTimer = 0
    })
  end

  -- Update zones
  for i = #b.rotZones, 1, -1 do
    local zone = b.rotZones[i]
    zone.lifetime = zone.lifetime - dt
    zone.damageTimer = zone.damageTimer - dt

    if zone.lifetime <= 0 then
      table.remove(b.rotZones, i)
    end
  end
end

function M.updateGravity(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 4 then return end

  if b.gravityActive then
    b.gravityTimer = b.gravityTimer - dt
    b.gravityPullStrength = 200 + (b.phase * 30)
    if b.enraged then b.gravityPullStrength = b.gravityPullStrength * 1.5 end

    if b.gravityTimer <= 0 then
      b.gravityActive = false
      b.gravityCooldown = b.enraged and 6 or 10
      -- Slam damage at end
      b.shouldAttack = true
      b.currentAttack = "gravitySlam"
    end
  else
    b.gravityCooldown = b.gravityCooldown - dt
    if b.gravityCooldown <= 0 and not b.waterfowlActive and not b.deathBlightCharging then
      b.gravityActive = true
      b.gravityTimer = 3
    end
  end
end

function M.updateWaterfowl(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 5 then return end

  if b.waterfowlActive then
    b.waterfowlTimer = b.waterfowlTimer - dt

    if b.waterfowlTimer <= 0 and b.waterfowlHits < b.waterfowlMaxHits then
      b.waterfowlHits = b.waterfowlHits + 1
      b.waterfowlTimer = 0.15

      -- Dash toward target with each hit
      local dx = b.waterfowlTargetX - b.x
      local dy = b.waterfowlTargetY - b.y
      local dist = math.sqrt(dx*dx + dy*dy)
      if dist > 10 then
        b.x = b.x + (dx/dist) * 60
        b.y = b.y + (dy/dist) * 40
      end

      -- Fire projectiles in flurry
      table.insert(b.pendingProjectiles, {
        type = "waterfowl",
        x = b.x,
        y = b.y + 50,
        targetX = playerX,
        targetY = playerY,
        damage = DAMAGE.waterfowl
      })

      b.shouldAttack = true
      b.currentAttack = "waterfowl"
    end

    if b.waterfowlHits >= b.waterfowlMaxHits then
      b.waterfowlActive = false
      b.baseX = b.x
    end
  end
end

function M.startWaterfowl(playerX, playerY)
  local b = M.boss
  b.waterfowlActive = true
  b.waterfowlHits = 0
  b.waterfowlTimer = 0.8  -- Wind-up delay (telegraph)
  b.waterfowlTargetX = playerX
  b.waterfowlTargetY = playerY
  b.waterfowlMaxHits = b.enraged and 12 or 9
end

function M.updateDeathBlight(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 6 then return end

  if b.deathBlightCharging then
    b.deathBlightTimer = b.deathBlightTimer - dt

    if b.deathBlightTimer <= 0 then
      b.deathBlightCharging = false
      -- Fire the death blight beam
      table.insert(b.pendingProjectiles, {
        type = "deathBlight",
        x = b.x,
        y = b.y + 60,
        targetX = b.deathBlightTargetX,
        targetY = b.deathBlightTargetY,
        damage = DAMAGE.deathBlight,
        width = 40,
        speed = 500
      })
      b.shouldAttack = true
      b.currentAttack = "deathBlight"
    end
  end
end

function M.startDeathBlight(playerX, playerY)
  local b = M.boss
  b.deathBlightCharging = true
  b.deathBlightTimer = b.deathBlightDuration
  b.deathBlightTargetX = playerX
  b.deathBlightTargetY = playerY
end

function M.updateAttacks(dt, playerX, playerY)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.phaseTransitioning then return end
  if b.waterfowlActive or b.gravityActive or b.deathBlightCharging then return end

  b.attackTimer = b.attackTimer - dt

  local attackSpeed = 1
  if b.phase >= 4 then attackSpeed = 1.3 end
  if b.enraged then attackSpeed = 1.8 end

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
    -- Phase 1: Blade Dance only
    M.fireBladePattern(playerX, playerY)

  elseif b.phase == 2 then
    -- Phase 2: Blade + Shadow Strike
    if roll < 60 then
      M.fireBladePattern(playerX, playerY)
    else
      M.startTeleport(playerX, playerY)
    end

  elseif b.phase == 3 then
    -- Phase 3: + Void Waves zones (passive)
    if roll < 50 then
      M.fireBladePattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 4 then
    -- Phase 4: + Gravity Well
    if roll < 30 and not b.gravityActive then
      b.gravityActive = true
      b.gravityTimer = 3
    elseif roll < 60 then
      M.fireBladePattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 5 then
    -- Phase 5: + Waterfowl Dance
    if roll < 25 then
      M.startWaterfowl(playerX, playerY)
    elseif roll < 50 then
      M.fireBladePattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  elseif b.phase == 6 then
    -- Phase 6: + Void Blight
    if roll < 20 then
      M.startDeathBlight(playerX, playerY)
    elseif roll < 40 then
      M.startWaterfowl(playerX, playerY)
    elseif roll < 70 then
      M.fireBladePattern(playerX, playerY)
    else
      M.fireSpreadPattern(playerX, playerY)
    end

  else
    -- Phase 7: Void sLAYER - everything faster, combos
    b.comboCount = b.comboCount + 1
    if b.comboCount >= 3 then
      b.comboCount = 0
      if roll < 33 then
        M.startWaterfowl(playerX, playerY)
      else
        M.startDeathBlight(playerX, playerY)
      end
    else
      if roll < 40 then
        M.fireBladePattern(playerX, playerY)
      elseif roll < 70 then
        M.fireSpreadPattern(playerX, playerY)
      else
        M.fireSweepPattern(playerX, playerY)
      end
    end
    b.attackTimer = 0.8  -- Faster in rage
  end
end

function M.fireBladePattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.blade
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- Three blade projectiles in arc
  for i = -1, 1 do
    local angle = math.atan2(playerY - b.y, playerX - b.x) + i * 0.3
    table.insert(b.pendingProjectiles, {
      type = "blade",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 350,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "blade"
end

function M.fireSpreadPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.blade
  if b.enraged then damage = math.floor(damage * b.rageMultiplier) end

  -- 5-way spread
  local count = b.enraged and 7 or 5
  for i = 1, count do
    local angle = math.pi/2 + ((i - (count+1)/2) * 0.25)
    table.insert(b.pendingProjectiles, {
      type = "spread",
      x = b.x,
      y = b.y + 50,
      angle = angle,
      speed = 300,
      damage = damage
    })
  end

  b.shouldAttack = true
  b.currentAttack = "spread"
end

function M.fireSweepPattern(playerX, playerY)
  local b = M.boss
  local damage = DAMAGE.godSlayer

  -- Sweep beam attack (10 projectiles in sequence)
  for i = 0, 9 do
    local delay = i * 0.08
    local angle = math.pi/2 - 0.6 + (i * 0.12)
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
  b.currentAttack = "sweep"
end

function M.damage(amount)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end
  if b.phaseTransitioning then return false end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

-- Get gravity pull vector for player
function M.getGravityPull()
  local b = M.boss
  if not b or not b.gravityActive then
    return 0, 0
  end
  return b.x, b.y, b.gravityPullStrength
end

-- Check if player is in rot zone
function M.checkRotZoneDamage(playerX, playerY, playerRadius)
  local b = M.boss
  if not b then return 0 end

  local totalDamage = 0
  for _, zone in ipairs(b.rotZones) do
    local dx = playerX - zone.x
    local dy = playerY - zone.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < zone.radius + playerRadius and zone.damageTimer <= 0 then
      zone.damageTimer = 0.5  -- Tick every 0.5s
      totalDamage = totalDamage + zone.damage
    end
  end

  return totalDamage
end

-- Get pending projectiles for weapons system to spawn
function M.getPendingProjectiles()
  local b = M.boss
  if not b then return {} end
  return b.pendingProjectiles
end

-- Get current attack info for HUD warnings
function M.getAttackWarning()
  local b = M.boss
  if not b then return nil end

  if b.deathBlightCharging then
    return "VOID BLIGHT", b.deathBlightTimer / b.deathBlightDuration
  elseif b.gravityActive then
    return "GRAVITY WELL", b.gravityTimer / 3
  elseif b.waterfowlActive and b.waterfowlHits == 0 then
    return "WATERFOWL DANCE", 1
  end

  return nil
end

return M
