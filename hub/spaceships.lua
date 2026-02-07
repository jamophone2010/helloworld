-- hub/spaceships.lua
-- Animated spaceship flyby system for station windows
-- Ships appear periodically passing by in the background, No Man's Sky style
-- Drawn within galaxy window views

local M = {}

M.activeShips = {}
M.spawnTimer = 0
M.spawnInterval = 4 -- seconds between ship appearances

-- Ship templates
local shipTemplates = {
  -- Small fighters (fast, common)
  {
    type = "fighter",
    speed = {80, 160},
    size = {12, 18},
    color = {{0.7, 0.8, 1.0}, {1.0, 0.6, 0.3}, {0.5, 1.0, 0.7}},
    trailLength = 20,
    rarity = 0.4
  },
  -- Medium freighters
  {
    type = "freighter",
    speed = {30, 60},
    size = {30, 50},
    color = {{0.6, 0.6, 0.7}, {0.5, 0.4, 0.3}, {0.4, 0.5, 0.6}},
    trailLength = 15,
    rarity = 0.3
  },
  -- Large capital ships (slow, rare, impressive)
  {
    type = "capital",
    speed = {10, 25},
    size = {80, 140},
    color = {{0.5, 0.5, 0.6}, {0.3, 0.4, 0.5}},
    trailLength = 8,
    rarity = 0.1
  },
  -- Shuttles (very common, small)
  {
    type = "shuttle",
    speed = {50, 100},
    size = {8, 14},
    color = {{0.9, 0.9, 0.8}, {0.7, 0.8, 0.9}},
    trailLength = 12,
    rarity = 0.15
  },
  -- Exotic / rare colorful ships
  {
    type = "exotic",
    speed = {100, 200},
    size = {15, 25},
    color = {{1.0, 0.2, 0.8}, {0.2, 1.0, 0.8}, {1.0, 0.8, 0.0}},
    trailLength = 30,
    rarity = 0.05
  }
}

-- Generate ship shape points based on template type
local function generateShipShape(shipType, size)
  local hw = size / 2
  local hh = size / 3

  if shipType == "fighter" then
    -- Arrow / X-wing style
    return {
      {hw, 0},
      {-hw * 0.3, -hh},
      {-hw, -hh * 0.6},
      {-hw * 0.6, 0},
      {-hw, hh * 0.6},
      {-hw * 0.3, hh},
    }
  elseif shipType == "freighter" then
    -- Blocky cargo ship
    return {
      {hw, -hh * 0.3},
      {hw, hh * 0.3},
      {hw * 0.2, hh * 0.8},
      {-hw, hh * 0.6},
      {-hw, -hh * 0.6},
      {hw * 0.2, -hh * 0.8},
    }
  elseif shipType == "capital" then
    -- Star Destroyer wedge
    return {
      {hw, 0},
      {hw * 0.6, -hh * 0.2},
      {-hw * 0.4, -hh},
      {-hw, -hh * 0.8},
      {-hw, hh * 0.8},
      {-hw * 0.4, hh},
      {hw * 0.6, hh * 0.2},
    }
  elseif shipType == "shuttle" then
    -- Small boxy shuttle
    return {
      {hw, -hh * 0.2},
      {hw, hh * 0.2},
      {-hw * 0.5, hh * 0.5},
      {-hw, hh * 0.3},
      {-hw, -hh * 0.3},
      {-hw * 0.5, -hh * 0.5},
    }
  elseif shipType == "exotic" then
    -- Sleek / curved
    return {
      {hw, 0},
      {hw * 0.3, -hh * 0.8},
      {-hw * 0.5, -hh * 0.5},
      {-hw, 0},
      {-hw * 0.5, hh * 0.5},
      {hw * 0.3, hh * 0.8},
    }
  end

  -- Default triangle
  return {{hw, 0}, {-hw, -hh}, {-hw, hh}}
end

