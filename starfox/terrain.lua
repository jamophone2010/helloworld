local M = {}

M.scrollOffset = 0
M.scrollSpeed = 100
M.stars = {}
M.groundSections = {}

function M.reset()
  M.scrollOffset = 0
  M.stars = {}

  for i = 1, 100 do
    table.insert(M.stars, {
      x = math.random(800),
      y = math.random(600),
      speed = math.random(20, 80),
      size = math.random(1, 2)
    })
  end

  M.groundSections = {}
end

function M.update(dt)
  M.scrollOffset = M.scrollOffset + M.scrollSpeed * dt

  for _, star in ipairs(M.stars) do
    star.y = star.y + star.speed * dt

    if star.y > 600 then
      star.y = 0
      star.x = math.random(800)
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
