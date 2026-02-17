-- chillon/environment.lua
-- Dynamic environmental effects for Chillon (Montreux × Chamonix)
-- Alpine snowfall, wind systems, frozen lake, aurora borealis,
-- thermal spring steam, mountain range rendering, pine forests

local M = {}

-- Wind system
local windStrength = 0.6
local windTarget = 0.6
local windTimer = 0
local gustInterval = 3

-- Snow particles
local snowParticles = {}
local MAX_SNOW = 300
local blizzardIntensity = 0

-- Aurora borealis
local auroraWaves = {}
local auroraActive = false

-- Steam vents (hot springs)
local steamParticles = {}

function M.init()
  windStrength = 0.6
  windTarget = 0.6
  windTimer = 0

  -- Initialize snow
  snowParticles = {}
  for i = 1, MAX_SNOW do
    table.insert(snowParticles, {
      x = math.random(0, 2000),
      y = math.random(-200, 800),
      size = 1 + math.random() * 3,
      speed = 15 + math.random() * 30,
      drift = math.random() * math.pi * 2,
      driftSpeed = 0.5 + math.random() * 1.5,
      opacity = 0.3 + math.random() * 0.7,
      layer = math.random(1, 3)  -- parallax depth
    })
  end

  -- Initialize aurora waves
  auroraWaves = {}
  for i = 1, 5 do
    table.insert(auroraWaves, {
      yBase = 40 + i * 25,
      amplitude = 15 + math.random() * 20,
      frequency = 0.005 + math.random() * 0.008,
      speed = 0.3 + math.random() * 0.5,
      phase = math.random() * math.pi * 2,
      color = i <= 2 and "green" or (i <= 4 and "blue" or "purple"),
      width = 200 + math.random() * 300,
      xOffset = math.random() * 400
    })
  end

  -- Initialize steam
  steamParticles = {}
  for i = 1, 40 do
    table.insert(steamParticles, {
      x = 0, y = 0,
      size = 3 + math.random() * 5,
      speed = 8 + math.random() * 12,
      life = math.random(),
      maxLife = 2 + math.random() * 3,
      opacity = 0.2 + math.random() * 0.3,
      sourceIndex = math.ceil(math.random() * 2)
    })
  end
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  -- Wind gusts
  windTimer = windTimer + dt
  if windTimer >= gustInterval then
    windTimer = 0
    windTarget = 0.3 + math.random() * 0.9
    gustInterval = 2 + math.random() * 5
    -- Occasional blizzard surges
    if math.random() < 0.15 then
      windTarget = 1.2 + math.random() * 0.5
      blizzardIntensity = math.min(1, blizzardIntensity + 0.3)
    else
      blizzardIntensity = math.max(0, blizzardIntensity - dt * 0.2)
    end
  end
  windStrength = windStrength + (windTarget - windStrength) * dt * 1.5
  blizzardIntensity = math.max(0, blizzardIntensity - dt * 0.05)

  -- Update snow particles
  for _, p in ipairs(snowParticles) do
    local layerSpeed = p.layer == 1 and 0.6 or (p.layer == 2 and 1.0 or 1.4)
    p.y = p.y + p.speed * layerSpeed * dt
    p.drift = p.drift + p.driftSpeed * dt
    p.x = p.x + math.sin(p.drift) * 15 * dt + windStrength * 30 * dt * layerSpeed

    -- Reset when off screen
    if p.y > 900 then
      p.y = math.random(-50, -10)
      p.x = math.random(-200, 2000)
    end
    if p.x > 2200 then p.x = -100 end
    if p.x < -200 then p.x = 2000 end
  end

  -- Update steam
  for _, s in ipairs(steamParticles) do
    s.life = s.life + dt
    if s.life >= s.maxLife then
      s.life = 0
      s.x = 0
      s.y = 0
    end
  end
end

-- ═══════════════════════════════════════
-- GETTERS
-- ═══════════════════════════════════════

function M.getWindStrength()
  return windStrength
end