-- Spawn a new ship
local function spawnShip()
  -- Pick template based on rarity weights
  local roll = math.random()
  local cumulative = 0
  local template = shipTemplates[1]
  for _, t in ipairs(shipTemplates) do
    cumulative = cumulative + t.rarity
    if roll <= cumulative then
      template = t
      break
    end
  end

  local colors = template.color
  local c = colors[math.random(1, #colors)]
  local size = template.size[1] + math.random() * (template.size[2] - template.size[1])
  local speed = template.speed[1] + math.random() * (template.speed[2] - template.speed[1])

  -- Direction: mostly left-to-right but sometimes right-to-left
  local direction = math.random() > 0.3 and 1 or -1
  local startX, targetX
  if direction == 1 then
    startX = -size * 2
    targetX = 1700
  else
    startX = 1700
    targetX = -size * 2
  end

  -- Vertical position (anywhere in the window, weighted toward middle)
  local yPos = 100 + math.random() * 600

  -- Slight angle for variety
  local angle = (math.random() - 0.5) * 0.2

  local ship = {
    template = template,
    x = startX,
    y = yPos,
    targetX = targetX,
    speed = speed * direction,
    size = size,
    color = c,
    angle = angle,
    trailPositions = {},
    trailLength = template.trailLength,
    shape = generateShipShape(template.type, size),
    engineGlow = 0,
    active = true,
    depth = 0.5 + math.random() * 0.5 -- parallax depth
  }

  return ship
end

function M.update(dt)
  M.spawnTimer = M.spawnTimer + dt

  -- Spawn new ships
  if M.spawnTimer >= M.spawnInterval then
    M.spawnTimer = 0
    M.spawnInterval = 3 + math.random() * 5 -- randomize next spawn

    -- Can have up to 5 active ships
    if #M.activeShips < 5 then
      table.insert(M.activeShips, spawnShip())
    end
  end

  -- Update active ships
  for i = #M.activeShips, 1, -1 do
    local ship = M.activeShips[i]

    -- Move
    ship.x = ship.x + ship.speed * dt * ship.depth
    ship.y = ship.y + math.sin(ship.angle) * ship.speed * dt * 0.3

    -- Engine glow pulse
    ship.engineGlow = 0.5 + 0.5 * math.sin(love.timer.getTime() * 8 + i)

    -- Record trail position
    table.insert(ship.trailPositions, 1, {x = ship.x, y = ship.y})
    if #ship.trailPositions > ship.trailLength then
      table.remove(ship.trailPositions)
    end

    -- Remove if offscreen
    if (ship.speed > 0 and ship.x > 1700) or (ship.speed < 0 and ship.x < -200) then
      table.remove(M.activeShips, i)
    end
  end
end

-- Draw all active ships (call within a window's scissor region)
function M.draw(time)
  for _, ship in ipairs(M.activeShips) do
    local r, g, b = ship.color[1], ship.color[2], ship.color[3]
    local depth = ship.depth

    -- Engine trail
    for j = 1, #ship.trailPositions do
      local tp = ship.trailPositions[j]
      local trailAlpha = (1 - j / #ship.trailPositions) * 0.4 * depth
      local trailSize = ship.size * 0.15 * (1 - j / #ship.trailPositions)

      -- Engine exhaust glow
      love.graphics.setColor(r * 0.5, g * 0.5, b, trailAlpha)
      love.graphics.circle("fill", tp.x, tp.y, trailSize)
    end

    -- Ship body
    love.graphics.push()
    love.graphics.translate(ship.x, ship.y)
    love.graphics.rotate(ship.angle)
    love.graphics.scale(depth, depth)

    -- Hull
    local vertices = {}
    for _, pt in ipairs(ship.shape) do
      table.insert(vertices, pt[1])
      table.insert(vertices, pt[2])
    end

    if #vertices >= 6 then
      -- Dark hull
      love.graphics.setColor(r * 0.3, g * 0.3, b * 0.3, 0.8 * depth)
      love.graphics.polygon("fill", vertices)

      -- Hull outline
      love.graphics.setColor(r * 0.6, g * 0.6, b * 0.6, 0.6 * depth)
      love.graphics.setLineWidth(1)
      love.graphics.polygon("line", vertices)
    end

    -- Engine glow (at the back)
    local glowAlpha = ship.engineGlow * 0.6 * depth
    love.graphics.setColor(0.3, 0.5, 1.0, glowAlpha)
    love.graphics.circle("fill", -ship.size * 0.4, 0, ship.size * 0.12)
    love.graphics.setColor(0.5, 0.7, 1.0, glowAlpha * 0.5)
    love.graphics.circle("fill", -ship.size * 0.4, 0, ship.size * 0.25)

    -- Running lights on hull
    if ship.template.type == "capital" or ship.template.type == "freighter" then
      local blink = math.sin(time * 4 + ship.x * 0.01) > 0 and 0.8 or 0.1
      love.graphics.setColor(1.0, 0.0, 0.0, blink * depth)
      love.graphics.circle("fill", ship.size * 0.3, -ship.size * 0.15, 2)
      love.graphics.setColor(0.0, 1.0, 0.0, blink * depth)
      love.graphics.circle("fill", ship.size * 0.3, ship.size * 0.15, 2)
    end

    love.graphics.pop()
  end
end

-- Reset all ships (e.g., when changing floors)
function M.reset()
  M.activeShips = {}
  M.spawnTimer = 0
end

return M
