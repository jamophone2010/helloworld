local M = {}

M.rival = nil
M.lasers = nil

local PATTERNS = {
  dive_left = {
    {x = 100, y = -50},
    {x = 150, y = 150},
    {x = 300, y = 300},
    {x = 500, y = 350},
    {x = 650, y = 200},
    {x = 700, y = -50}
  },
  dive_right = {
    {x = 700, y = -50},
    {x = 650, y = 150},
    {x = 500, y = 300},
    {x = 300, y = 350},
    {x = 150, y = 200},
    {x = 100, y = -50}
  },
  figure8 = {
    {x = 200, y = 100},
    {x = 350, y = 180},
    {x = 500, y = 100},
    {x = 600, y = 180},
    {x = 500, y = 280},
    {x = 350, y = 350},
    {x = 200, y = 280},
    {x = 100, y = 180},
    {x = 200, y = 100}
  },
  strafe_left = {
    {x = 850, y = 200},
    {x = -50, y = 250}
  },
  strafe_right = {
    {x = -50, y = 200},
    {x = 850, y = 250}
  },
  swoop = {
    {x = 400, y = -50},
    {x = 400, y = 200},
    {x = 200, y = 400},
    {x = 400, y = 450},
    {x = 600, y = 400},
    {x = 400, y = 200},
    {x = 400, y = -50}
  }
}

local PATTERN_NAMES = {"dive_left", "dive_right", "figure8", "strafe_left", "strafe_right", "swoop"}

function M.reset()
  M.rival = nil
  M.lasers = nil
end

function M.spawn(x, y, overrideHP, variant)
  local hp = overrideHP or 20
  M.rival = {
    x = x or 400,
    y = y or -50,
    width = 35,
    height = 35,
    health = hp,
    maxHealth = hp,
    score = 1000,
    active = true,
    destroyed = false,
    pattern = nil,
    pathPoints = {},
    pathT = 0,
    patternIndex = 1,
    patternSpeed = 1.2,
    reflecting = false,
    reflectTimer = 0,
    reflectCooldown = 0,
    reflectDuration = 0.6,
    reflectChance = 0.7,
    shootTimer = 2,
    burstCount = 0,
    burstDelay = 0,
    respawnTimer = 0,
    retreating = false,
    variant = variant or "standard",
    teleportTimer = 0,
    teleportCooldown = 3,
    teleportDelay = 1.5
  }
  M.lasers = M.lasers or {}
  if variant == "teleport" then
    M.rival.teleportTimer = 2
    M.rival.x = 400
    M.rival.y = 200
  else
    M.startPattern("dive_left")
  end
end

function M.isActive()
  return M.rival ~= nil and M.rival.active and not M.rival.destroyed
end

function M.getRival()
  return M.rival
end

function M.startPattern(patternName)
  local r = M.rival
  if not r then return end
  r.pattern = patternName
  r.pathPoints = PATTERNS[patternName]
  r.pathT = 0
  r.patternIndex = 1
end

