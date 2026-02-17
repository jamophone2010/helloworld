-- elendil/environment.lua
-- HD-2D environmental effects for Elendil — Zanaris blue palette
-- Cool blue-teal tones, neon bioluminescence, data-stream particles,
-- signal-mist fog, cyan water reflections, glowing flora

local M = {}
local lighting = require("elendil.lighting")

-- Wind state
local wind = {
  baseStrength = 0.4,
  currentStrength = 0.4,
  targetStrength = 0.4,
  gustTimer = 0,
  direction = 1
}

-- Cloud state
local clouds = {}
local cloudsSeed = 0

-- River state
local river = {
  flowSpeed = 30,
  ripples = {},
  reflectionOffset = 0
}

-- Fireflies (night particles)
local fireflies = {}

-- Pollen / dust motes (day particles)
local dustMotes = {}

-- Fog layers (morning mist)
local fogLayers = {}

-- Initialize environment
function M.init()
  M.regenerateClouds()
  M.regenerateRiver()
  M.regenerateFireflies(40)
  M.regenerateDustMotes(60)
  M.regenerateFog()
  M.initWaterfalls()
end

-- ═══════════════════════════════════════
-- CLOUD SYSTEM
-- ═══════════════════════════════════════

function M.regenerateClouds()
  local day = lighting.getDayNumber()
  if cloudsSeed == day then return end
  cloudsSeed = day

  clouds = {}
  math.randomseed(day * 54321)

  local numClouds = 6 + math.random(0, 5)
  for i = 1, numClouds do
    local cloud = {
      x = math.random(-200, 1800),
      y = math.random(15, 120),
      width = math.random(60, 180),
      height = math.random(20, 50),
      speed = 3 + math.random() * 8,
      puffs = {},
      opacity = 0.5 + math.random() * 0.3
    }

    local numPuffs = 3 + math.random(0, 3)
    for j = 1, numPuffs do
      table.insert(cloud.puffs, {
        offsetX = (j - 1) * (cloud.width / numPuffs) - cloud.width / 2 + math.random(-8, 8),
        offsetY = math.random(-8, 8),
        radius = cloud.height / 2 + math.random(-8, 12)
      })
    end

    table.insert(clouds, cloud)
  end

  math.randomseed(os.time())
end

-- ═══════════════════════════════════════
-- RIVER SYSTEM (with reflections)
-- ═══════════════════════════════════════

function M.regenerateRiver()
  river.ripples = {}
  for i = 1, 30 do
    table.insert(river.ripples, {
      x = math.random(0, 48 * 32),
      y = math.random(32 * 32, 37 * 32),
      radius = 3 + math.random() * 8,
      phase = math.random() * math.pi * 2,
      speed = 0.5 + math.random() * 1.5,
      life = math.random() * 10
    })
  end
end

-- ═══════════════════════════════════════
-- FIREFLY SYSTEM (night ambiance)
-- ═══════════════════════════════════════

function M.regenerateFireflies(count)
  fireflies = {}
  for i = 1, count do
    table.insert(fireflies, {
      x = math.random(0, 48 * 32),
      y = math.random(0, 30 * 32),
      baseX = 0, baseY = 0,
      size = 1.5 + math.random() * 2,
      phase = math.random() * math.pi * 2,
      glowPhase = math.random() * math.pi * 2,
      speed = 8 + math.random() * 15,
      driftAngle = math.random() * math.pi * 2,
      brightness = 0
    })
    fireflies[i].baseX = fireflies[i].x
    fireflies[i].baseY = fireflies[i].y
  end
end

-- ═══════════════════════════════════════
-- DUST MOTE / POLLEN SYSTEM (day ambiance)
-- ═══════════════════════════════════════

function M.regenerateDustMotes(count)
  dustMotes = {}
  for i = 1, count do
    table.insert(dustMotes, {
      x = math.random(0, 48 * 32),
      y = math.random(0, 32 * 32),
      size = 0.8 + math.random() * 1.5,
      speedX = 2 + math.random() * 5,
      speedY = -1 + math.random() * 2,
      phase = math.random() * math.pi * 2,
      brightness = 0.3 + math.random() * 0.5
    })
  end
end

-- ═══════════════════════════════════════
-- FOG SYSTEM (morning mist, HD-2D atmosphere)
-- ═══════════════════════════════════════

function M.regenerateFog()
  fogLayers = {}
  for i = 1, 5 do
    table.insert(fogLayers, {
      y = 200 + i * 150,
      density = 0.08 + math.random() * 0.06,
      speed = 5 + math.random() * 10,
      offset = math.random() * 500,
      height = 60 + math.random() * 40
    })
  end
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  M.updateWind(dt)
  M.updateClouds(dt)
  M.updateRiver(dt)
  M.updateFireflies(dt)
  M.updateDustMotes(dt)
end

function M.updateWind(dt)
  local hour = lighting.getHour()
  if hour >= 10 and hour <= 16 then
    wind.baseStrength = 0.5 + math.sin(hour * 0.5) * 0.15
  else
    wind.baseStrength = 0.25 + math.sin(hour * 0.3) * 0.1
  end

  wind.gustTimer = wind.gustTimer - dt
  if wind.gustTimer <= 0 then
    wind.targetStrength = wind.baseStrength + math.random() * 0.15
    wind.gustTimer = 6 + math.random() * 10
  end

  wind.currentStrength = wind.currentStrength + (wind.targetStrength - wind.currentStrength) * 0.3 * dt