function M.getWindSway(x, time, scale)
  scale = scale or 1
  return math.sin(time * 1.5 + x * 0.01) * windStrength * 3 * scale
end

function M.getBlizzardIntensity()
  return blizzardIntensity
end

-- ═══════════════════════════════════════
-- DRAW: SKY (Arctic gradient with mountain silhouettes)
-- ═══════════════════════════════════════

function M.drawSky(screenW, screenH, skyColors)
  local horizon, zenith = skyColors[1], skyColors[2]
  if not horizon or not zenith then
    horizon = {0.45, 0.55, 0.65}
    zenith = {0.20, 0.30, 0.50}
  end

  -- Gradient sky
  local segments = 30
  for i = 0, segments - 1 do
    local t = i / segments
    local y = t * screenH * 0.6
    local h = screenH * 0.6 / segments + 1
    love.graphics.setColor(
      zenith[1] + (horizon[1] - zenith[1]) * t,
      zenith[2] + (horizon[2] - zenith[2]) * t,
      zenith[3] + (horizon[3] - zenith[3]) * t
    )
    love.graphics.rectangle("fill", 0, y, screenW, h)
  end

  -- Below horizon (mountain shadow)
  love.graphics.setColor(horizon[1] * 0.8, horizon[2] * 0.8, horizon[3] * 0.85)
  love.graphics.rectangle("fill", 0, screenH * 0.6, screenW, screenH * 0.4)
end

-- ═══════════════════════════════════════
-- DRAW: STARS (cold, bright arctic stars)
-- ═══════════════════════════════════════

function M.drawStars(screenW, screenH, time, isNight)
  if not isNight then return end

  local stars = require("chillon.areas").getStars()
  for _, star in ipairs(stars) do
    local twinkle = math.sin(time * 1.5 + star.twinklePhase) * 0.3 + 0.7
    local alpha = star.brightness * twinkle * 0.9
    -- Ice-cold white-blue stars
    love.graphics.setColor(0.85, 0.90, 1.0, alpha)
    love.graphics.circle("fill", star.x, star.y, star.size)
    -- Tiny glow halo
    love.graphics.setColor(0.80, 0.88, 1.0, alpha * 0.15)
    love.graphics.circle("fill", star.x, star.y, star.size * 3)
  end
end

-- ═══════════════════════════════════════
-- DRAW: AURORA BOREALIS (night only)
-- ═══════════════════════════════════════

function M.drawAurora(screenW, screenH, time, isNight)
  if not isNight then return end

  for _, wave in ipairs(auroraWaves) do
    local r, g, b
    if wave.color == "green" then
      r, g, b = 0.15, 0.85, 0.35
    elseif wave.color == "blue" then
      r, g, b = 0.20, 0.50, 0.90
    else  -- purple
      r, g, b = 0.55, 0.20, 0.80
    end

    -- Flowing curtain of light
    for i = 0, math.floor(wave.width), 3 do
      local x = wave.xOffset + i
      if x >= 0 and x <= screenW then
        local waveY = wave.yBase + math.sin(i * wave.frequency + time * wave.speed + wave.phase) * wave.amplitude
        local curtainH = 25 + math.sin(i * 0.02 + time * 0.3) * 15
        local alpha = (0.08 + math.sin(i * 0.01 + time * 0.7) * 0.04)
        -- Gradient curtain from bright top to fading bottom
        for cy = 0, math.floor(curtainH), 2 do
          local curtainAlpha = alpha * (1 - cy / curtainH) * 0.7
          love.graphics.setColor(r, g, b, curtainAlpha)
          love.graphics.rectangle("fill", x, waveY + cy, 3, 2)
        end
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: MOUNTAIN RANGE (background peaks)
-- ═══════════════════════════════════════

