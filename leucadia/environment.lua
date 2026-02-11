-- leucadia/environment.lua
-- Dynamic environmental effects for Leucadia beach town
-- Clouds, wind, tides, waves, and beach crabs

local M = {}
local lighting = require("leucadia.lighting")

-- Wind state
local wind = {
  baseStrength = 0.5,
  currentStrength = 0.5,
  gustTimer = 0,
  gustDuration = 0,
  gustStrength = 0,
  direction = 1  -- 1 = right, -1 = left (prevailing westerly wind from ocean)
}

-- Cloud state (persistent per day)
local clouds = {}
local cloudsSeed = 0

-- Tide state
local tide = {
  level = 0.5,  -- 0 = low, 1 = high
  rising = true,
  cycleDuration = 180,  -- 3 minutes for full tide cycle
  timer = 0
}

-- Crabs (generated at low tide)
local crabs = {}

-- Waves (generated at high tide)
local waves = {}

-- Initialize environment
function M.init()
  M.regenerateClouds()
  M.regenerateTide()
end

-- Regenerate clouds based on day number
function M.regenerateClouds()
  local day = lighting.getDayNumber()
  if cloudsSeed == day then return end  -- Already generated for today
  cloudsSeed = day

  clouds = {}
  math.randomseed(day * 12345)

  local numClouds = 8 + math.random(0, 6)
  for i = 1, numClouds do
    local cloud = {
      x = math.random(-200, 1800),
      y = math.random(20, 150),
      width = math.random(80, 200),
      height = math.random(30, 60),
      speed = 5 + math.random() * 10,
      puffs = {},
      opacity = 0.6 + math.random() * 0.3
    }

    -- Generate cloud puffs (fluffy parts)
    local numPuffs = 3 + math.random(0, 4)
    for j = 1, numPuffs do
      table.insert(cloud.puffs, {
        offsetX = (j - 1) * (cloud.width / numPuffs) - cloud.width / 2 + math.random(-10, 10),
        offsetY = math.random(-10, 10),
        radius = cloud.height / 2 + math.random(-10, 15)
      })
    end

    table.insert(clouds, cloud)
  end

  math.randomseed(os.time())  -- Reset random seed
end

-- Regenerate tide state (called when exiting buildings)
function M.regenerateTide()
  -- Randomize tide position
  tide.level = math.random() * 0.4 + 0.3  -- Between 0.3 and 0.7
  tide.rising = math.random() > 0.5
  tide.timer = 0

  -- Regenerate crabs and waves based on tide
  M.regenerateBeachLife()
end

-- Regenerate crabs/waves based on current tide
function M.regenerateBeachLife()
  crabs = {}
  waves = {}

  if tide.level < 0.5 then
    -- Low tide: spawn crabs
    local numCrabs = 5 + math.floor((0.5 - tide.level) * 20)
    for i = 1, numCrabs do
      table.insert(crabs, {
        x = math.random(50, 900),
        y = math.random(900, 1100),  -- Beach area (y = 28-35 in grid = ~900-1120 pixels)
        targetX = 0,
        targetY = 0,
        moving = false,
        moveTimer = math.random() * 3,
        direction = 1,
        animFrame = 0,
        speed = 30 + math.random() * 20
      })
    end
  else
    -- High tide: create wave patterns
    local numWaves = 3 + math.floor(tide.level * 5)
    for i = 1, numWaves do
      table.insert(waves, {
        x = -100,
        y = 1000 + i * 25,  -- Staggered wave lines
        progress = i * 0.3,  -- Offset timing
        speed = 80 + math.random() * 40,
        amplitude = 8 + math.random() * 8,
        wavelength = 100 + math.random() * 50
      })
    end
  end
end

-- Update environment
function M.update(dt)
  M.updateWind(dt)
  M.updateClouds(dt)
  M.updateTide(dt)
  M.updateCrabs(dt)
  M.updateWaves(dt)
end