end

function M.updateClouds(dt)
  for _, cloud in ipairs(clouds) do
    cloud.x = cloud.x + cloud.speed * wind.currentStrength * dt
    if cloud.x > 1800 then
      cloud.x = -cloud.width
    end
  end
end

function M.updateRiver(dt)
  river.reflectionOffset = river.reflectionOffset + dt * 0.5

  for _, ripple in ipairs(river.ripples) do
    ripple.phase = ripple.phase + ripple.speed * dt
    ripple.life = ripple.life + dt
    -- Slowly move ripples downstream
    ripple.x = ripple.x + river.flowSpeed * dt
    if ripple.x > 48 * 32 then
      ripple.x = 0
      ripple.phase = 0
    end
  end
end

function M.updateFireflies(dt)
  local isNight = lighting.isNight()
  for _, fly in ipairs(fireflies) do
    fly.phase = fly.phase + dt
    fly.glowPhase = fly.glowPhase + dt * (1.5 + math.sin(fly.phase * 0.3) * 0.5)

    -- Drift gently
    fly.driftAngle = fly.driftAngle + (math.random() - 0.5) * dt * 2
    fly.x = fly.baseX + math.sin(fly.phase * 0.3) * 30 + math.cos(fly.driftAngle) * fly.speed * dt
    fly.y = fly.baseY + math.cos(fly.phase * 0.4) * 20 + math.sin(fly.driftAngle) * fly.speed * dt * 0.5
    fly.baseX = fly.baseX + math.cos(fly.driftAngle) * fly.speed * dt * 0.1
    fly.baseY = fly.baseY + math.sin(fly.driftAngle) * fly.speed * dt * 0.05

    -- Wrap around
    if fly.baseX < -50 then fly.baseX = 48 * 32 + 50 end
    if fly.baseX > 48 * 32 + 50 then fly.baseX = -50 end
    if fly.baseY < -50 then fly.baseY = 30 * 32 end
    if fly.baseY > 30 * 32 then fly.baseY = -50 end

    -- Glow pulse (only at night, slow bioluminescent pulse)
    if isNight then
      fly.brightness = math.max(0, math.sin(fly.glowPhase) * 0.7 + 0.3)
    else
      fly.brightness = fly.brightness * 0.95  -- Fade out during day
    end
  end
end

function M.updateDustMotes(dt)
  for _, mote in ipairs(dustMotes) do
    mote.phase = mote.phase + dt
    mote.x = mote.x + (mote.speedX + wind.currentStrength * 8) * dt
    mote.y = mote.y + mote.speedY * dt + math.sin(mote.phase * 1.5) * 0.3

    -- Wrap
    if mote.x > 48 * 32 then mote.x = 0 end
    if mote.y < 0 then mote.y = 30 * 32 end
    if mote.y > 30 * 32 then mote.y = 0 end
  end
end

-- ═══════════════════════════════════════
-- GETTERS
-- ═══════════════════════════════════════

function M.getWindStrength()
  return wind.currentStrength
end

function M.getWindSway(x, time, amplitude)
  amplitude = amplitude or 1
  local positionPhase = x * 0.023
  local phase = positionPhase + time * 0.6 * wind.currentStrength
  local sway = math.sin(phase) * wind.currentStrength * amplitude
  sway = sway + math.sin(phase * 0.7 + positionPhase * 2) * wind.currentStrength * amplitude * 0.25
  return sway
end

-- ═══════════════════════════════════════
-- DRAW: SKY & HORIZON
-- ═══════════════════════════════════════

function M.drawSky(screenW, screenH)
  local horizonColor, zenithColor = lighting.getSkyColors()
  local sunsetGlow = lighting.getSunsetGlow()

  -- HD-2D painterly gradient sky (more segments for smoother look)
  local segments = 30
  for i = 0, segments - 1 do
    local t1 = i / segments
    local t2 = (i + 1) / segments
    local y1 = t1 * screenH * 0.45
    local y2 = t2 * screenH * 0.45

    local r = zenithColor[1] + (horizonColor[1] - zenithColor[1]) * (t1 * t1)
    local g = zenithColor[2] + (horizonColor[2] - zenithColor[2]) * (t1 * t1)
    local b = zenithColor[3] + (horizonColor[3] - zenithColor[3]) * (t1 * t1)

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", 0, y1, screenW, y2 - y1 + 1)
  end

  -- Sunset/sunrise glow band at horizon
  if sunsetGlow > 0 then
    love.graphics.setColor(1.0, 0.55, 0.25, sunsetGlow * 0.3)
    love.graphics.rectangle("fill", 0, screenH * 0.35, screenW, screenH * 0.15)
    love.graphics.setColor(1.0, 0.40, 0.20, sunsetGlow * 0.15)
    love.graphics.rectangle("fill", 0, screenH * 0.25, screenW, screenH * 0.15)
  end
end

