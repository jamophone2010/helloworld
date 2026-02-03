local M = {}

local PLANETS = {
  -- Row 1 (bottom) - Start
  {id = 1, name = "Corneria", x = 400, y = 520, connections = {2, 3}},

  -- Row 2
  {id = 2, name = "Meteo", x = 250, y = 440, connections = {1, 4, 5}},
  {id = 3, name = "Sector Y", x = 550, y = 440, connections = {1, 5, 6}},

  -- Row 3
  {id = 4, name = "Fortuna", x = 120, y = 360, connections = {2, 7}},
  {id = 5, name = "Katina", x = 400, y = 360, connections = {2, 3, 8}},
  {id = 6, name = "Aquas", x = 680, y = 360, connections = {3, 9}},

  -- Row 4
  {id = 7, name = "Solar", x = 80, y = 280, connections = {4, 10, 11}},
  {id = 8, name = "Sector X", x = 400, y = 280, connections = {5, 11, 12}},
  {id = 9, name = "Zoness", x = 720, y = 280, connections = {6, 12, 13}},

  -- Row 5
  {id = 10, name = "Macbeth", x = 60, y = 200, connections = {7, 14}},
  {id = 11, name = "Titania", x = 250, y = 200, connections = {7, 8, 15}},
  {id = 12, name = "Sector Z", x = 550, y = 200, connections = {8, 9, 16}},
  {id = 13, name = "Bolse", x = 740, y = 200, connections = {9, 17}},

  -- Row 6
  {id = 14, name = "Area 6", x = 150, y = 120, connections = {10, 18}},
  {id = 15, name = "Fichina", x = 300, y = 120, connections = {11, 18}},
  {id = 16, name = "Outer", x = 500, y = 120, connections = {12, 18}},
  {id = 17, name = "Venom II", x = 650, y = 120, connections = {13, 18}},

  -- Row 7 (top) - Final
  {id = 18, name = "Venom", x = 400, y = 50, connections = {14, 15, 16, 17}}
}

local selectedIndex = 1
local stars = {}

function M.load()
  selectedIndex = 1
  stars = {}
  for i = 1, 120 do
    table.insert(stars, {
      x = math.random(800),
      y = math.random(600),
      size = math.random(1, 2),
      brightness = math.random() * 0.5 + 0.3
    })
  end
end

function M.getSelected()
  return PLANETS[selectedIndex]
end

function M.getSelectedId()
  return PLANETS[selectedIndex].id
end

function M.getPlanets()
  return PLANETS
end

function M.getStars()
  return stars
end

function M.navigate(direction)
  local current = PLANETS[selectedIndex]
  local best = nil
  local bestScore = -math.huge

  for _, connId in ipairs(current.connections) do
    local conn = PLANETS[connId]
    local dx = conn.x - current.x
    local dy = conn.y - current.y
    local score = 0

    if direction == "up" and dy < 0 then
      score = -dy
    elseif direction == "down" and dy > 0 then
      score = dy
    elseif direction == "left" and dx < 0 then
      score = -dx
    elseif direction == "right" and dx > 0 then
      score = dx
    end

    if score > bestScore then
      bestScore = score
      best = connId
    end
  end

  if best then
    selectedIndex = best
  end
end

return M
