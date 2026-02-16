local M = {}

local stars = {}
local pleiadesStars = {}
local nebulaClouds = {}
local ships = {}
local rotation = 0
local centerX, centerY = 683, 384
local numStars = 2000
local numArms = 4
local armSpread = 0.4
local coreRadius = 56  -- 1.5 * 0.75 = original * ~1.125
local time = 0
local shipSpawnTimer = 0
local shipSpawnInterval = 22
local TRAIL_LEN = 50

-- Star Fox ship designs — proper Arwing-style multi-part shapes
-- Each ship has body, leftWing, rightWing, leftFin, rightFin, noseCone parts
-- Coordinates are in local ship space (nose = -Y, tail = +Y)
local shipDesigns = {
  {
    name = "starwing",
    color = {0.3, 0.5, 1.0},
    accentColor = {0.5, 0.7, 1.0},
  },
  {
    name = "lancer",
    color = {1.0, 0.4, 0.1},
    accentColor = {1.0, 0.7, 0.3},
  },
  {
    name = "paladin",
    color = {0.2, 0.8, 0.3},
    accentColor = {0.5, 1.0, 0.6},
  },
  {
    name = "mistral",
    color = {0.6, 0.2, 1.0},
    accentColor = {0.8, 0.5, 1.0},
  },
  {
    name = "phantom",
    color = {0.3, 0.3, 0.4},
    accentColor = {0.6, 0.6, 0.8},
  },
  {
    name = "prototype",
    color = {0.0, 0.8, 1.0},
    accentColor = {0.4, 0.9, 1.0},
  },
}

-- Shared Arwing polygon parts (normalised, will be scaled by ship size)
local arwingParts = {
  body      = {0, -22, -10, 8, -3, 10, 3, 10, 10, 8},
  leftWing  = {-10, 0, -26, 6, -24, 10, -10, 8},
  rightWing = {10, 0, 26, 6, 24, 10, 10, 8},
  leftFin   = {-24, 4, -28, -2, -26, 6},
  rightFin  = {24, 4, 28, -2, 26, 6},
  noseCone  = {0, -22, -4, -16, 4, -16},
}

-- Get the current screen position of a Pleiades star (accounts for rotation)
local function getPleiadesScreenPos(idx)
  local ps = pleiadesStars[idx]
  if not ps then return centerX, centerY end
  local cosR = math.cos(rotation)
  local sinR = math.sin(rotation)
  return centerX + ps.x * cosR - ps.y * sinR,
         centerY + ps.x * sinR + ps.y * cosR
end

