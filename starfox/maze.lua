local M = {}

M.walls = {}
M.active = false

local SCROLL_SPEED = 100
local WALL_HEIGHT = 60
local GAP_WIDTH = 150
local SCREEN_WIDTH = 800

local PATTERNS = {
  left = {gapCenter = 175},
  center = {gapCenter = 400},
  right = {gapCenter = 625},
  zigzag_left = {gapCenter = 200},
  zigzag_right = {gapCenter = 600},
  narrow = {gapCenter = 400, gapWidth = 100}
}

local zigzagState = "left"

function M.reset()
  M.walls = {}
  M.active = false
  zigzagState = "left"
end

function M.activate()
  M.active = true
end

function M.deactivate()
  M.active = false
end

function M.isActive()
  return M.active
end

function M.spawnWallRow(pattern)
  local p = PATTERNS[pattern]
  if not p then
    if pattern == "zigzag" then
      p = PATTERNS["zigzag_" .. zigzagState]
      zigzagState = zigzagState == "left" and "right" or "left"
    else
      p = PATTERNS.center
    end
  end

  local gapWidth = p.gapWidth or GAP_WIDTH
  local gapCenter = p.gapCenter
  local gapLeft = gapCenter - gapWidth / 2
  local gapRight = gapCenter + gapWidth / 2

  table.insert(M.walls, {
    y = -WALL_HEIGHT,
    height = WALL_HEIGHT,
    gapLeft = gapLeft,
    gapRight = gapRight
  })
end

function M.update(dt)
  if not M.active then return end

  for i = #M.walls, 1, -1 do
    local wall = M.walls[i]
    wall.y = wall.y + SCROLL_SPEED * dt

    if wall.y > 650 then
      table.remove(M.walls, i)
    end
  end
end

function M.getWalls()
  return M.walls
end

function M.checkCollision(x, y, radius)
  if not M.active then return false end

  for _, wall in ipairs(M.walls) do
    if y + radius > wall.y and y - radius < wall.y + wall.height then
      if x - radius < wall.gapLeft or x + radius > wall.gapRight then
        return true
      end
    end
  end
  return false
end

function M.checkLaserCollision(laser)
  if not M.active then return false end

  for _, wall in ipairs(M.walls) do
    if laser.y > wall.y and laser.y < wall.y + wall.height then
      if laser.x < wall.gapLeft or laser.x > wall.gapRight then
        return true
      end
    end
  end
  return false
end

return M