function M.drawMountainRange(screenW, screenH, cameraY, ambientIntensity)
  -- Far range (pale blue silhouette)
  local baseY = screenH * 0.35 - cameraY * 0.02

  -- Distant mountains (3 layers for depth)
  -- Layer 3: farthest, palest
  love.graphics.setColor(0.50 * ambientIntensity, 0.55 * ambientIntensity, 0.65 * ambientIntensity, 0.6)
  local peaks3 = {0, baseY + 40, 80, baseY - 30, 180, baseY - 60, 280, baseY - 20, 380, baseY - 75,
                  480, baseY - 40, 560, baseY - 90, 660, baseY - 25, 760, baseY - 55, screenW, baseY + 40,
                  screenW, screenH * 0.6, 0, screenH * 0.6}
  love.graphics.polygon("fill", unpack(peaks3))

  -- Snow caps on far range
  love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.4)
  local snowPeaks = {80, baseY - 30, 180, baseY - 60, 280, baseY - 20,
                     280, baseY - 15, 180, baseY - 50, 80, baseY - 22}
  love.graphics.polygon("fill", unpack(snowPeaks))
  local snowPeaks2 = {380, baseY - 75, 480, baseY - 40, 560, baseY - 90,
                      560, baseY - 80, 480, baseY - 30, 380, baseY - 65}
  love.graphics.polygon("fill", unpack(snowPeaks2))

  -- Layer 2: mid-range
  love.graphics.setColor(0.38 * ambientIntensity, 0.40 * ambientIntensity, 0.48 * ambientIntensity, 0.75)
  local peaks2 = {0, baseY + 60, 100, baseY + 10, 220, baseY - 30, 320, baseY + 20, 440, baseY - 45,
                  530, baseY, 650, baseY - 35, 750, baseY + 15, screenW, baseY + 50,
                  screenW, screenH * 0.6, 0, screenH * 0.6}
  love.graphics.polygon("fill", unpack(peaks2))

  -- Layer 1: nearest, darkest
  love.graphics.setColor(0.28 * ambientIntensity, 0.30 * ambientIntensity, 0.35 * ambientIntensity, 0.85)
  local peaks1 = {0, baseY + 80, 60, baseY + 50, 160, baseY + 20, 260, baseY + 55, 350, baseY + 15,
                  450, baseY + 45, 550, baseY + 10, 640, baseY + 60, 730, baseY + 25, screenW, baseY + 70,
                  screenW, screenH * 0.6, 0, screenH * 0.6}
  love.graphics.polygon("fill", unpack(peaks1))

  -- Snow on nearest peaks
  love.graphics.setColor(0.75 * ambientIntensity, 0.78 * ambientIntensity, 0.82 * ambientIntensity, 0.5)
  for i = 1, #peaks1 - 5, 2 do
    local px, py = peaks1[i], peaks1[i + 1]
    if py < baseY + 50 then
      love.graphics.circle("fill", px, py + 3, 12)
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: CLOUDS (heavy, grey arctic clouds)
-- ═══════════════════════════════════════

function M.drawClouds(cameraX, cameraY, time, ambientIntensity)
  local dayNum = require("chillon.lighting").getDayNumber()
  math.randomseed(dayNum * 137)

  local numClouds = 8
  for i = 1, numClouds do
    local cloudX = math.random(0, 900) + math.sin(time * 0.03 + i * 2.7) * 40
    local cloudY = 30 + math.random(0, 120)
    local cloudW = 80 + math.random(0, 120)

    -- Parallax
    cloudX = cloudX - cameraX * 0.03 * (1 + i * 0.1)

    -- Heavy grey-white clouds
    for puff = 1, 5 do
      local px = cloudX + (puff - 1) * cloudW / 5 + math.sin(puff * 1.9) * 15
      local py = cloudY + math.sin(puff * 2.7) * 8
      local pr = 18 + math.sin(puff * 3.1) * 10

      love.graphics.setColor(
        0.72 * ambientIntensity,
        0.74 * ambientIntensity,
        0.78 * ambientIntensity,
        0.55
      )
      love.graphics.circle("fill", px, py, pr)
      -- Lighter top edge
      love.graphics.setColor(
        0.80 * ambientIntensity,
        0.82 * ambientIntensity,
        0.86 * ambientIntensity,
        0.3
      )
      love.graphics.circle("fill", px, py - 5, pr * 0.7)
    end

    -- Cloud shadow on ground (subtle)
    love.graphics.setColor(0, 0, 0, 0.04)
    love.graphics.ellipse("fill", cloudX + cloudW / 2 - cameraX * 0.1,
      350 - cameraY * 0.05, cloudW * 0.7, 10)
  end

  math.randomseed(os.time())