function M.drawValleyCliffs(screenW, screenH, cameraY)
  local _, ambientIntensity = lighting.getAmbientLight()
  local worldHorizonY = -300
  local screenHorizonY = worldHorizonY - cameraY + screenH / 2

  -- Far valley wall (left side — towering cliffs with cascading greenery)
  local cliffColors = {
    {0.12, 0.18, 0.32},  -- Dark blue stone
    {0.16, 0.22, 0.38},  -- Lighter blue stone
    {0.08, 0.12, 0.25},  -- Deep indigo crevice
  }

  -- Left cliff face
  local leftCliffX = -20
  local cliffW = screenW * 0.18
  love.graphics.setColor(cliffColors[1][1] * ambientIntensity, cliffColors[1][2] * ambientIntensity, cliffColors[1][3] * ambientIntensity)
  love.graphics.polygon("fill",
    leftCliffX, screenHorizonY - 120,
    leftCliffX + cliffW, screenHorizonY + 20,
    leftCliffX + cliffW * 0.7, screenHorizonY + 80,
    leftCliffX, screenHorizonY + 80
  )
  -- Cliff texture (vertical striations)
  for i = 0, 6 do
    local cx = leftCliffX + i * cliffW / 7
    local shade = 0.85 + math.sin(i * 3.7) * 0.15
    love.graphics.setColor(cliffColors[2][1] * ambientIntensity * shade, cliffColors[2][2] * ambientIntensity * shade, cliffColors[2][3] * ambientIntensity * shade, 0.4)
    love.graphics.line(cx, screenHorizonY - 100 + i * 8, cx + 5, screenHorizonY + 60)
  end
  -- Neon data-vines on left cliff
  for i = 0, 4 do
    local vx = leftCliffX + 10 + i * cliffW / 5
    local vy = screenHorizonY - 80 + i * 12
    love.graphics.setColor(0.10 * ambientIntensity, 0.55 * ambientIntensity, 0.70 * ambientIntensity, 0.6)
    love.graphics.line(vx, vy, vx + math.sin(i * 2.3) * 6, vy + 25 + math.sin(i * 1.7) * 8)
    love.graphics.circle("fill", vx + math.sin(i * 2.3) * 6, vy + 25 + math.sin(i * 1.7) * 8, 4)
  end

  -- Right cliff face
  local rightCliffX = screenW - screenW * 0.15
  love.graphics.setColor(cliffColors[1][1] * ambientIntensity, cliffColors[1][2] * ambientIntensity, cliffColors[1][3] * ambientIntensity)
  love.graphics.polygon("fill",
    rightCliffX, screenHorizonY + 20,
    screenW + 20, screenHorizonY - 100,
    screenW + 20, screenHorizonY + 80,
    rightCliffX + cliffW * 0.3, screenHorizonY + 80
  )
  -- Right cliff texture
  for i = 0, 5 do
    local cx = rightCliffX + 10 + i * (screenW * 0.15) / 6
    local shade = 0.85 + math.sin(i * 4.1) * 0.15
    love.graphics.setColor(cliffColors[2][1] * ambientIntensity * shade, cliffColors[2][2] * ambientIntensity * shade, cliffColors[2][3] * ambientIntensity * shade, 0.4)
    love.graphics.line(cx, screenHorizonY - 80 + i * 6, cx - 3, screenHorizonY + 60)
  end
  -- Neon data-vines on right cliff
  for i = 0, 3 do
    local vx = rightCliffX + 15 + i * 25
    local vy = screenHorizonY - 60 + i * 10
    love.graphics.setColor(0.10 * ambientIntensity, 0.55 * ambientIntensity, 0.70 * ambientIntensity, 0.6)
    love.graphics.line(vx, vy, vx - math.sin(i * 1.9) * 5, vy + 20 + math.sin(i * 2.1) * 6)
    love.graphics.circle("fill", vx - math.sin(i * 1.9) * 5, vy + 20 + math.sin(i * 2.1) * 6, 3.5)
  end

  -- Distant tree canopy between cliffs (far background foliage)
  for i = 0, 12 do
    local tx = screenW * 0.15 + i * (screenW * 0.7) / 12
    local ty = screenHorizonY + 10 + math.sin(i * 2.1) * 15
    local tr = 18 + math.sin(i * 3.7) * 8
    local treeShade = ambientIntensity * (0.8 + math.sin(i * 1.3) * 0.2)
    if i % 3 == 0 then
      love.graphics.setColor(0.12 * treeShade, 0.35 * treeShade, 0.55 * treeShade, 0.5)
    elseif i % 3 == 1 then
      love.graphics.setColor(0.08 * treeShade, 0.30 * treeShade, 0.48 * treeShade, 0.5)
    else
      love.graphics.setColor(0.15 * treeShade, 0.25 * treeShade, 0.50 * treeShade, 0.5)
    end
    love.graphics.ellipse("fill", tx, ty, tr, tr * 0.7)
  end
end

-- ═══════════════════════════════════════
-- WATERFALL SYSTEM (Rivendell cascading falls)
-- ═══════════════════════════════════════

local waterfalls = {}