function M.updateWind(dt)
  -- Base wind varies with time of day
  local hour = lighting.getHour()
  if hour >= 10 and hour <= 16 then
    wind.baseStrength = 0.6 + math.sin(hour * 0.5) * 0.2  -- Stronger midday
  else
    wind.baseStrength = 0.3 + math.sin(hour * 0.3) * 0.1  -- Calmer morning/evening
  end

  -- Wind gusts
  wind.gustTimer = wind.gustTimer - dt
  if wind.gustTimer <= 0 then
    wind.gustDuration = 1 + math.random() * 2
    wind.gustStrength = math.random() * 0.5
    wind.gustTimer = 3 + math.random() * 5
  end

  if wind.gustDuration > 0 then
    wind.gustDuration = wind.gustDuration - dt
    local gustFade = math.min(1, wind.gustDuration / 0.5)
    wind.currentStrength = wind.baseStrength + wind.gustStrength * gustFade
  else
    wind.currentStrength = wind.baseStrength
  end
end

function M.updateClouds(dt)
  for _, cloud in ipairs(clouds) do
    cloud.x = cloud.x + cloud.speed * wind.currentStrength * dt

    -- Wrap clouds around screen
    if cloud.x > 1600 then
      cloud.x = -cloud.width
    end
  end
end

function M.updateTide(dt)
  tide.timer = tide.timer + dt

  -- Gradual tide change
  local tideSpeed = 0.3 / tide.cycleDuration  -- Full cycle in cycleDuration seconds
  if tide.rising then
    tide.level = tide.level + tideSpeed * dt
    if tide.level >= 1 then
      tide.level = 1
      tide.rising = false
    end
  else
    tide.level = tide.level - tideSpeed * dt
    if tide.level <= 0 then
      tide.level = 0
      tide.rising = true
    end
  end

  -- Regenerate beach life when crossing thresholds
  if tide.timer > 30 then  -- Check every 30 seconds
    tide.timer = 0
    M.regenerateBeachLife()
  end
end

function M.updateCrabs(dt)
  for _, crab in ipairs(crabs) do
    crab.animFrame = crab.animFrame + dt * 8

    if crab.moving then
      -- Move toward target
      local dx = crab.targetX - crab.x
      local dy = crab.targetY - crab.y
      local dist = math.sqrt(dx * dx + dy * dy)

      if dist < 5 then
        crab.moving = false
        crab.moveTimer = 1 + math.random() * 4
      else
        crab.x = crab.x + (dx / dist) * crab.speed * dt
        crab.y = crab.y + (dy / dist) * crab.speed * dt
        crab.direction = dx > 0 and 1 or -1
      end
    else
      crab.moveTimer = crab.moveTimer - dt
      if crab.moveTimer <= 0 then
        -- Pick new random target
        crab.targetX = crab.x + math.random(-100, 100)
        crab.targetY = crab.y + math.random(-50, 50)
        -- Keep within beach bounds
        crab.targetX = math.max(50, math.min(900, crab.targetX))
        crab.targetY = math.max(900, math.min(1100, crab.targetY))
        crab.moving = true
      end
    end
  end
end

function M.updateWaves(dt)
  for _, wave in ipairs(waves) do
    wave.progress = wave.progress + dt * 0.5
    if wave.progress > 1.5 then
      wave.progress = -0.5
    end
  end
end

-- Get current wind strength (0-1)
function M.getWindStrength()
  return wind.currentStrength
end

-- Get wind sway offset for a given position and time
function M.getWindSway(x, time, amplitude)
  amplitude = amplitude or 1
  local phase = x * 0.01 + time * 2 * wind.currentStrength
  local sway = math.sin(phase) * wind.currentStrength * amplitude
  -- Add some higher frequency wobble during gusts
  if wind.gustDuration > 0 then
    sway = sway + math.sin(phase * 3 + time * 5) * wind.gustStrength * 0.3 * amplitude
  end
  return sway
end

-- Get tide level (0 = low, 1 = high)
function M.getTideLevel()
  return tide.level
end

-- Draw sky with gradient
function M.drawSky(screenW, screenH)
  local horizonColor, zenithColor = lighting.getSkyColors()

  -- Draw gradient from horizon to zenith
  local segments = 20
  for i = 0, segments - 1 do
    local t1 = i / segments
    local t2 = (i + 1) / segments
    local y1 = t1 * screenH * 0.4
    local y2 = t2 * screenH * 0.4

    local r = zenithColor[1] + (horizonColor[1] - zenithColor[1]) * t1
    local g = zenithColor[2] + (horizonColor[2] - zenithColor[2]) * t1
    local b = zenithColor[3] + (horizonColor[3] - zenithColor[3]) * t1

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, y1, screenW, y2 - y1 + 1)
  end
