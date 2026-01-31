local M = {}
local asteroid = require("asteroids.asteroid")

function M.new()
  return {
    number = 1,
    ufoTimer = 30,
    cleared = false
  }
end

function M.getAsteroidCount(level)
  return 4 + (level.number - 1) * 2
end

function M.spawnAsteroids(level, width, height)
  local asteroids = {}
  local count = M.getAsteroidCount(level)

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

    table.insert(asteroids, asteroid.new(x, y, "large"))
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
end

return M