function M.initWaterfalls()
  waterfalls = {
    {x = 0.12, startY = -80, height = 160, width = 18, mist = {}, splashParticles = {}, flowSpeed = 120},
    {x = 0.88, startY = -60, height = 140, width = 12, mist = {}, splashParticles = {}, flowSpeed = 100}
  }
  for _, wf in ipairs(waterfalls) do
    for i = 1, 15 do
      table.insert(wf.mist, {
        ox = (math.random() - 0.5) * 40,
        oy = math.random() * 30,
        size = 8 + math.random() * 15,
        phase = math.random() * math.pi * 2,
        speed = 0.5 + math.random() * 1.0,
        alpha = 0.1 + math.random() * 0.15
      })
    end
    for i = 1, 8 do
      table.insert(wf.splashParticles, {
        ox = (math.random() - 0.5) * 30,
        vy = -20 - math.random() * 30,
        vx = (math.random() - 0.5) * 30,
        size = 1 + math.random() * 2,
        phase = math.random() * math.pi * 2,
        life = math.random()
      })
    end
  end
end

function M.drawWaterfalls(screenW, screenH, cameraY, time)
  local _, ambientIntensity = lighting.getAmbientLight()
  local worldHorizonY = -300
  local screenHorizonY = worldHorizonY - cameraY + screenH / 2

  for _, wf in ipairs(waterfalls) do
    local wx = wf.x * screenW
    local wy = screenHorizonY + wf.startY
    local wh = wf.height
    local ww = wf.width

    -- Main water column (animated vertical flow)
    for i = 0, 20 do
      local t = i / 20
      local flowY = wy + t * wh
      local columnWidth = ww * (0.7 + t * 0.3)
      local alpha = (0.4 + math.sin(time * 2 + t * 8) * 0.1) * ambientIntensity

      love.graphics.setColor(0.75, 0.85, 0.95, alpha)
      love.graphics.rectangle("fill", wx - columnWidth/2, flowY, columnWidth, wh / 20 + 2)

      local streakX = wx + math.sin(time * 3 + i * 1.7) * columnWidth * 0.3
      love.graphics.setColor(0.90, 0.95, 1.0, alpha * 0.6)
      love.graphics.rectangle("fill", streakX - 1, flowY, 2, wh / 15)
    end

    -- Foam at the base
    local baseY = wy + wh
    love.graphics.setColor(0.85, 0.92, 0.98, 0.5 * ambientIntensity)
    love.graphics.ellipse("fill", wx, baseY, ww * 1.5, 8)
    love.graphics.setColor(0.90, 0.95, 1.0, 0.3 * ambientIntensity)
    love.graphics.ellipse("fill", wx, baseY, ww * 2, 12)

    -- Rising mist spray
    for _, m in ipairs(wf.mist) do
      local mx = wx + m.ox + math.sin(time * m.speed + m.phase) * 8
      local my = baseY + m.oy - math.sin(time * m.speed * 0.7 + m.phase) * 10
      love.graphics.setColor(0.80, 0.85, 0.92, m.alpha * ambientIntensity)
      love.graphics.circle("fill", mx, my, m.size)
    end

    -- Splash droplets
    for _, sp in ipairs(wf.splashParticles) do
      local life = (time * 0.8 + sp.phase) % 1
      local spx = wx + sp.ox + sp.vx * life * 0.5
      local spy = baseY + sp.vy * life + 40 * life * life
      local spAlpha = (1 - life) * 0.5 * ambientIntensity
      love.graphics.setColor(0.85, 0.92, 1.0, spAlpha)
      love.graphics.circle("fill", spx, spy, sp.size * (1 - life * 0.5))
    end

    -- Subtle rainbow in mist during daytime
    if not lighting.isNight() then
      local sunAngle = lighting.getSunAngle()
      if sunAngle and math.sin(sunAngle) > 0.3 then
        local rainbowAlpha = 0.06 * math.sin(sunAngle) * ambientIntensity
        local rbX = wx + 15
        local rbY = baseY - 10
        local colors = {
          {0.8, 0.2, 0.2}, {0.9, 0.6, 0.1}, {0.9, 0.9, 0.2},
          {0.2, 0.8, 0.3}, {0.2, 0.4, 0.9}, {0.5, 0.2, 0.8}
        }
        for ci, c in ipairs(colors) do
          love.graphics.setColor(c[1], c[2], c[3], rainbowAlpha)
          love.graphics.arc("line", rbX, rbY, 20 + ci * 3, -math.pi * 0.8, -math.pi * 0.2)
        end
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: CLOUDS (painterly, HD-2D style)
-- ═══════════════════════════════════════

function M.drawClouds(cameraX, cameraY, time)
  local sunsetGlow = lighting.getSunsetGlow()
  local _, ambientIntensity = lighting.getAmbientLight()

  for _, cloud in ipairs(clouds) do
    local parallaxX = cloud.x - cameraX * 0.08
    local parallaxY = cloud.y

    -- Cloud color: cool blue-white during day, teal at dusk, deep blue at night
    local r, g, b = 0.60 * ambientIntensity, 0.72 * ambientIntensity, 0.85 * ambientIntensity
    if sunsetGlow > 0 then
      r = (0.60 - sunsetGlow * 0.15) * ambientIntensity
      g = (0.72 - sunsetGlow * 0.10) * ambientIntensity
      b = (0.85 + sunsetGlow * 0.05) * ambientIntensity
    end

    love.graphics.setColor(r, g, b, cloud.opacity * ambientIntensity)

    for _, puff in ipairs(cloud.puffs) do
      love.graphics.ellipse("fill",
        parallaxX + puff.offsetX,
        parallaxY + puff.offsetY,
        puff.radius * 1.3,
        puff.radius * 0.7
      )
    end

    -- Cloud shadow on ground (subtle, during day only)
    if not lighting.isNight() then
      local shadowY = 600 + parallaxY * 2
      love.graphics.setColor(0, 0, 0, 0.04 * cloud.opacity)
      for _, puff in ipairs(cloud.puffs) do
        love.graphics.ellipse("fill",
          parallaxX + puff.offsetX + 40,
          shadowY,
          puff.radius * 1.5,
          puff.radius * 0.3
        )
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: RIVER (with HD-2D reflections)
-- ═══════════════════════════════════════

