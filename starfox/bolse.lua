local M = {}

M.station = nil

function M.reset()
  M.station = nil
end

function M.spawn(x)
  M.station = {
    x = x or 400,
    y = -200,
    targetY = 150,
    width = 250,
    height = 250,
    entering = true,
    active = true,
    time = 0,
    phase = 1,
    rotation = 0,
    rotationSpeed = 0.5,
    coreHealth = 80,
    coreMaxHealth = 80,
    coreExposed = false,
    coreExposure = 0,
    coreTimer = 0,
    turrets = {},
    score = 3000
  }

  for i = 0, 5 do
    table.insert(M.station.turrets, {
      angle = i * (math.pi * 2 / 6),
      distance = 100,
      health = 10,
      maxHealth = 10,
      destroyed = false,
      shootTimer = math.random() * 1 + 0.5 + i * 0.3,
      worldX = 0,
      worldY = 0,
      shouldShoot = false
    })
  end
end

function M.isActive()
  return M.station ~= nil and M.station.active
end

function M.getStation()
  return M.station
end

function M.update(dt, playerX, playerY)
  local s = M.station
  if not s or not s.active then return end

  s.time = s.time + dt

  if s.entering then
    s.y = s.y + 80 * dt
    if s.y >= s.targetY then
      s.y = s.targetY
      s.entering = false
    end
    return
  end

  s.rotation = s.rotation + s.rotationSpeed * dt

  for _, turret in ipairs(s.turrets) do
    if not turret.destroyed then
      local angle = turret.angle + s.rotation
      turret.worldX = s.x + math.cos(angle) * turret.distance
      turret.worldY = s.y + math.sin(angle) * turret.distance

      turret.shouldShoot = false
      if math.sin(angle) > 0.3 then
        turret.shootTimer = turret.shootTimer - dt
        if turret.shootTimer <= 0 then
          turret.shootTimer = 1.8
          turret.shouldShoot = true
        end
      end
    end
  end

  M.updatePhase(dt)
end

function M.updatePhase(dt)
  local s = M.station
  local destroyedCount = 0
  for _, t in ipairs(s.turrets) do
    if t.destroyed then destroyedCount = destroyedCount + 1 end
  end

  if s.phase == 1 then
    if destroyedCount >= 4 or s.time > 30 then
      s.phase = 2
      s.coreTimer = 0
    end
  elseif s.phase == 2 then
    s.coreTimer = s.coreTimer + dt
    s.coreExposure = math.min(1, s.coreTimer / 5)
    if s.coreExposure >= 1 then
      s.coreExposed = true
    end
    if s.coreHealth <= s.coreMaxHealth * 0.3 then
      s.phase = 3
      s.rotationSpeed = 1.2
    end
  elseif s.phase == 3 then
    s.coreExposed = true
  end
end

function M.damageTurret(turret, amount)
  if turret.destroyed then return false end
  turret.health = turret.health - amount
  if turret.health <= 0 then
    turret.destroyed = true
    return true
  end
  return false
end

function M.damageCore(amount)
  local s = M.station
  if not s or not s.coreExposed then return false end
  s.coreHealth = s.coreHealth - amount
  if s.coreHealth <= 0 then
    s.active = false
    return true
  end
  return false
end

function M.getTurrets()
  if not M.station then return {} end
  return M.station.turrets
end

return M