end

-- Draw clouds
function M.drawClouds(cameraX, cameraY, time)
  local sunsetGlow = lighting.getSunsetGlow()

  for _, cloud in ipairs(clouds) do
    -- Parallax effect: clouds move slower than camera
    local parallaxX = cloud.x - cameraX * 0.1
    local parallaxY = cloud.y

    -- Cloud color changes with sunset
    local r, g, b = 0.95, 0.95, 0.98
    if sunsetGlow > 0 then
      r = 0.95 + sunsetGlow * 0.05
      g = 0.95 - sunsetGlow * 0.25
      b = 0.98 - sunsetGlow * 0.4
    end

    love.graphics.setColor(r, g, b, cloud.opacity)

    -- Draw cloud puffs
    for _, puff in ipairs(cloud.puffs) do
      local puffX = parallaxX + puff.offsetX
      local puffY = parallaxY + puff.offsetY
      love.graphics.ellipse("fill", puffX, puffY, puff.radius * 1.2, puff.radius * 0.8)
    end

    -- Cloud shadow on ground (only during day)
    if not lighting.isNight() then
      local shadowY = 800 + parallaxY * 2  -- Project onto ground
      love.graphics.setColor(0, 0, 0, 0.05 * cloud.opacity)
      for _, puff in ipairs(cloud.puffs) do
        love.graphics.ellipse("fill",
          parallaxX + puff.offsetX + 50,
          shadowY,
          puff.radius * 1.5,
          puff.radius * 0.3
        )
      end
    end
  end
end

-- Draw palm tree with wind animation
function M.drawPalmTree(x, y, gs, time)
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Trunk (slight sway)
  local trunkSway = M.getWindSway(x * gs, time, 3)
  love.graphics.setColor(0.45, 0.35, 0.25)

  -- Trunk segments with increasing sway
  local trunkHeight = gs * 2.5
  local segments = 8
  for i = 0, segments - 1 do
    local t = i / segments
    local segSway = trunkSway * t * t  -- Quadratic sway increase
    local width = 8 - t * 4  -- Taper

    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1/segments) * trunkHeight
    local x1 = baseX + segSway * t
    local x2 = baseX + segSway * (t + 1/segments)

    love.graphics.polygon("fill",
      x1 - width/2, y1,
      x1 + width/2, y1,
      x2 + width/2 - 0.5, y2,
      x2 - width/2 + 0.5, y2
    )
  end

  -- Palm fronds
  local topX = baseX + trunkSway
  local topY = baseY - trunkHeight
  local numFronds = 7

  for i = 1, numFronds do
    local angle = (i / numFronds) * math.pi * 1.5 - math.pi * 0.75
    local frondSway = M.getWindSway(x * gs + i * 20, time + i * 0.2, 8)

    -- Each frond curves outward and droops
    local frondLength = 35 + math.sin(i * 2) * 8
    local droop = 0.3 + math.abs(math.cos(angle)) * 0.4

    -- Frond stem
    love.graphics.setColor(0.3, 0.5, 0.25)
    local segments2 = 6
    local lastX, lastY = topX, topY

    for j = 1, segments2 do
      local t = j / segments2
      local stemAngle = angle + frondSway * 0.02 * t
      local droopAngle = droop * t * t
      local length = frondLength * t

      local fx = topX + math.cos(stemAngle) * length + frondSway * t * 0.5
      local fy = topY + math.sin(stemAngle) * length * 0.3 - (1 - t) * 20 + droopAngle * 30

      love.graphics.setLineWidth(3 - t * 2)
      love.graphics.line(lastX, lastY, fx, fy)

      -- Leaflets
      if j > 1 then
        love.graphics.setColor(0.25, 0.55, 0.2)
        local leafAngle1 = stemAngle + math.pi/2
        local leafAngle2 = stemAngle - math.pi/2
        local leafLen = 12 - t * 6
        local leafSway = frondSway * 0.1

        love.graphics.polygon("fill",
          fx, fy,
          fx + math.cos(leafAngle1 + leafSway * 0.1) * leafLen, fy + math.sin(leafAngle1) * leafLen * 0.5,
          fx + math.cos(stemAngle) * 3, fy + math.sin(stemAngle) * 1
        )
        love.graphics.polygon("fill",
          fx, fy,
          fx + math.cos(leafAngle2 - leafSway * 0.1) * leafLen, fy + math.sin(leafAngle2) * leafLen * 0.5,
          fx + math.cos(stemAngle) * 3, fy + math.sin(stemAngle) * 1
        )
      end

      lastX, lastY = fx, fy
    end
  end

  -- Coconuts
  love.graphics.setColor(0.4, 0.3, 0.2)
  love.graphics.ellipse("fill", topX - 3, topY + 5, 4, 5)
  love.graphics.ellipse("fill", topX + 4, topY + 3, 4, 5)