end

-- ═══════════════════════════════════════
-- DRAW: FALLING SNOW
-- ═══════════════════════════════════════

function M.drawSnow(cameraX, cameraY, screenW, screenH)
  for _, p in ipairs(snowParticles) do
    local parallaxFactor = p.layer == 1 and 0.3 or (p.layer == 2 and 0.6 or 1.0)
    local drawX = p.x - cameraX * parallaxFactor
    local drawY = p.y - cameraY * parallaxFactor

    if drawX >= -10 and drawX <= screenW + 10 and drawY >= -10 and drawY <= screenH + 10 then
      local alpha = p.opacity * (p.layer == 1 and 0.3 or (p.layer == 2 and 0.6 or 0.9))
      local size = p.size * (p.layer == 1 and 0.5 or (p.layer == 2 and 0.8 or 1.0))

      -- Snowflake (bright white)
      love.graphics.setColor(0.95, 0.97, 1.0, alpha)
      love.graphics.circle("fill", drawX, drawY, size)

      -- Subtle glow on foreground flakes
      if p.layer == 3 and size > 2.5 then
        love.graphics.setColor(0.90, 0.95, 1.0, alpha * 0.15)
        love.graphics.circle("fill", drawX, drawY, size * 2)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: BLIZZARD OVERLAY
-- ═══════════════════════════════════════

function M.drawBlizzardOverlay(screenW, screenH, time)
  if blizzardIntensity <= 0.05 then return end

  -- White-out effect
  love.graphics.setColor(0.85, 0.88, 0.92, blizzardIntensity * 0.25)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Horizontal streaks of driven snow
  for i = 1, math.floor(blizzardIntensity * 20) do
    local streakY = (time * 80 * i + i * 137) % screenH
    local streakX = math.sin(time * 2 + i * 3.7) * 100
    love.graphics.setColor(0.92, 0.94, 0.98, blizzardIntensity * 0.15)
    love.graphics.line(streakX, streakY, streakX + 200 + windStrength * 100, streakY + 2)
  end
end

-- ═══════════════════════════════════════
-- DRAW: PINE TREE (snow-covered alpine pine)
-- ═══════════════════════════════════════

function M.drawPineTree(x, y, gs, time, variety, ambientIntensity)
  ambientIntensity = ambientIntensity or 0.9
  local sway = M.getWindSway(x * gs, time, 0.5)
  local px = x * gs + gs / 2
  local py = y * gs + gs

  -- Trunk (dark bark)
  love.graphics.setColor(0.30 * ambientIntensity, 0.22 * ambientIntensity, 0.15 * ambientIntensity)
  love.graphics.rectangle("fill", px - 3, py - 20, 6, 20)

  -- Multiple snow-laden branch tiers
  local tiers = variety == 1 and 5 or 4
  for tier = 0, tiers - 1 do
    local tierY = py - 25 - tier * 14 + sway * (tier * 0.15)
    local tierW = (tiers - tier) * 10 + 8

    -- Dark green needles
    love.graphics.setColor(
      (0.12 + tier * 0.02) * ambientIntensity,
      (0.28 + tier * 0.03) * ambientIntensity,
      (0.12 + tier * 0.01) * ambientIntensity
    )
    love.graphics.polygon("fill",
      px + sway * (tier * 0.1), tierY - 10,
      px - tierW + sway * (tier * 0.1), tierY + 6,
      px + tierW + sway * (tier * 0.1), tierY + 6
    )

    -- Snow on branches (white caps)
    love.graphics.setColor(0.88 * ambientIntensity, 0.90 * ambientIntensity, 0.95 * ambientIntensity, 0.85)
    love.graphics.polygon("fill",
      px + sway * (tier * 0.1), tierY - 10,
      px - tierW * 0.6 + sway * (tier * 0.1), tierY - 2,
      px + tierW * 0.6 + sway * (tier * 0.1), tierY - 2
    )

    -- Snow drip detail
    if tier < tiers - 1 then
      love.graphics.setColor(0.85 * ambientIntensity, 0.87 * ambientIntensity, 0.92 * ambientIntensity, 0.4)
      love.graphics.circle("fill", px - tierW * 0.3 + sway * (tier * 0.1), tierY + 7, 2)
      love.graphics.circle("fill", px + tierW * 0.3 + sway * (tier * 0.1), tierY + 7, 2)
    end
  end

  -- Treetop point
  local topY = py - 25 - tiers * 14
  love.graphics.setColor(0.14 * ambientIntensity, 0.30 * ambientIntensity, 0.14 * ambientIntensity)
  love.graphics.polygon("fill",
    px + sway * (tiers * 0.1), topY - 8,
    px - 5 + sway * (tiers * 0.1), topY + 4,
    px + 5 + sway * (tiers * 0.1), topY + 4
  )
  -- Snow on tip
  love.graphics.setColor(0.90 * ambientIntensity, 0.92 * ambientIntensity, 0.96 * ambientIntensity, 0.9)
  love.graphics.circle("fill", px + sway * (tiers * 0.1), topY - 6, 3)