local function spawnShip()
  -- Must have at least one Pleiades star as destination
  if #pleiadesStars == 0 then return end

  local edge = math.random(4)
  local x, y
  if edge == 1 then
    x = math.random(1366); y = -20
  elseif edge == 2 then
    x = math.random(1366); y = 788
  elseif edge == 3 then
    x = -20; y = math.random(768)
  else
    x = 1386; y = math.random(768)
  end

  -- Pick a random Pleiades star as target (will track it each frame)
  local targetStarIdx = math.random(#pleiadesStars)
  local destX, destY = getPleiadesScreenPos(targetStarIdx)
  local dx = destX - x
  local dy = destY - y
  local dist = math.sqrt(dx * dx + dy * dy)
  local speed = 50 + math.random() * 40

  local design = shipDesigns[math.random(#shipDesigns)]
  local angle = math.atan2(dy, dx) + math.pi / 2

  table.insert(ships, {
    x = x, y = y,
    speed = speed,
    targetStarIdx = targetStarIdx,
    angle = angle,
    design = design,
    r = design.color[1],
    g = design.color[2],
    b = design.color[3],
    ar = design.accentColor[1],
    ag = design.accentColor[2],
    ab = design.accentColor[3],
    trail = {},
    baseSize = 9 + math.random() * 4,
    arrived = false,
    fadeAlpha = 1,
  })
end

function M.load()
  stars = {}
  pleiadesStars = {}
  nebulaClouds = {}
  ships = {}
  shipSpawnTimer = shipSpawnInterval * 0.35

  -- Spiral arm stars (0.75x of previous: 525*0.75=394)
  for i = 1, numStars do
    local armIndex = math.random(0, numArms - 1)
    local armAngle = (armIndex / numArms) * math.pi * 2
    local dist = math.random() ^ 0.5 * 394 + 22
    local spiralTwist = dist * 0.008
    local angle = armAngle + spiralTwist + (math.random() - 0.5) * armSpread

    local x = math.cos(angle) * dist
    local y = math.sin(angle) * dist * 0.4

    local brightness = math.random() * 0.6 + 0.2
    local size = math.random() * 1.5 + 0.5

    local colorType = math.random()
    local r, g, b
    if colorType < 0.6 then
      r, g, b = 0.8 + math.random() * 0.2, 0.85 + math.random() * 0.15, 1
    elseif colorType < 0.85 then
      r, g, b = 1, 0.9 + math.random() * 0.1, 0.6 + math.random() * 0.2
    else
      r, g, b = 1, 0.5 + math.random() * 0.3, 0.3 + math.random() * 0.2
    end

    local dramatic = math.random() < 0.08
    table.insert(stars, {
      x = x, y = y,
      size = size,
      brightness = brightness,
      twinkleSpeed = dramatic and (math.random() * 4 + 3) or (math.random() * 2 + 1),
      twinkleOffset = math.random() * math.pi * 2,
      twinkleAmp = dramatic and 0.6 or 0.28,
      r = r, g = g, b = b,
      hasDiffraction = math.random() < 0.02
    })
  end

  -- Core stars (0.75x)
  for i = 1, 400 do
    local angle = math.random() * math.pi * 2
    local dist = math.random() ^ 2 * coreRadius
    table.insert(stars, {
      x = math.cos(angle) * dist,
      y = math.sin(angle) * dist * 0.4,
      size = math.random() * 2 + 1,
      brightness = math.random() * 0.4 + 0.6,
      twinkleSpeed = math.random() * 3 + 2,
      twinkleOffset = math.random() * math.pi * 2,
      twinkleAmp = 0.18,
      r = 1, g = 0.95, b = 0.8,
      core = true
    })
  end

  -- Background stars (more visible twinkle)
  for i = 1, 400 do
    local dramatic = math.random() < 0.18
    table.insert(stars, {
      x = (math.random() - 0.5) * 1600,
      y = (math.random() - 0.5) * 900,
      size = math.random() * 0.9 + 0.3,
      brightness = math.random() * 0.35 + 0.12,
      twinkleSpeed = dramatic and (math.random() * 6 + 4) or (math.random() * 2.5 + 1.0),
      twinkleOffset = math.random() * math.pi * 2,
      twinkleAmp = dramatic and 0.85 or 0.45,
      r = 1, g = 1, b = 1,
      background = true
    })
  end

  -- Pleiades stars (6, 0.75x scaled): also serve as ship destinations
  for i = 1, 6 do
    local armIndex = math.random(0, numArms - 1)
    local armAngle = (armIndex / numArms) * math.pi * 2
    local dist = math.random() * 315 + 68
    local spiralTwist = dist * 0.008
    local angle = armAngle + spiralTwist + (math.random() - 0.5) * 0.35

    local gx = math.cos(angle) * dist
    local gy = math.sin(angle) * dist * 0.4

    table.insert(pleiadesStars, {
      x = gx, y = gy,
      size = 3 + math.random() * 5,
      haloSize = 25 + math.random() * 40,
      brightness = 0.7 + math.random() * 0.3,
      pulseSpeed = 0.3 + math.random() * 0.8,
      pulseOffset = math.random() * math.pi * 2,
      colorR = 0.6 + math.random() * 0.2,
      colorG = 0.7 + math.random() * 0.2,
      colorB = 1.0
    })
  end

  -- Nebula clouds (0.75x)
  local cloudPalette = {
    {0.4, 0.2, 0.6, 0.06},
    {0.2, 0.3, 0.7, 0.05},
    {0.6, 0.2, 0.4, 0.04},
    {0.3, 0.5, 0.7, 0.05},
    {0.5, 0.3, 0.6, 0.04},
  }

  for i = 1, 12 do
    local armIndex = math.random(0, numArms - 1)
    local armAngle = (armIndex / numArms) * math.pi * 2
    local dist = math.random() * 338 + 56
    local spiralTwist = dist * 0.008
    local angle = armAngle + spiralTwist + (math.random() - 0.5) * 0.5

    local color = cloudPalette[math.random(#cloudPalette)]
    table.insert(nebulaClouds, {
      x = math.cos(angle) * dist,
      y = math.sin(angle) * dist * 0.4,
      radius = 68 + math.random() * 113,
      color = color,
      driftX = (math.random() - 0.5) * 2,
      driftY = (math.random() - 0.5) * 2,
      pulseSpeed = math.random() * 0.3 + 0.1,
      pulseOffset = math.random() * math.pi * 2,
      layers = math.random(2, 3)
    })
  end
end

function M.update(dt)
  rotation = rotation + dt * 0.008
  time = time + dt

  for _, cloud in ipairs(nebulaClouds) do
    cloud.x = cloud.x + cloud.driftX * dt * 0.1
    cloud.y = cloud.y + cloud.driftY * dt * 0.1
  end

  shipSpawnTimer = shipSpawnTimer + dt
  if shipSpawnTimer >= shipSpawnInterval then
    shipSpawnTimer = 0
    shipSpawnInterval = 18 + math.random() * 22
    spawnShip()
  end

  for i = #ships, 1, -1 do
    local ship = ships[i]
    table.insert(ship.trail, 1, {x = ship.x, y = ship.y})
    if #ship.trail > TRAIL_LEN then
      table.remove(ship.trail)
    end

    if ship.arrived then
      -- Fade out at destination
      ship.fadeAlpha = ship.fadeAlpha - dt * 2.5
      if ship.fadeAlpha <= 0 then
        table.remove(ships, i)
      end
    else
      -- Steer toward the Pleiades star (re-evaluated each frame for rotation)
      local destX, destY = getPleiadesScreenPos(ship.targetStarIdx)
      local dx = destX - ship.x
      local dy = destY - ship.y
      local dist = math.sqrt(dx * dx + dy * dy)

      if dist < 8 then
        -- Arrived at the star — begin fade
        ship.arrived = true
        ship.x = destX
        ship.y = destY
      else
        -- Smoothly steer toward target
        local dirX = dx / dist
        local dirY = dy / dist
        ship.x = ship.x + dirX * ship.speed * dt
        ship.y = ship.y + dirY * ship.speed * dt
        ship.angle = math.atan2(dirY, dirX) + math.pi / 2
      end
    end
  end
end

-- Transform and draw a polygon part at ship position/angle/scale
local function drawPart(ship, pts, scale, r, g, b, alpha, mode)
  local cosA = math.cos(ship.angle)
  local sinA = math.sin(ship.angle)
  local verts = {}
  for i = 1, #pts, 2 do
    local lx, ly = pts[i] * scale, pts[i + 1] * scale
    table.insert(verts, ship.x + lx * cosA - ly * sinA)
    table.insert(verts, ship.y + lx * sinA + ly * cosA)
  end
  if #verts >= 6 then
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.polygon(mode or "fill", verts)
  end
end

local function drawShipShape(ship, size, alpha)
  local c  = ship.design.color
  local ac = ship.design.accentColor
  -- Scale factor: arwing base parts are ~28px nose-to-tail, normalise to ship size
  local s = size / 22

  -- Filled hull panels (dark ship colour)
  drawPart(ship, arwingParts.body, s, c[1]*0.4, c[2]*0.4, c[3]*0.4, 0.75 * alpha)
  drawPart(ship, arwingParts.leftWing, s, c[1]*0.35, c[2]*0.35, c[3]*0.35, 0.7 * alpha)
  drawPart(ship, arwingParts.rightWing, s, c[1]*0.35, c[2]*0.35, c[3]*0.35, 0.7 * alpha)
  drawPart(ship, arwingParts.leftFin, s, c[1]*0.5, c[2]*0.5, c[3]*0.5, 0.6 * alpha)
  drawPart(ship, arwingParts.rightFin, s, c[1]*0.5, c[2]*0.5, c[3]*0.5, 0.6 * alpha)
  -- Bright nose cone
  drawPart(ship, arwingParts.noseCone, s, ac[1]*0.6, ac[2]*0.6, ac[3]*0.6, 0.8 * alpha)

  -- Wireframe edges (bright ship colour)
  love.graphics.setLineWidth(0.8)
  drawPart(ship, arwingParts.body, s, c[1], c[2], c[3], alpha, "line")
  drawPart(ship, arwingParts.leftWing, s, c[1], c[2], c[3], alpha, "line")
  drawPart(ship, arwingParts.rightWing, s, c[1], c[2], c[3], alpha, "line")
  drawPart(ship, arwingParts.leftFin, s, ac[1], ac[2], ac[3], 0.8 * alpha, "line")
  drawPart(ship, arwingParts.rightFin, s, ac[1], ac[2], ac[3], 0.8 * alpha, "line")
  drawPart(ship, arwingParts.noseCone, s, ac[1], ac[2], ac[3], 0.8 * alpha, "line")

  -- Cockpit canopy glow
  local cosA = math.cos(ship.angle)
  local sinA = math.sin(ship.angle)
  local cx = ship.x + (0 * cosA - (-6 * s) * sinA)
  local cy = ship.y + (0 * sinA + (-6 * s) * cosA)
  love.graphics.setColor(0.4, 0.85, 1, 0.5 * alpha)
  love.graphics.circle("fill", cx, cy, math.max(1, 3 * s))
  love.graphics.setColor(1, 1, 1, 0.4 * alpha)
  love.graphics.circle("fill", cx, cy, math.max(0.5, 1.5 * s))
end

function M.draw()
  love.graphics.setColor(0.01, 0.01, 0.03)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Background stars
  for _, star in ipairs(stars) do
    if star.background then
      local twinkle = math.max(0, math.sin(time * star.twinkleSpeed + star.twinkleOffset) * star.twinkleAmp + (1 - star.twinkleAmp))
      local alpha = star.brightness * twinkle
      love.graphics.setColor(star.r * alpha, star.g * alpha, star.b * alpha)
      love.graphics.circle("fill", centerX + star.x, centerY + star.y, star.size)
    end
  end

  local cosR = math.cos(rotation)
  local sinR = math.sin(rotation)

  -- Nebula clouds
  for _, cloud in ipairs(nebulaClouds) do
    local rx = cloud.x * cosR - cloud.y * sinR
    local ry = cloud.x * sinR + cloud.y * cosR
    local screenX = centerX + rx
    local screenY = centerY + ry

    local pulse = math.sin(time * cloud.pulseSpeed + cloud.pulseOffset) * 0.15 + 1
    local baseRadius = cloud.radius * pulse

    for layer = cloud.layers, 1, -1 do
      local layerRadius = baseRadius * (0.4 + layer * 0.25)
      local layerOpacity = cloud.color[4] * (1.2 - layer * 0.3)

      for i = 1, 6 do
        local cloudAngle = (i / 6) * math.pi * 2 + time * 0.03
        local offsetX = math.cos(cloudAngle) * layerRadius * 0.25
        local offsetY = math.sin(cloudAngle) * layerRadius * 0.25
        love.graphics.setColor(cloud.color[1], cloud.color[2], cloud.color[3], layerOpacity * 0.4)
        love.graphics.circle("fill", screenX + offsetX, screenY + offsetY, layerRadius * 0.6)
      end

      love.graphics.setColor(cloud.color[1], cloud.color[2], cloud.color[3], layerOpacity * 0.6)
      love.graphics.circle("fill", screenX, screenY, layerRadius * 0.4)
    end
  end

  -- Galactic core glow
  for i = 8, 1, -1 do
    local glowSize = coreRadius * i * 0.8
    local alpha = 0.04 / (i * 0.5)
    love.graphics.setColor(1, 0.85, 0.6, alpha)
    love.graphics.circle("fill", centerX, centerY, glowSize)
  end
  for i = 6, 1, -1 do
    local glowSize = coreRadius * i * 0.5
    local alpha = 0.03 / (i * 0.5)
    love.graphics.setColor(0.8, 0.7, 1, alpha)
    love.graphics.circle("fill", centerX, centerY, glowSize)
  end

  -- Rotating galaxy stars
  for _, star in ipairs(stars) do
    if not star.background then
      local screenX = centerX + star.x * cosR - star.y * sinR
      local screenY = centerY + star.x * sinR + star.y * cosR

      local twinkle = math.max(0, math.sin(time * star.twinkleSpeed + star.twinkleOffset) * star.twinkleAmp + (1 - star.twinkleAmp))
      local alpha = star.brightness * twinkle

      love.graphics.setColor(star.r * alpha, star.g * alpha, star.b * alpha)
      love.graphics.circle("fill", screenX, screenY, star.size)

      if star.core then
        love.graphics.setColor(star.r, star.g, star.b, alpha * 0.25)
        love.graphics.circle("fill", screenX, screenY, star.size * 2.5)
        love.graphics.setColor(star.r, star.g, star.b, alpha * 0.1)
        love.graphics.circle("fill", screenX, screenY, star.size * 4)
      end

      if star.hasDiffraction then
        love.graphics.setColor(star.r, star.g, star.b, alpha * 0.5)
        local spikeLen = star.size * 6
        love.graphics.setLineWidth(1)
        love.graphics.line(screenX - spikeLen, screenY, screenX + spikeLen, screenY)
        love.graphics.line(screenX, screenY - spikeLen, screenX, screenY + spikeLen)
        love.graphics.setColor(star.r, star.g, star.b, alpha * 0.25)
        local diagLen = spikeLen * 0.6
        love.graphics.line(screenX - diagLen, screenY - diagLen, screenX + diagLen, screenY + diagLen)
        love.graphics.line(screenX - diagLen, screenY + diagLen, screenX + diagLen, screenY - diagLen)
      end
    end
  end

  -- Pleiades-style bright stars
  for _, ps in ipairs(pleiadesStars) do
    local screenX = centerX + ps.x * cosR - ps.y * sinR
    local screenY = centerY + ps.x * sinR + ps.y * cosR

    local pulse = math.sin(time * ps.pulseSpeed + ps.pulseOffset) * 0.15 + 0.85
    local alpha = ps.brightness * pulse

    love.graphics.setColor(ps.colorR * 0.4, ps.colorG * 0.5, ps.colorB, alpha * 0.06)
    love.graphics.circle("fill", screenX, screenY, ps.haloSize * 1.5)
    love.graphics.setColor(ps.colorR * 0.5, ps.colorG * 0.6, ps.colorB, alpha * 0.1)
    love.graphics.circle("fill", screenX, screenY, ps.haloSize)
    love.graphics.setColor(ps.colorR * 0.6, ps.colorG * 0.7, ps.colorB, alpha * 0.15)
    love.graphics.circle("fill", screenX, screenY, ps.haloSize * 0.6)
    love.graphics.setColor(ps.colorR * 0.8, ps.colorG * 0.85, ps.colorB, alpha * 0.3)
    love.graphics.circle("fill", screenX, screenY, ps.size * 2.5)
    love.graphics.setColor(ps.colorR, ps.colorG, ps.colorB, alpha)
    love.graphics.circle("fill", screenX, screenY, ps.size)
    love.graphics.setColor(1, 1, 1, alpha * 0.95)
    love.graphics.circle("fill", screenX, screenY, ps.size * 0.5)

    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(ps.colorR * 0.9, ps.colorG * 0.95, ps.colorB, alpha * 0.6)
    local spikeLen = ps.size * 6
    love.graphics.line(screenX - spikeLen, screenY, screenX + spikeLen, screenY)
    love.graphics.line(screenX, screenY - spikeLen, screenX, screenY + spikeLen)
    love.graphics.setColor(ps.colorR * 0.8, ps.colorG * 0.9, ps.colorB, alpha * 0.3)
    local diagLen = spikeLen * 0.7
    love.graphics.line(screenX - diagLen, screenY - diagLen, screenX + diagLen, screenY + diagLen)
    love.graphics.line(screenX - diagLen, screenY + diagLen, screenX + diagLen, screenY - diagLen)
  end

  -- Spaceships with trails
  for _, ship in ipairs(ships) do
    -- Compute distance to target for shrink effect
    local destX, destY = getPleiadesScreenPos(ship.targetStarIdx)
    local dx = destX - ship.x
    local dy = destY - ship.y
    local distToStar = math.sqrt(dx * dx + dy * dy)
    -- Shrink as ship approaches (start shrinking within 120px)
    local shrink = math.min(1, distToStar / 120)
    local shipSize = math.max(1, ship.baseSize * (0.15 + 0.85 * shrink))
    local fa = ship.fadeAlpha  -- fade out on arrival

    -- Trail: older = larger (farther from star)
    for j, pt in ipairs(ship.trail) do
      local trailFrac = j / TRAIL_LEN
      local dotSize = math.max(0.3, shipSize * 0.35 + trailFrac * 3.5)
      local alpha = (1 - trailFrac) * 0.5 * fa
      love.graphics.setColor(ship.r, ship.g, ship.b, alpha)
      love.graphics.circle("fill", pt.x, pt.y, dotSize)
    end

    -- Engine glow
    love.graphics.setColor(ship.r, ship.g, ship.b, 0.25 * fa)
    love.graphics.circle("fill", ship.x, ship.y, shipSize * 2)

    -- Ship (full Arwing-style)
    drawShipShape(ship, shipSize, 0.9 * fa)
  end

  -- Central bright core
  love.graphics.setColor(1, 0.9, 0.7, 0.4)
  love.graphics.circle("fill", centerX, centerY, 22)
  love.graphics.setColor(1, 0.95, 0.8, 0.6)
  love.graphics.circle("fill", centerX, centerY, 13)
  love.graphics.setColor(1, 0.98, 0.9, 0.85)
  love.graphics.circle("fill", centerX, centerY, 7)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.circle("fill", centerX, centerY, 3.5)
end

return M