function M.drawRiver(gs, time, cameraX, cameraY)
  local _, ambientIntensity = lighting.getAmbientLight()
  local sunsetGlow = lighting.getSunsetGlow()

  -- River base color with depth gradient
  for y = 30, 37 do
    for x = 0, 47 do
      -- Skip bridge area
      if x < 20 or x > 26 then
        local depth = (y - 30) / 7
        local flowOffset = math.sin((x * 0.3 + time * 0.8)) * 0.03
        local r = (0.05 + depth * 0.03 + flowOffset) * ambientIntensity
        local g = (0.15 + depth * 0.08 + flowOffset) * ambientIntensity
        local b = (0.45 + depth * 0.05) * ambientIntensity

        -- Twilight neon reflection in water
        if sunsetGlow > 0 then
          r = r + sunsetGlow * 0.05
          g = g + sunsetGlow * 0.10
          b = b + sunsetGlow * 0.08
        end

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", x * gs, y * gs, gs, gs)
      end
    end
  end

  -- HD-2D water reflections (wobbly mirrored environment)
  M.drawWaterReflections(gs, time, ambientIntensity)

  -- Ripple patterns
  for _, ripple in ipairs(river.ripples) do
    local rx = ripple.x
    local ry = ripple.y
    local alpha = math.max(0, math.sin(ripple.phase) * 0.15)
    local size = ripple.radius + math.sin(ripple.phase * 0.5) * 2

    -- Bright ripple ring
    love.graphics.setColor(0.5, 0.7, 0.85, alpha * ambientIntensity)
    love.graphics.circle("line", rx, ry, size)

    -- Inner bright spot
    love.graphics.setColor(0.6, 0.8, 0.95, alpha * 0.5 * ambientIntensity)
    love.graphics.circle("fill", rx, ry, size * 0.3)
  end

  -- Surface sparkles (sunlight on water — key HD-2D effect)
  if not lighting.isNight() then
    local sunAngle = lighting.getSunAngle()
    local sparkleIntensity = sunAngle and math.sin(sunAngle) * 0.8 or 0
    for i = 1, 35 do
      local sx = (i * 67 + time * 25) % (48 * gs)
      local sy = 30 * gs + (i * 41) % (7 * gs)
      -- Skip bridge area
      if sx < 20 * gs or sx > 26 * gs then
        local sparklePhase = math.sin(time * 3 + i * 2.3)
        if sparklePhase > 0.5 then
          local brightness = (sparklePhase - 0.5) * 2 * sparkleIntensity
          -- Cool cyan sparkle
          love.graphics.setColor(0.50, 0.85, 1.0, 0.5 * brightness * ambientIntensity)
          love.graphics.circle("fill", sx, sy, 2 + brightness * 2)
          -- Neon glow halo
          love.graphics.setColor(0.30, 0.75, 0.95, 0.2 * brightness * ambientIntensity)
          love.graphics.circle("fill", sx, sy, 4 + brightness * 3)
        end
      end
    end
  end
end

-- HD-2D style water reflections
function M.drawWaterReflections(gs, time, ambientIntensity)
  -- Simulate reflected light from sky on water surface
  local horizonColor, _ = lighting.getSkyColors()
  local reflectionAlpha = 0.12 * ambientIntensity

  for x = 0, 47 do
    if x < 20 or x > 26 then  -- Skip bridge
      -- Wobbling reflection columns
      local wobble = math.sin(x * 0.4 + time * 1.2) * 3
      local reflY = 30 * gs + wobble

      love.graphics.setColor(horizonColor[1], horizonColor[2], horizonColor[3], reflectionAlpha)
      love.graphics.rectangle("fill", x * gs, reflY, gs, gs * 0.5)
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: FOG (morning mist, HD-2D atmosphere)
-- ═══════════════════════════════════════

function M.drawFog(cameraX, cameraY, time, screenW, screenH)
  local hour = lighting.getHour()

  -- Fog is thickest at dawn, dissipates by midday
  local fogDensity = 0
  if hour >= 4 and hour <= 10 then
    local peak = 6.5
    fogDensity = math.max(0, 1 - math.abs(hour - peak) / 3.5)
  end
  -- Light evening mist
  if hour >= 18 and hour <= 21 then
    fogDensity = math.max(fogDensity, (hour - 18) / 3 * 0.4)
  end

  if fogDensity <= 0.01 then return end

  for _, layer in ipairs(fogLayers) do
    local fogY = layer.y - cameraY * 0.3
    local fogX = layer.offset + time * layer.speed * wind.currentStrength

    -- Undulating data-mist band
    love.graphics.setColor(0.30, 0.45, 0.70, layer.density * fogDensity)
    for x = -100, screenW + 100, 30 do
      local waveY = fogY + math.sin((x + fogX) * 0.008) * layer.height * 0.3
                         + math.sin((x + fogX) * 0.015) * layer.height * 0.15
      love.graphics.ellipse("fill", x, waveY, 50, layer.height * 0.6)
    end
  end

  -- Low ground fog near river
  if fogDensity > 0.3 then
    local riverFogY = 28 * 32 - cameraY + screenH / 2
    love.graphics.setColor(0.20, 0.40, 0.65, fogDensity * 0.15)
    love.graphics.rectangle("fill", 0, riverFogY - 30, screenW, 80)
  end