end

-- ═══════════════════════════════════════
-- DRAW: HOT SPRING STEAM
-- ═══════════════════════════════════════

function M.drawSteam(gs, time, ambientIntensity)
  local areas = require("chillon.areas")
  ambientIntensity = ambientIntensity or 0.9

  -- Steam from hot spring pool decorations
  for _, deco in ipairs(areas.decorations) do
    if deco.type == "hot_spring_pool" then
      local cx = (deco.x + (deco.w or 1) / 2) * gs
      local cy = deco.y * gs

      for i = 1, 8 do
        local seed = i * 7.31 + deco.x * 3.7
        local steamX = cx + math.sin(time * 0.8 + seed) * 15
        local steamY = cy - 10 - i * 8 - math.sin(time * 1.2 + seed * 1.3) * 5
        local steamSize = 6 + math.sin(time + seed) * 3
        local alpha = (0.15 - i * 0.015) * ambientIntensity

        love.graphics.setColor(0.85, 0.88, 0.92, math.max(0, alpha))
        love.graphics.circle("fill", steamX, steamY, steamSize)
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW: FROZEN RIVER / ICE SURFACE
-- ═══════════════════════════════════════

function M.drawFrozenLake(gs, time, ambientIntensity)
  local areas = require("chillon.areas")
  local lake = areas.zones.frozen_lake
  if not lake then return end

  local lx = lake.x1 * gs
  local ly = lake.y1 * gs
  local lw = (lake.x2 - lake.x1 + 1) * gs
  local lh = (lake.y2 - lake.y1 + 1) * gs

  -- Ice surface base
  love.graphics.setColor(0.55 * ambientIntensity, 0.68 * ambientIntensity, 0.78 * ambientIntensity)
  love.graphics.rectangle("fill", lx, ly, lw, lh)

  -- Ice cracks
  love.graphics.setColor(0.45 * ambientIntensity, 0.58 * ambientIntensity, 0.70 * ambientIntensity, 0.5)
  for i = 1, 12 do
    local seed = i * 13.7
    local cx1 = lx + (math.sin(seed) * 0.5 + 0.5) * lw
    local cy1 = ly + (math.sin(seed * 1.7) * 0.5 + 0.5) * lh
    local cx2 = cx1 + math.sin(seed * 2.3) * 40
    local cy2 = cy1 + math.cos(seed * 3.1) * 30
    love.graphics.setLineWidth(0.5)
    love.graphics.line(cx1, cy1, cx2, cy2)
    -- Branch cracks
    love.graphics.line(cx2, cy2, cx2 + 15, cy2 + 10)
    love.graphics.line(cx2, cy2, cx2 - 10, cy2 + 15)
  end
  love.graphics.setLineWidth(1)

  -- Surface shimmer / reflection
  for i = 1, 6 do
    local seed = i * 9.3
    local sx = lx + (math.sin(seed + time * 0.3) * 0.5 + 0.5) * lw
    local sy = ly + (math.sin(seed * 1.5 + time * 0.2) * 0.5 + 0.5) * lh
    local sparkle = math.sin(time * 2 + seed) * 0.3 + 0.5
    love.graphics.setColor(0.85, 0.90, 0.98, sparkle * 0.25 * ambientIntensity)
    love.graphics.circle("fill", sx, sy, 3)
  end

  -- Dark depths showing through in places
  for i = 1, 4 do
    local seed = i * 17.9
    local dx = lx + (math.sin(seed) * 0.5 + 0.5) * lw * 0.8 + lw * 0.1
    local dy = ly + (math.sin(seed * 1.3) * 0.5 + 0.5) * lh * 0.8 + lh * 0.1
    love.graphics.setColor(0.15 * ambientIntensity, 0.25 * ambientIntensity, 0.40 * ambientIntensity, 0.2)
    love.graphics.ellipse("fill", dx, dy, 20, 12)
  end