function M.pickNextPattern()
  local idx = math.random(#PATTERN_NAMES)
  M.startPattern(PATTERN_NAMES[idx])
end

function M.updateMovement(dt)
  local r = M.rival
  if not r or #r.pathPoints == 0 then return end

  local current = r.pathPoints[r.patternIndex]
  local next = r.pathPoints[r.patternIndex + 1]

  if not next then
    M.pickNextPattern()
    return
  end

  r.pathT = r.pathT + dt * r.patternSpeed
  if r.pathT >= 1 then
    r.pathT = 0
    r.patternIndex = r.patternIndex + 1
  else
    r.x = current.x + (next.x - current.x) * r.pathT
    r.y = current.y + (next.y - current.y) * r.pathT
  end
end

function M.detectIncomingThreat(lasers)
  local r = M.rival
  if not r or not lasers then return false end

  for _, laser in ipairs(lasers) do
    if laser.owner == "player" and not laser.mirrored then
      local dist = math.sqrt((laser.x - r.x)^2 + (laser.y - r.y)^2)
      if dist < 80 and laser.vy and laser.vy < 0 then
        return true
      end
    end
  end
  return false
end

function M.mirrorIncoming(lasers)
  local r = M.rival
  if not r or not r.reflecting or not lasers then return end

  for _, laser in ipairs(lasers) do
    if laser.owner == "player" and not laser.mirrored then
      local dist = math.sqrt((laser.x - r.x)^2 + (laser.y - r.y)^2)
      if dist < 50 then
        laser.vy = -laser.vy
        if laser.vx then laser.vx = -laser.vx end
        laser.owner = "enemy"
        laser.mirrored = true
      end
    end
  end
end

function M.update(dt, playerX, playerY, playerLasers)
  local r = M.rival
  if not r then return end

  if r.destroyed and not r.retreating then
    r.respawnTimer = r.respawnTimer - dt
    if r.respawnTimer <= 0 then
      M.spawn(400, -50)
    end
    return
  end

  if r.retreating then
    r.y = r.y - 300 * dt
    if r.y < -100 then
      r.active = false
    end
    return
  end

  if not r.active then return end

  -- Handle teleporting variant
  if r.variant == "teleport" then
    r.teleportTimer = r.teleportTimer - dt
    if r.teleportTimer <= 0 then
      -- Teleport to random position
      r.x = math.random(100, 700)
      r.y = math.random(100, 400)
      r.teleportTimer = r.teleportCooldown
    end
  end

  r.reflectCooldown = math.max(0, r.reflectCooldown - dt)

  if r.reflecting then
    r.reflectTimer = r.reflectTimer - dt
    M.mirrorIncoming(playerLasers)
    if r.reflectTimer <= 0 then
      r.reflecting = false
    end
  else
    if r.reflectCooldown <= 0 and M.detectIncomingThreat(playerLasers) then
      if math.random() < r.reflectChance then
        r.reflecting = true
        r.reflectTimer = r.reflectDuration
        r.reflectCooldown = 3
      end
    end
  end

  -- Skip pattern movement for teleporting variant
  if r.variant ~= "teleport" then
    M.updateMovement(dt)
  end

  if r.burstCount > 0 then
    r.burstDelay = r.burstDelay - dt
    if r.burstDelay <= 0 then
      M.fireAtPlayer(playerX, playerY)
      r.burstCount = r.burstCount - 1
      r.burstDelay = 0.15
    end
  else
    r.shootTimer = r.shootTimer - dt
    if r.shootTimer <= 0 then
      r.burstCount = 3
      r.burstDelay = 0
      r.shootTimer = 2.5
    end
  end
end

function M.fireAtPlayer(playerX, playerY)
  local r = M.rival
  if not r or not r.active then return end

  local dx = playerX - r.x
  local dy = playerY - r.y
  local dist = math.sqrt(dx*dx + dy*dy)
  if dist == 0 then dist = 1 end

  local laser = {
    x = r.x,
    y = r.y + 15,
    vx = (dx / dist) * 350,
    vy = (dy / dist) * 350,
    width = 6,
    height = 6,
    damage = 5,
    owner = "enemy"
  }

  -- Mark teleporting rival's bullets as reflectable
  if r.variant == "teleport" then
    laser.reflectable = true
  end

  table.insert(M.lasers, laser)
end

function M.updateLasers(dt)
  if not M.lasers then return end

  for i = #M.lasers, 1, -1 do
    local laser = M.lasers[i]
    laser.x = laser.x + laser.vx * dt
    laser.y = laser.y + laser.vy * dt

    if laser.x < -50 or laser.x > 850 or laser.y < -50 or laser.y > 650 then
      table.remove(M.lasers, i)
    end
  end
end

function M.getLasers()
  return M.lasers or {}
end

function M.damage(amount)
  local r = M.rival
  if not r or r.reflecting then return false end

  r.health = r.health - amount
  if r.health <= 0 then
    r.destroyed = true
    r.active = false
    r.respawnTimer = 8
    return true
  end
  return false
end

function M.retreat()
  local r = M.rival
  if not r then return end
  r.retreating = true
  r.reflecting = false
end

return M