end

-- ═══════════════════════════════════════
-- DRAW: FIREFLIES (night particles)
-- ═══════════════════════════════════════

function M.drawFireflies(cameraX, cameraY, screenW, screenH)
  if not lighting.isNight() then return end

  for _, fly in ipairs(fireflies) do
    if fly.brightness > 0.05 then
      local sx = fly.x - cameraX + screenW / 2
      local sy = fly.y - cameraY + screenH / 2

      -- Only draw on-screen
      if sx > -20 and sx < screenW + 20 and sy > -20 and sy < screenH + 20 then
        -- Outer glow (neon cyan)
        love.graphics.setColor(0.15, 0.70, 0.95, fly.brightness * 0.15)
        love.graphics.circle("fill", sx, sy, fly.size * 6)

        -- Middle glow
        love.graphics.setColor(0.20, 0.80, 1.0, fly.brightness * 0.35)
        love.graphics.circle("fill", sx, sy, fly.size * 3)

        -- Bright core
        love.graphics.setColor(0.40, 0.95, 1.0, fly.brightness * 0.8)
        love.graphics.circle("fill", sx, sy, fly.size)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: DUST MOTES / POLLEN (day particles)
-- ═══════════════════════════════════════

function M.drawDustMotes(cameraX, cameraY, screenW, screenH)
  if lighting.isNight() then return end

  local _, ambientIntensity = lighting.getAmbientLight()
  local sunAngle = lighting.getSunAngle()
  local sunHeight = sunAngle and math.sin(sunAngle) or 0.5

  for _, mote in ipairs(dustMotes) do
    local sx = mote.x - cameraX + screenW / 2
    local sy = mote.y - cameraY + screenH / 2

    if sx > -10 and sx < screenW + 10 and sy > -10 and sy < screenH + 10 then
      -- Motes catch sunlight — brighter when sun is low (more dramatic)
      local catchLight = mote.brightness * (0.5 + (1 - sunHeight) * 0.5) * ambientIntensity
      local wobble = math.sin(mote.phase * 2) * 0.5

      -- Cool neon data-mote
      love.graphics.setColor(0.40, 0.75, 0.95, catchLight * 0.5)
      love.graphics.circle("fill", sx + wobble, sy, mote.size + 1)

      -- Bright cyan center
      love.graphics.setColor(0.50, 0.90, 1.0, catchLight * 0.8)
      love.graphics.circle("fill", sx + wobble, sy, mote.size * 0.5)
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: STARS (night sky)
-- ═══════════════════════════════════════

function M.drawStars(screenW, screenH, time)
  if not lighting.isNight() then return end

  local hour = lighting.getHour()
  local starAlpha = 1
  if hour > 4.5 and hour < 6 then
    starAlpha = (6 - hour) / 1.5
  elseif hour > 19 and hour < 20.5 then
    starAlpha = (hour - 19) / 1.5
  end

  local areas = require("elendil.areas")
  for _, star in ipairs(areas.getStars()) do
    local twinkle = 0.5 + math.sin(time * 1.5 + star.twinklePhase) * 0.5
    local brightness = star.brightness * twinkle * starAlpha

    -- Star point
    love.graphics.setColor(0.9, 0.92, 1.0, brightness * 0.9)
    love.graphics.circle("fill", star.x, star.y, star.size)

    -- Star glow
    if brightness > 0.5 then
      love.graphics.setColor(0.8, 0.85, 1.0, (brightness - 0.5) * 0.3)
      love.graphics.circle("fill", star.x, star.y, star.size * 3)
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: TREES (HD-2D style — rich, layered)
-- ═══════════════════════════════════════

