-- leucadia/environment.lua
-- Dynamic environmental effects for Leucadia beach town
-- Clouds, wind, tides, waves, and beach crabs

local M = {}
local lighting = require("leucadia.lighting")

-- Wind state
local wind = {
  baseStrength = 0.5,
  currentStrength = 0.5,
  targetStrength = 0.5,
  gustTimer = 0,
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

  -- Gentle gusts: smoothly vary target strength over time
  wind.gustTimer = wind.gustTimer - dt
  if wind.gustTimer <= 0 then
    wind.targetStrength = wind.baseStrength + math.random() * 0.2
    wind.gustTimer = 5 + math.random() * 8
  end

  -- Smooth interpolation toward target (eliminates jerky gust transitions)
  wind.currentStrength = wind.currentStrength + (wind.targetStrength - wind.currentStrength) * 0.4 * dt
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
  -- Use position to create unique phase offset for each tree
  local positionPhase = x * 0.023  -- Different phase for each position
  local phase = positionPhase + time * 0.6 * wind.currentStrength

  -- Smooth sinusoidal sway with secondary frequency for natural motion
  local sway = math.sin(phase) * wind.currentStrength * amplitude
  sway = sway + math.sin(phase * 0.7 + positionPhase * 2) * wind.currentStrength * amplitude * 0.25

  return sway
end

-- Get tide level (0 = low, 1 = high)
function M.getTideLevel()
  return tide.level
end

-- Draw horizon with ocean below
function M.drawHorizon(screenW, screenH, cameraY)
  local horizonColor, zenithColor = lighting.getSkyColors()
  local sunsetGlow = lighting.getSunsetGlow()
  
  -- Calculate horizon position (fixed in world space, moves with camera)
  local worldHorizonY = -200  -- Horizon line in world coordinates
  local screenHorizonY = worldHorizonY - cameraY + screenH / 2
  
  -- Draw ocean below horizon
  if screenHorizonY < screenH then
    local oceanStartY = math.max(0, screenHorizonY)
    local oceanHeight = screenH - oceanStartY
    
    -- Ocean gradient (darker at bottom, lighter at horizon)
    local segments = 15
    for i = 0, segments - 1 do
      local t1 = i / segments
      local t2 = (i + 1) / segments
      local y1 = oceanStartY + t1 * oceanHeight
      local y2 = oceanStartY + t2 * oceanHeight
      
      -- Deeper blue at bottom, lighter at horizon
      local depth = 1 - t1 * 0.4
      local r = 0.15 * depth + sunsetGlow * 0.3
      local g = 0.4 * depth + sunsetGlow * 0.1
      local b = 0.6 * depth - sunsetGlow * 0.2
      
      love.graphics.setColor(r, g, b)
      love.graphics.rectangle("fill", 0, y1, screenW, y2 - y1 + 1)
    end
    
    -- Add subtle wave texture to distant ocean
    love.graphics.setColor(1, 1, 1, 0.05)
    for i = 1, 8 do
      local waveY = oceanStartY + oceanHeight * (i / 10)
      local waveOffset = math.sin(love.timer.getTime() * 0.5 + i * 0.8) * 3
      love.graphics.line(0, waveY + waveOffset, screenW, waveY + waveOffset)
    end
  end
  
  -- Draw horizon line (slight haze)
  if screenHorizonY >= 0 and screenHorizonY < screenH then
    love.graphics.setColor(horizonColor[1], horizonColor[2], horizonColor[3], 0.3)
    love.graphics.rectangle("fill", 0, screenHorizonY - 2, screenW, 4)
  end
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

-- Draw palm tree with wind animation (Southern California style)
function M.drawPalmTree(x, y, gs, time, variety)
  variety = variety or 1
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Per-tree seed for consistent variation
  local treeSeed = x * 7 + y * 13

  -- Medjool date palm trunk
  local trunkSway = M.getWindSway(x * gs, time, 2)
  local trunkHeight = variety == 1 and gs * 3.5 or gs * 3.0
  local trunkBaseWidth = variety == 1 and 14 or 11

  -- Draw trunk with diamond cross-hatch pattern (old leaf bases)
  local segments = 18
  for i = 0, segments - 1 do
    local t = i / segments
    local segSway = trunkSway * t * t
    local width = trunkBaseWidth - t * (variety == 1 and 5 or 4)

    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1/segments) * trunkHeight
    local x1 = baseX + segSway * t
    local x2 = baseX + segSway * (t + 1/segments)

    -- Gray-brown trunk color typical of Medjool date palms
    local barkShade = 0.92 - (t * 0.12) + math.sin(treeSeed + i * 2.3) * 0.05
    love.graphics.setColor(0.46 * barkShade, 0.40 * barkShade, 0.34 * barkShade)
    love.graphics.polygon("fill",
      x1 - width/2, y1,
      x1 + width/2, y1,
      x2 + width/2 - 0.3, y2,
      x2 - width/2 + 0.3, y2
    )

    -- Diamond cross-hatch pattern (old leaf bases) on lower 2/3 of trunk
    if t < 0.65 then
      love.graphics.setColor(0.36 * barkShade, 0.31 * barkShade, 0.26 * barkShade)
      love.graphics.setLineWidth(1.2)
      local cx = (x1 + x2) / 2
      local cy = (y1 + y2) / 2
      local hw = width * 0.38
      local hh = (trunkHeight / segments) * 0.42
      love.graphics.line(cx - hw, cy, cx, cy - hh)
      love.graphics.line(cx, cy - hh, cx + hw, cy)
      love.graphics.line(cx + hw, cy, cx, cy + hh)
      love.graphics.line(cx, cy + hh, cx - hw, cy)
    end

    -- Upper trunk: smoother, lighter bark
    if t >= 0.65 then
      love.graphics.setColor(0.50 * barkShade, 0.44 * barkShade, 0.38 * barkShade, 0.4)
      love.graphics.setLineWidth(1)
      love.graphics.line(x1 - width/4, y1, x2 - width/4, y2)
    end

    -- Light highlight on right side of trunk
    love.graphics.setColor(0.55 * barkShade, 0.48 * barkShade, 0.40 * barkShade, 0.25)
    love.graphics.polygon("fill",
      x1 + width/4, y1,
      x1 + width/2, y1,
      x2 + width/2 - 0.3, y2,
      x2 + width/4, y2
    )
  end

  -- Crown position
  local topX = baseX + trunkSway
  local topY = baseY - trunkHeight

  -- Old frond stubs / fiber skirt hanging below crown
  love.graphics.setColor(0.42, 0.34, 0.22, 0.7)
  for i = 1, 7 do
    local stubAngle = (i / 7) * math.pi + math.sin(treeSeed + i) * 0.3
    local stubLen = 8 + math.sin(treeSeed * 0.7 + i * 1.5) * 3
    love.graphics.setLineWidth(2)
    love.graphics.line(
      topX, topY + 6,
      topX + math.cos(stubAngle) * stubLen,
      topY + 6 + math.abs(math.sin(stubAngle)) * stubLen * 0.5 + 6
    )
  end

  -- Date clusters hanging below crown
  if variety == 1 then
    for i = 1, 3 do
      local clusterAngle = (i / 3) * math.pi * 2 + math.sin(treeSeed) * 0.5
      local clusterX = topX + math.cos(clusterAngle) * 10
      local clusterSway = M.getWindSway(x * gs + i * 50, time, 1) * 0.2
      -- Date stem
      love.graphics.setColor(0.45, 0.38, 0.22)
      love.graphics.setLineWidth(1.5)
      love.graphics.line(topX, topY + 3, clusterX + clusterSway, topY + 12)
      -- Date bunch
      love.graphics.setColor(0.38, 0.20, 0.08)
      love.graphics.ellipse("fill", clusterX + clusterSway, topY + 16, 4, 7)
      -- Individual date highlights
      love.graphics.setColor(0.52, 0.30, 0.14, 0.5)
      love.graphics.circle("fill", clusterX + clusterSway - 1.5, topY + 14, 1.5)
      love.graphics.circle("fill", clusterX + clusterSway + 1.5, topY + 17, 1.5)
    end
  end

  -- Crown center bulge (where fronds emerge)
  love.graphics.setColor(0.35, 0.28, 0.18)
  love.graphics.ellipse("fill", topX, topY, 6, 4)
  love.graphics.setColor(0.32, 0.45, 0.22)
  love.graphics.ellipse("fill", topX, topY - 2, 5, 3)

  -- Sun glow state for frond lighting
  local sunAngle = lighting.getSunAngle()  -- nil at night, 0=east horizon, pi/2=zenith, pi=west
  local sunGlow = lighting.getSunsetGlow() -- 0-1, peaks at sunrise/sunset
  local ambientColor, ambientIntensity = lighting.getAmbientLight()
  local hasSun = sunAngle ~= nil
  local sunDirX, sunDirY = 0, 0
  local sunHeight = 0
  if hasSun then
    sunDirX = -math.cos(sunAngle)  -- sun direction: -1 (east) to 1 (west)
    sunHeight = math.sin(sunAngle)  -- 0 at horizon, 1 at zenith
    sunDirY = -sunHeight             -- sun is above, so y points up
  end

  -- Sun glow color shifts: golden at golden hour, warm white midday, orange/pink at sunset
  local glowR, glowG, glowB = 1.0, 0.95, 0.8  -- default warm white
  if hasSun then
    if sunGlow > 0.1 then
      -- Sunrise/sunset: blend toward warm orange-gold
      glowR = 1.0
      glowG = 0.65 + (1 - sunGlow) * 0.25
      glowB = 0.3 + (1 - sunGlow) * 0.4
    elseif sunHeight < 0.5 then
      -- Low sun (golden hour): warm gold
      local goldenT = 1 - sunHeight / 0.5
      glowR = 1.0
      glowG = 0.85 + goldenT * (-0.1)
      glowB = 0.7 + goldenT * (-0.25)
    end
  end

  -- Crown of fronds (lush, vibrant — radiating outward from central core)
  local numFronds = variety == 1 and 16 or 13

  for i = 1, numFronds do
    local frondSeed = treeSeed + i * 3.7

    -- Evenly distributed around crown with natural variation
    local baseAngle = (i / numFronds) * math.pi * 2
    local angleVariation = math.sin(frondSeed) * 0.18 + math.cos(frondSeed * 1.3) * 0.12
    local angle = baseAngle + angleVariation

    -- Wind sway per frond
    local frondSway = M.getWindSway(x * gs + i * 25, time + i * 0.15, 5)

    -- Frond length with per-frond variation — longer, healthier fronds
    local lengthVariation = math.sin(frondSeed * 2.1) * 6
    local frondLength = (variety == 1 and 58 or 48) + lengthVariation

    -- Direction this frond radiates: full 360° burst from center
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)

    -- Multiple shades of green for depth — vivid, saturated greens
    local greenShade = 0.92 + math.sin(i * 1.7) * 0.08

    -- Draw frond rachis with pinnate leaflets
    local frondSegs = 10
    local lastX, lastY = topX, topY

    for j = 1, frondSegs do
      local t = j / frondSegs
      local stemAngle = angle + frondSway * 0.008 * t
      local length = frondLength * t

      -- Radiating outward: fronds shoot out from core in all directions
      -- Strong outward thrust that holds shape, only the lightest tip droop
      local outwardForce = (1 - t * t) * 18  -- pushes frond away from trunk
      local tipCurve = t * t * t * t * 6      -- tiny graceful tip curve, not droopy

      local fx = topX + math.cos(stemAngle) * length * 0.90 + frondSway * t * 0.15
      local fy = topY + math.sin(stemAngle) * length * 0.55 - outwardForce + tipCurve

      -- Rachis color (rich dark green stem)
      love.graphics.setColor(0.22 * greenShade, 0.42 * greenShade, 0.16 * greenShade)
      love.graphics.setLineWidth(3.5 - t * 2.5)
      love.graphics.line(lastX, lastY, fx, fy)

      -- Pinnate leaflets along rachis (skip the very base)
      if j >= 2 then
        local leafLen = (18 - t * 10) * (variety == 1 and 1.0 or 0.85)
        local rachisAngle = math.atan2(fy - lastY, fx - lastX)
        local leafSway = frondSway * 0.03 * t

        -- Left leaflet — lush vibrant green
        local leftAngle = rachisAngle - math.pi / 2.6 + leafSway * 0.06
        love.graphics.setColor(0.20 * greenShade, 0.52 * greenShade, 0.15 * greenShade)
        love.graphics.polygon("fill",
          fx, fy,
          fx + math.cos(leftAngle) * leafLen, fy + math.sin(leftAngle) * leafLen,
          fx + math.cos(leftAngle + 0.22) * leafLen * 0.58, fy + math.sin(leftAngle + 0.22) * leafLen * 0.58
        )

        -- Right leaflet — slightly lighter for depth
        local rightAngle = rachisAngle + math.pi / 2.6 - leafSway * 0.06
        love.graphics.setColor(0.24 * greenShade, 0.56 * greenShade, 0.18 * greenShade)
        love.graphics.polygon("fill",
          fx, fy,
          fx + math.cos(rightAngle) * leafLen, fy + math.sin(rightAngle) * leafLen,
          fx + math.cos(rightAngle - 0.22) * leafLen * 0.58, fy + math.sin(rightAngle - 0.22) * leafLen * 0.58
        )

        -- Dynamic sun glow on leaflets
        if hasSun then
          -- How much this frond faces the sun (dot product of frond direction and sun direction)
          local frondDirX = math.cos(angle)
          local frondDirY = math.sin(angle)
          local sunFacing = frondDirX * sunDirX + frondDirY * sunDirY  -- -1 to 1

          -- Sun-facing fronds: warm glow highlights on the lit side
          if sunFacing > 0 then
            local glowIntensity = sunFacing * (0.15 + sunGlow * 0.35 + (1 - sunHeight) * 0.1)
            local glowAlpha = glowIntensity * (0.3 + t * 0.25)  -- stronger toward tips

            -- Warm sun glow on left leaflet
            if (i + j) % 2 == 0 then
              love.graphics.setColor(glowR, glowG, glowB, glowAlpha)
              love.graphics.circle("fill",
                fx + math.cos(leftAngle) * leafLen * 0.5,
                fy + math.sin(leftAngle) * leafLen * 0.5, 2.2)
            end
            -- Warm sun glow on right leaflet
            if (i + j) % 2 == 1 then
              love.graphics.setColor(glowR, glowG, glowB, glowAlpha * 0.85)
              love.graphics.circle("fill",
                fx + math.cos(rightAngle) * leafLen * 0.5,
                fy + math.sin(rightAngle) * leafLen * 0.5, 2.0)
            end

            -- Edge rim highlight on sun-facing leaflets (golden hour / sunset)
            if sunGlow > 0.15 and t > 0.3 and (i + j) % 3 == 0 then
              love.graphics.setColor(glowR, glowG * 0.9, glowB * 0.7, sunGlow * sunFacing * 0.4)
              love.graphics.setLineWidth(1)
              love.graphics.line(
                fx, fy,
                fx + math.cos(leftAngle) * leafLen * 0.9,
                fy + math.sin(leftAngle) * leafLen * 0.9
              )
            end
          end

          -- Backlit translucency: fronds facing AWAY from sun glow from behind
          if sunFacing < -0.2 and sunHeight < 0.7 then
            local backlitIntensity = (-sunFacing - 0.2) * (0.12 + sunGlow * 0.3)
            local backlitAlpha = backlitIntensity * (0.15 + t * 0.2)
            -- Warm translucent glow (light passing through leaves)
            love.graphics.setColor(glowR * 0.8, glowG * 0.9 + 0.1, glowB * 0.5 + 0.15, backlitAlpha)
            love.graphics.circle("fill",
              fx + math.cos(leftAngle) * leafLen * 0.4,
              fy + math.sin(leftAngle) * leafLen * 0.4, 2.5)
            love.graphics.circle("fill",
              fx + math.cos(rightAngle) * leafLen * 0.4,
              fy + math.sin(rightAngle) * leafLen * 0.4, 2.5)
          end
        else
          -- Night / no sun: subtle ambient dappling only
          if (i + j) % 5 == 0 then
            love.graphics.setColor(0.3, 0.45, 0.3, 0.08)
            love.graphics.circle("fill",
              fx + math.cos(leftAngle) * leafLen * 0.5,
              fy + math.sin(leftAngle) * leafLen * 0.5, 1.5)
          end
        end
      end

      lastX, lastY = fx, fy
    end
  end
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
        local waveOffset = math.sin(x / wave.wavelength + time * 0.75) * wave.amplitude
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
          local foamY = waveY + math.sin(x / wave.wavelength + time * 0.75) * wave.amplitude
          love.graphics.circle("fill", x, foamY - 2, 3 + math.random() * 2)
        end
      end
    end
  end

  -- Beach water edge with gradient
  local waterY = 1050 + tideOffset
  -- Multi-layer water for depth
  love.graphics.setColor(0.18, 0.45, 0.65, 0.6)
  love.graphics.rectangle("fill", 0, waterY, 1000, 80)
  love.graphics.setColor(0.22, 0.52, 0.72, 0.5)
  love.graphics.rectangle("fill", 0, waterY + 80, 1000, 120)
  
  -- Water sparkles (sun reflecting off water)
  for i = 1, 30 do
    local sparkleX = (i * 73 + time * 5) % 1000
    local sparkleY = waterY + (i * 47) % 150
    local sparklePhase = math.sin(time * 0.75 + i * 2)
    if sparklePhase > 0.5 then
      local brightness = (sparklePhase - 0.5) * 2
      love.graphics.setColor(1, 1, 0.95, 0.6 * brightness)
      love.graphics.circle("fill", sparkleX, sparkleY, 2 + brightness * 2)
      love.graphics.setColor(0.9, 0.95, 1, 0.3 * brightness)
      love.graphics.circle("fill", sparkleX, sparkleY, 4 + brightness * 3)
    end
  end

  -- Foam line at water edge with variation
  love.graphics.setColor(1, 1, 1, 0.4)
  for x = 0, 1000, 5 do
    local foamOffset = math.sin(x * 0.1 + time * 0.5) * 3
    local bubbleSize = 1.5 + math.sin(x * 0.2 + time * 0.25) * 0.5
    love.graphics.circle("fill", x, waterY + foamOffset, bubbleSize)
  end
  
  -- Additional foam patches
  love.graphics.setColor(1, 1, 1, 0.25)
  for x = 0, 1000, 30 do
    local patchY = waterY + math.sin(x * 0.05 + time * 0.25) * 8 + 10
    love.graphics.circle("fill", x, patchY, 4 + math.random() * 3)
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
