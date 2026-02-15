local M = {}
local screen = require("starfox.screen")

M.scrollOffset = 0
M.scrollSpeed = 100
M.starSpeedMultiplier = 1.0
M.stars = {}
M.groundSections = {}

function M.reset()
  M.scrollOffset = 0
  M.starSpeedMultiplier = 1.0
  M.stars = {}

  for i = 1, 100 do
    table.insert(M.stars, {
      x = math.random(screen.WIDTH),
      y = math.random(screen.HEIGHT),
      speed = math.random(20, 80),
      size = math.random(1, 2)
    })
  end

  M.groundSections = {}
end

function M.update(dt)
  M.scrollOffset = M.scrollOffset + M.scrollSpeed * dt

  for _, star in ipairs(M.stars) do
    star.y = star.y + star.speed * M.starSpeedMultiplier * dt

    if star.y > screen.HEIGHT then
      star.y = 0
      star.x = math.random(screen.WIDTH)
    end
  end
end

function M.getScrollOffset()
  return M.scrollOffset
end

function M.getLevelTime()
  return M.scrollOffset / M.scrollSpeed
end

return M