function M.drawOakTree(x, y, gs, time, variety)
  variety = variety or 1
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local treeSeed = x * 7 + y * 13
  local _, ambientIntensity = lighting.getAmbientLight()

  -- Trunk (pale silver-gray bark — beech/mallorn style)
  local trunkSway = M.getWindSway(x * gs, time, 1.5)
  local trunkHeight = variety == 1 and gs * 2.8 or gs * 2.4
  local trunkWidth = variety == 1 and 10 or 8

  local segments = 12
  for i = 0, segments - 1 do
    local t = i / segments
    local width = trunkWidth * (1 - t * 0.4)
    local segSway = trunkSway * t * t * 0.5

    local y1 = baseY - t * trunkHeight
    local y2 = baseY - (t + 1/segments) * trunkHeight
    local x1 = baseX + segSway * t
    local x2 = baseX + segSway * (t + 1/segments)

    -- Dark blue-gray bark (signal-tree)
    local barkShade = 0.9 - t * 0.1 + math.sin(treeSeed + i * 2) * 0.05
    love.graphics.setColor(0.18 * barkShade * ambientIntensity, 0.22 * barkShade * ambientIntensity, 0.38 * barkShade * ambientIntensity)
    love.graphics.polygon("fill",
      x1 - width/2, y1,
      x1 + width/2, y1,
      x2 + width/2 - 0.3, y2,
      x2 - width/2 + 0.3, y2
    )

    -- Bark texture (smoother than oak)
    if t < 0.7 then
      love.graphics.setColor(0.14 * barkShade * ambientIntensity, 0.18 * barkShade * ambientIntensity, 0.32 * barkShade * ambientIntensity)
      love.graphics.setLineWidth(1)
      love.graphics.line(x1 - width/3, y1, x2 - width/3, y2)
    end
  end

  -- Crown (blue-teal bioluminescent foliage — Zanaris style)
  local topX = baseX + trunkSway * 0.5
  local topY = baseY - trunkHeight

  local crownRadius = variety == 1 and 28 or 22
  local leafClusters = {
    {ox = -8, oy = -5, r = crownRadius * 0.7, shade = 0.85},
    {ox = 10, oy = -8, r = crownRadius * 0.65, shade = 0.90},
    {ox = 0, oy = -15, r = crownRadius * 0.8, shade = 0.95},
    {ox = -12, oy = -12, r = crownRadius * 0.6, shade = 0.80},
    {ox = 8, oy = -3, r = crownRadius * 0.55, shade = 0.88},
    {ox = 0, oy = -8, r = crownRadius, shade = 1.0}
  }

  local sunAngle = lighting.getSunAngle()
  local sunDirX = sunAngle and -math.cos(sunAngle) or 0
  local sunsetGlow = lighting.getSunsetGlow()

  for ci, cluster in ipairs(leafClusters) do
    local cx = topX + cluster.ox + M.getWindSway(x * gs + cluster.ox * 10, time, 2) * 0.5
    local cy = topY + cluster.oy

    local gs1 = cluster.shade * ambientIntensity

    -- Bioluminescent color variation (teal, cyan, deep blue mix)
    local colorChoice = (treeSeed + ci) % 3
    if colorChoice == 0 then
      -- Neon teal
      love.graphics.setColor(0.10 * gs1, 0.50 * gs1, 0.60 * gs1)
    elseif colorChoice == 1 then
      -- Deep cyan-blue
      love.graphics.setColor(0.12 * gs1, 0.35 * gs1, 0.58 * gs1)
    else
      -- Dark indigo
      love.graphics.setColor(0.15 * gs1, 0.22 * gs1, 0.50 * gs1)
    end
    love.graphics.ellipse("fill", cx, cy, cluster.r, cluster.r * 0.75)

    -- Lighter highlight on sun-facing side
    if sunAngle then
      local highlightX = cx + sunDirX * cluster.r * 0.3
      if colorChoice == 0 then
        love.graphics.setColor(0.20 * gs1, 0.65 * gs1, 0.75 * gs1, 0.6)
      elseif colorChoice == 1 then
        love.graphics.setColor(0.25 * gs1, 0.50 * gs1, 0.72 * gs1, 0.6)
      else
        love.graphics.setColor(0.22 * gs1, 0.35 * gs1, 0.62 * gs1, 0.6)
      end
      love.graphics.ellipse("fill", highlightX, cy - cluster.r * 0.15, cluster.r * 0.6, cluster.r * 0.5)

      if sunsetGlow > 0 then
        love.graphics.setColor(0.30, 0.65, 0.90, sunsetGlow * 0.15 * gs1)
        love.graphics.ellipse("fill", highlightX, cy - cluster.r * 0.1, cluster.r * 0.5, cluster.r * 0.4)
      end
    end
  end

  -- Leaf edge detail (autumnal hues)
  local numEdgeLeaves = 12
  for i = 1, numEdgeLeaves do
    local angle = (i / numEdgeLeaves) * math.pi * 2
    local edgeR = crownRadius * (0.85 + math.sin(treeSeed + i * 3) * 0.15)
    local leafX = topX + math.cos(angle) * edgeR + M.getWindSway(x * gs + i * 20, time, 1)
    local leafY = topY - 8 + math.sin(angle) * edgeR * 0.7
    local leafShade = (0.85 + math.sin(i * 2.1) * 0.15) * ambientIntensity

    local edgeColor = (treeSeed + i) % 3
    if edgeColor == 0 then
      love.graphics.setColor(0.15 * leafShade, 0.55 * leafShade, 0.68 * leafShade)
    elseif edgeColor == 1 then
      love.graphics.setColor(0.18 * leafShade, 0.40 * leafShade, 0.62 * leafShade)
    else
      love.graphics.setColor(0.20 * leafShade, 0.30 * leafShade, 0.55 * leafShade)
    end
    love.graphics.circle("fill", leafX, leafY, 4 + math.sin(treeSeed + i) * 2)
  end

  -- Falling leaves (gentle drift — signature Rivendell autumnal detail)
  for i = 1, 2 do
    local leafTime = time * 0.5 + treeSeed * 0.1 + i * 3.7
    local fallProgress = (leafTime % 4) / 4  -- 4 second fall cycle
    if fallProgress < 1 then
      local lfx = topX + math.sin(leafTime * 1.3) * crownRadius * 0.6
      local lfy = topY - 5 + fallProgress * (trunkHeight + 20)
      local lfAlpha = 1 - fallProgress * 0.8
      local lfColor = (treeSeed + i) % 2
      if lfColor == 0 then
        love.graphics.setColor(0.15 * ambientIntensity, 0.60 * ambientIntensity, 0.80 * ambientIntensity, lfAlpha * 0.6)
      else
        love.graphics.setColor(0.20 * ambientIntensity, 0.45 * ambientIntensity, 0.70 * ambientIntensity, lfAlpha * 0.6)
      end
      love.graphics.circle("fill", lfx + math.sin(leafTime * 2.5) * 8, lfy, 2)
    end
  end
