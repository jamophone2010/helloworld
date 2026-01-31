local M = {}

M.SIZES = {
  large = {radius = 40, score = 100, splits = 2},
  medium = {radius = 25, score = 50, splits = 2},
  small = {radius = 15, score = 25, splits = 0}
}

function M.new(x, y, size)
  local speed = math.random(50, 150)
  local angle = math.random() * math.pi * 2

  return {
    x = x,
    y = y,
    vx = math.cos(angle) * speed,
    vy = math.sin(angle) * speed,
    size = size or "large",
    rotation = 0,
    rotationSpeed = (math.random() - 0.5) * 2
  }
end

function M.update(asteroid, dt)
  asteroid.x = asteroid.x + asteroid.vx * dt
  asteroid.y = asteroid.y + asteroid.vy * dt
  asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
end

function M.wrap(asteroid, width, height)
  if asteroid.x < -50 then asteroid.x = width + 50 end
  if asteroid.x > width + 50 then asteroid.x = -50 end
  if asteroid.y < -50 then asteroid.y = height + 50 end
  if asteroid.y > height + 50 then asteroid.y = -50 end
end

function M.split(asteroid)
  local sizeData = M.SIZES[asteroid.size]
  local splits = {}

  if sizeData.splits > 0 then
    local nextSize = asteroid.size == "large" and "medium" or "small"

    for i = 1, sizeData.splits do
      table.insert(splits, M.new(asteroid.x, asteroid.y, nextSize))
    end
  end

  return splits, sizeData.score
end

function M.getRadius(asteroid)
  return M.SIZES[asteroid.size].radius
end

return M
