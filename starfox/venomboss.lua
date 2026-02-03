local M = {}

M.boss = nil

local PHASE_TELEPORT_COOLDOWN = {4, 3, 2}
local PHASE_LASER_DURATION = {0, 2.5, 3}
local PHASE_LASER_COOLDOWN = {999, 6, 4}
local PHASE_LASER_SWEEP_SPEED = {0, 1.5, 2.5}

function M.reset()
  M.boss = nil
end

function M.spawn()
  M.boss = {
    x = 400,
    y = -120,
    width = 140,
    height = 110,
    health = 150,
    maxHealth = 150,
    score = 8000,
    phase = 1,
    active = true,
    entering = true,
    targetY = 120,

    teleporting = false,
    teleportTimer = 4,
    teleportTargetX = 400,
    fadeAlpha = 1,
    fadeIn = false,

    laserActive = false,
    laserTimer = 0,
    laserCooldownTimer = 6,
    laserAngle = math.pi / 2,
    laserReflected = false,
    laserReflectDamageTimer = 0,

    attackTimer = 2,
    shouldAttack = false
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

  if b.entering then
    b.y = b.y + 100 * dt
    if b.y >= b.targetY then
      b.y = b.targetY
      b.entering = false
    end
    return
  end

  M.updatePhase()
  M.updateTeleport(dt)
  M.updateLaser(dt, playerX, playerY)
  M.updateAttack(dt)
end

function M.updatePhase()
  local b = M.boss
  if b.health <= 50 and b.phase < 3 then
    b.phase = 3
  elseif b.health <= 100 and b.phase < 2 then
    b.phase = 2
  end
end

function M.updateTeleport(dt)
  local b = M.boss
  if b.laserActive then return end

  if b.teleporting then
    b.fadeAlpha = b.fadeAlpha - dt * 3
    if b.fadeAlpha <= 0 then
      b.fadeAlpha = 0
      b.x = b.teleportTargetX
      b.teleporting = false
      b.fadeIn = true
    end
  elseif b.fadeIn then
    b.fadeAlpha = b.fadeAlpha + dt * 3
    if b.fadeAlpha >= 1 then
      b.fadeAlpha = 1
      b.fadeIn = false
    end
  else
    b.teleportTimer = b.teleportTimer - dt
    if b.teleportTimer <= 0 then
      M.startTeleport()
    end
  end
end

function M.startTeleport()
  local b = M.boss
  b.teleporting = true
  b.teleportTargetX = math.random(100, 700)
  b.teleportTimer = PHASE_TELEPORT_COOLDOWN[b.phase]
end

function M.updateLaser(dt, playerX, playerY)
  local b = M.boss
  if b.phase < 2 then return end
  if b.teleporting or b.fadeIn then return end

  if b.laserActive then
    b.laserTimer = b.laserTimer - dt

    if b.laserReflected then
      b.laserReflectDamageTimer = b.laserReflectDamageTimer - dt
      if b.laserReflectDamageTimer <= 0 then
        b.laserReflectDamageTimer = 0.1
        b.health = b.health - 5
        if b.health <= 0 then
          b.health = 0
          b.active = false
        end
      end
    else
      local targetAngle = math.atan2(playerY - (b.y + 50), playerX - b.x)
      local diff = targetAngle - b.laserAngle
      while diff > math.pi do diff = diff - 2 * math.pi end
      while diff < -math.pi do diff = diff + 2 * math.pi end
      local sweepSpeed = PHASE_LASER_SWEEP_SPEED[b.phase]
      local step = sweepSpeed * dt
      if math.abs(diff) < step then
        b.laserAngle = targetAngle
      else
        b.laserAngle = b.laserAngle + step * (diff > 0 and 1 or -1)
      end
    end

    if b.laserTimer <= 0 then
      b.laserActive = false
      b.laserReflected = false
      b.laserCooldownTimer = PHASE_LASER_COOLDOWN[b.phase]
    end
  else
    b.laserCooldownTimer = b.laserCooldownTimer - dt
    if b.laserCooldownTimer <= 0 then
      M.startLaser()
    end
  end
end

function M.startLaser()
  local b = M.boss
  b.laserActive = true
  b.laserTimer = PHASE_LASER_DURATION[b.phase]
  b.laserAngle = math.pi / 2
  b.laserReflected = false
end

function M.reflectLaser()
  local b = M.boss
  if not b or not b.laserActive or b.laserReflected then return end
  b.laserReflected = true
  b.laserAngle = b.laserAngle + math.pi
  b.laserReflectDamageTimer = 0
end

function M.updateAttack(dt)
  local b = M.boss
  if b.teleporting or b.fadeIn or b.laserActive then return end

  b.attackTimer = b.attackTimer - dt
  if b.attackTimer <= 0 then
    b.shouldAttack = true
    b.attackTimer = b.phase == 3 and 1.2 or 1.8
  end
end

function M.damage(amount)
  local b = M.boss
  if not b or not b.active then return false end
  if b.teleporting or b.fadeAlpha < 1 then return false end

  b.health = b.health - amount
  if b.health <= 0 then
    b.health = 0
    b.active = false
    return true
  end
  return false
end

function M.getLaserEndpoint()
  local b = M.boss
  if not b then return 0, 0 end
  local length = 800
  local startX, startY = b.x, b.y + 50
  return startX + math.cos(b.laserAngle) * length,
         startY + math.sin(b.laserAngle) * length
end

function M.getLaserLine()
  local b = M.boss
  if not b then return 0, 0, 0, 0 end
  local startX, startY = b.x, b.y + 50
  local endX, endY = M.getLaserEndpoint()
  return startX, startY, endX, endY
end

function M.checkLaserHitPlayer(playerX, playerY, playerRadius)
  local b = M.boss
  if not b or not b.laserActive or b.laserReflected then return false end

  local x1, y1, x2, y2 = M.getLaserLine()
  local dx = x2 - x1
  local dy = y2 - y1
  local fx = x1 - playerX
  local fy = y1 - playerY

  local a = dx * dx + dy * dy
  local b_coef = 2 * (fx * dx + fy * dy)
  local c = fx * fx + fy * fy - playerRadius * playerRadius

  local disc = b_coef * b_coef - 4 * a * c
  if disc < 0 then return false end

  disc = math.sqrt(disc)
  local t1 = (-b_coef - disc) / (2 * a)
  local t2 = (-b_coef + disc) / (2 * a)

  return (t1 >= 0 and t1 <= 1) or (t2 >= 0 and t2 <= 1)
end

function M.pointToLaserDistance(px, py)
  local b = M.boss
  if not b or not b.laserActive then return 9999 end

  local x1, y1, x2, y2 = M.getLaserLine()
  local dx = x2 - x1
  local dy = y2 - y1
  local len2 = dx * dx + dy * dy
  if len2 == 0 then return math.sqrt((px - x1)^2 + (py - y1)^2) end

  local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / len2))
  local nearX = x1 + t * dx
  local nearY = y1 + t * dy
  return math.sqrt((px - nearX)^2 + (py - nearY)^2)
end

return M