end

-- ═══════════════════════════════════════
-- DRAW: GROUND SNOW OVERLAY
-- (adds snow patches to all outdoor zones)
-- ═══════════════════════════════════════

function M.drawSnowGround(zone, x, y, w, h, gs, ambientIntensity, time)
  -- Random snow patches on ground
  local count = math.floor(w * h / 300)
  for i = 1, count do
    local seed = i * 11.3 + x * 0.1 + y * 0.13
    local sx = x + (math.sin(seed) * 0.5 + 0.5) * w
    local sy = y + (math.sin(seed * 1.73) * 0.5 + 0.5) * h
    local patchSize = 8 + math.sin(seed * 2.91) * 5

    love.graphics.setColor(0.82 * ambientIntensity, 0.85 * ambientIntensity, 0.90 * ambientIntensity, 0.3 + math.sin(seed) * 0.15)
    love.graphics.ellipse("fill", sx, sy, patchSize, patchSize * 0.5)
  end
end

-- ═══════════════════════════════════════
-- DRAW: GORGES (dark void under bridges)
-- ═══════════════════════════════════════

function M.drawGorges(gs, time, ambientIntensity)
  local areas = require("chillon.areas")
  for _, gorge in ipairs(areas.gorges) do
    for ty = gorge.y1, gorge.y2 do
      for tx = gorge.x1, gorge.x2 do
        local onBridge = areas.isOnBridge(tx, ty)
        if not onBridge then
          -- Deep gorge — dark rock with icy blue tint
          local depth = gorge.depth / 300
          love.graphics.setColor(
            0.08 * (1 - depth * 0.4) * ambientIntensity,
            0.10 * (1 - depth * 0.3) * ambientIntensity,
            0.16 * (1 - depth * 0.2) * ambientIntensity
          )
          love.graphics.rectangle("fill", tx * gs, ty * gs, gs, gs)

          -- Rocky ledges visible in the depths
          local hash = (tx * 47 + ty * 83) % 256 / 256
          if hash > 0.55 then
            love.graphics.setColor(0.18 * ambientIntensity, 0.22 * ambientIntensity, 0.30 * ambientIntensity, 0.35)
            local ledgeW = 6 + hash * 14
            local ledgeY = ty * gs + hash * 20
            love.graphics.rectangle("fill", tx * gs + (gs - ledgeW) / 2, ledgeY, ledgeW, 3)
          end

          -- Ice shimmer deep in gorge
          if hash > 0.80 then
            local shimmer = math.sin(time * 0.5 + tx + ty) * 0.12 + 0.12
            love.graphics.setColor(0.35, 0.55, 0.80, shimmer * ambientIntensity)
            love.graphics.circle("fill", tx * gs + gs * 0.5, ty * gs + gs * 0.5, 3 + hash * 4)
          end
        end
      end
    end
  end
end

return M