end

function M.drawPineTree(x, y, gs, time, variety)
  variety = variety or 1
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local _, ambientIntensity = lighting.getAmbientLight()
  local treeSeed = x * 11 + y * 7

  -- Trunk (straight, silver-barked — cypress sentinel style)
  local trunkHeight = variety == 1 and gs * 3.0 or gs * 2.6
  local sway = M.getWindSway(x * gs, time, 1)

  love.graphics.setColor(0.15 * ambientIntensity, 0.20 * ambientIntensity, 0.35 * ambientIntensity)
  love.graphics.polygon("fill",
    baseX - 4, baseY,
    baseX + 4, baseY,
    baseX + 2 + sway * 0.3, baseY - trunkHeight,
    baseX - 2 + sway * 0.3, baseY - trunkHeight
  )

  -- Tiered branches (deep blue-teal — Zanaris antenna pine)
  local topX = baseX + sway * 0.3
  local topY = baseY - trunkHeight
  local tiers = variety == 1 and 5 or 4

  for i = 1, tiers do
    local t = i / tiers
    local tierY = topY + t * trunkHeight * 0.65
    local tierWidth = 8 + t * 18
    local tierSway = M.getWindSway(x * gs + i * 40, time, 1.5) * t

    -- Deep blue-teal base
    local shade = (0.85 + math.sin(treeSeed + i * 2) * 0.15) * ambientIntensity
    love.graphics.setColor(0.08 * shade, 0.22 * shade, 0.42 * shade)
    love.graphics.polygon("fill",
      topX + tierSway - tierWidth, tierY + 12,
      topX + tierSway + tierWidth, tierY + 12,
      topX + tierSway, tierY - 8
    )

    -- Highlight layer (cyan-blue)
    love.graphics.setColor(0.12 * shade, 0.35 * shade, 0.52 * shade, 0.7)
    love.graphics.polygon("fill",
      topX + tierSway - tierWidth * 0.7, tierY + 8,
      topX + tierSway + tierWidth * 0.6, tierY + 8,
      topX + tierSway + 2, tierY - 5
    )

    -- Neon signal shimmer at dawn (cyan highlights)
    local hour = lighting.getHour()
    if hour >= 4 and hour <= 8 then
      love.graphics.setColor(0.20, 0.70, 0.90, 0.10)
      love.graphics.polygon("fill",
        topX + tierSway - tierWidth * 0.3, tierY - 2,
        topX + tierSway + tierWidth * 0.3, tierY - 2,
        topX + tierSway, tierY - 8
      )
    end
  end
end

function M.drawWillowTree(x, y, gs, time, variety)
  variety = variety or 1
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs
  local _, ambientIntensity = lighting.getAmbientLight()
  local treeSeed = x * 5 + y * 17

  -- Trunk (dark blue-gray, graceful curve)
  local trunkHeight = gs * 2.2
  local sway = M.getWindSway(x * gs, time, 1.2)

  love.graphics.setColor(0.18 * ambientIntensity, 0.22 * ambientIntensity, 0.40 * ambientIntensity)
  love.graphics.polygon("fill",
    baseX - 6, baseY,
    baseX + 6, baseY,
    baseX + 3 + sway * 0.2, baseY - trunkHeight,
    baseX - 3 + sway * 0.2, baseY - trunkHeight
  )

  -- Crown origin
  local topX = baseX + sway * 0.2
  local topY = baseY - trunkHeight

  -- Drooping fronds (silver-green Elvish willow — ethereal drape)
  local numFronds = 10
  for i = 1, numFronds do
    local angle = (i / numFronds) * math.pi * 2
    local frondStartX = topX + math.cos(angle) * 12
    local frondStartY = topY + math.sin(angle) * 6

    local frondSway = M.getWindSway(x * gs + i * 30, time + i * 0.2, 3)
    local frondLength = 35 + math.sin(treeSeed + i * 2) * 10

    local prevX, prevY = frondStartX, frondStartY
    local segs = 6
    for j = 1, segs do
      local t = j / segs
      local fx = frondStartX + math.cos(angle) * t * 15 + frondSway * t
      local fy = frondStartY + t * t * frondLength

      local shade = (0.85 + t * 0.15) * ambientIntensity
      -- Neon cyan-blue coloring (Zanaris data-stream)
      love.graphics.setColor(0.12 * shade, 0.45 * shade, 0.65 * shade, 1 - t * 0.3)
      love.graphics.setLineWidth(3 - t * 2)
      love.graphics.line(prevX, prevY, fx, fy)

      if j >= 2 then
        love.graphics.setColor(0.15 * shade, 0.50 * shade, 0.70 * shade, 0.7)
        love.graphics.circle("fill", fx, fy, 3 - t * 1.5)
      end

      prevX, prevY = fx, fy
    end
  end
end

return M