end

-- Draw crabs on the beach
function M.drawCrabs()
  for _, crab in ipairs(crabs) do
    local frame = math.floor(crab.animFrame) % 4
    local legOffset = (frame % 2) * 2

    -- Body
    love.graphics.setColor(0.8, 0.4, 0.3)
    love.graphics.ellipse("fill", crab.x, crab.y, 8, 5)

    -- Claws
    local clawAnim = math.sin(crab.animFrame * 2) * 0.3
    love.graphics.setColor(0.85, 0.45, 0.35)
    love.graphics.ellipse("fill",
      crab.x + crab.direction * 10,
      crab.y - 2 + clawAnim,
      5, 3
    )
    love.graphics.ellipse("fill",
      crab.x + crab.direction * 10,
      crab.y + 2 - clawAnim,
      5, 3
    )

    -- Eyes
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("fill", crab.x + crab.direction * 4, crab.y - 4, 2)
    love.graphics.circle("fill", crab.x + crab.direction * 2, crab.y - 4, 2)

    -- Legs
    love.graphics.setColor(0.7, 0.35, 0.25)
    for i = -2, 2 do
      if i ~= 0 then
        local legX = crab.x + i * 3
        local legY = crab.y + 4 + ((math.abs(i) + frame) % 2) * 2
        love.graphics.line(crab.x, crab.y, legX, legY)
      end
    end
  end
end

-- Draw waves at high tide
function M.drawWaves(gs, time)
  local tideOffset = (1 - tide.level) * 100  -- Waves move back with tide

  for _, wave in ipairs(waves) do
    if wave.progress > 0 and wave.progress < 1 then
      love.graphics.setColor(0.3, 0.6, 0.8, 0.6 * (1 - math.abs(wave.progress - 0.5) * 2))

      -- Draw wave line with foam
      local waveY = wave.y + tideOffset - wave.progress * 80
      local points = {}

      for x = 0, 1000, 10 do
        local waveOffset = math.sin(x / wave.wavelength + time * 3) * wave.amplitude
        table.insert(points, x)
        table.insert(points, waveY + waveOffset)
      end

      if #points >= 4 then
        love.graphics.setLineWidth(3)
        love.graphics.line(points)

        -- Foam
        love.graphics.setColor(1, 1, 1, 0.4 * (1 - wave.progress))
        love.graphics.setLineWidth(1)
        for x = 0, 1000, 20 do
          local foamY = waveY + math.sin(x / wave.wavelength + time * 3) * wave.amplitude
          love.graphics.circle("fill", x, foamY - 2, 3 + math.random() * 2)
        end
      end
    end
  end

  -- Beach water edge
  local waterY = 1050 + tideOffset
  love.graphics.setColor(0.25, 0.55, 0.75, 0.5)
  love.graphics.rectangle("fill", 0, waterY, 1000, 200)

  -- Foam line at water edge
  love.graphics.setColor(1, 1, 1, 0.3)
  for x = 0, 1000, 5 do
    local foamOffset = math.sin(x * 0.1 + time * 2) * 3
    love.graphics.circle("fill", x, waterY + foamOffset, 2)
  end
end

-- Draw tide indicator in UI
function M.drawTideIndicator(x, y)
  love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
  love.graphics.rectangle("fill", x, y, 60, 20, 3, 3)

  love.graphics.setColor(0.3, 0.6, 0.8)
  love.graphics.rectangle("fill", x + 2, y + 14, 56 * tide.level, 4)

  love.graphics.setColor(1, 1, 1)
  love.graphics.print(tide.rising and "Tide ▲" or "Tide ▼", x + 5, y + 2)
end

return M
