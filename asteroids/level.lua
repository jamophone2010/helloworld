local M = {}
local asteroid = require("asteroids.asteroid")

local function randomColor()
  return {
    0.5 + math.random() * 0.5,
    0.5 + math.random() * 0.5,
    0.5 + math.random() * 0.5
  }
end

function M.new()
  return {
    number = 1,
    ufoTimer = 30,
    cleared = false,
    color = randomColor()
  }
end

function M.getAsteroidCount(level)
  return 4 + (level.number - 1) * 2
end

-- Center exclusion zone: asteroids won't spawn aimed at the center 1/3 of the screen
local CENTER_EXCLUSION = 0.33  -- fraction of screen width/height

function M.spawnAsteroids(level, width, height, overrideCount, isOortCloud)
  local asteroids = {}
  local rawCount = overrideCount or M.getAsteroidCount(level)
  -- Reduce asteroid count everywhere except Oort Cloud
  local count = isOortCloud and rawCount or math.max(1, math.floor(rawCount * 0.5))

  -- Center exclusion bounds
  local cxMin = width * (0.5 - CENTER_EXCLUSION / 2)
  local cxMax = width * (0.5 + CENTER_EXCLUSION / 2)
  local cyMin = height * (0.5 - CENTER_EXCLUSION / 2)
  local cyMax = height * (0.5 + CENTER_EXCLUSION / 2)

  for i = 1, count do
    local side = math.random(4)
    local x, y
    if side == 1 then
      x = -50
      y = math.random(height)
    elseif side == 2 then
      x = width + 50
      y = math.random(height)
    elseif side == 3 then
      x = math.random(width)
      y = -50
    else
      x = math.random(width)
      y = height + 50
    end

    -- Pick velocity that avoids aiming into center exclusion zone
    local speed = math.random(50, 150)
    local angle
    local attempts = 0
    repeat
      angle = math.random() * math.pi * 2
      -- Project where asteroid would be after ~2 seconds
      local futX = x + math.cos(angle) * speed * 2
      local futY = y + math.sin(angle) * speed * 2
      attempts = attempts + 1
    until not (futX > cxMin and futX < cxMax and futY > cyMin and futY < cyMax) or attempts > 10

    local a = asteroid.new(x, y, "large")
    a.vx = math.cos(angle) * speed
    a.vy = math.sin(angle) * speed
    table.insert(asteroids, a)
  end

  return asteroids
end

function M.update(level, dt, asteroidCount)
  level.ufoTimer = level.ufoTimer - dt
  level.cleared = asteroidCount == 0
end

function M.shouldSpawnUFO(level)
  if level.ufoTimer <= 0 then
    level.ufoTimer = math.max(15, 30 - level.number * 2)
    return true
  end
  return false
end

function M.nextLevel(level)
  level.number = level.number + 1
  level.ufoTimer = 30
  level.cleared = false
  level.color = randomColor()
end

return M
