-- cereus/lighting.lua
-- Desert day/night cycle with Arizona-accurate lighting
-- 30-minute real-time = 24 hour in-game cycle
-- Intense desert sun, dramatic golden hours, vivid sunsets, clear starry nights
-- Shadows track sun across the sky (east to west)

local M = {}

-- Time constants
M.CYCLE_DURATION = 30 * 60  -- 30 minutes = full day
M.SUNRISE_HOUR = 5.5        -- Arizona sunrise ~5:30 AM summer
M.SUNSET_HOUR = 19.5        -- Arizona sunset ~7:30 PM summer

-- Current time state
local worldTime = 0
local dayNumber = 1

function M.init()
  -- Start at early morning for dramatic entry
  worldTime = (7 / 24) * M.CYCLE_DURATION  -- 7 AM
  dayNumber = math.floor(os.time() / 86400)
end

function M.update(dt)
  worldTime = worldTime + dt
  if worldTime >= M.CYCLE_DURATION then
    worldTime = worldTime - M.CYCLE_DURATION
    dayNumber = dayNumber + 1
  end
end

-- Get current hour (0-24)
function M.getHour()
  return (worldTime / M.CYCLE_DURATION) * 24
end

-- Get time of day as string
function M.getTimeString()
  local hour = M.getHour()
  local h = math.floor(hour)
  local m = math.floor((hour - h) * 60)
  local ampm = h >= 12 and "PM" or "AM"
  local displayHour = h % 12
  if displayHour == 0 then displayHour = 12 end
  return string.format("%d:%02d %s", displayHour, m, ampm)
end

-- Get sun position angle
function M.getSunAngle()
  local hour = M.getHour()
  if hour < M.SUNRISE_HOUR or hour > M.SUNSET_HOUR then
    return nil  -- Below horizon
  end
  local dayProgress = (hour - M.SUNRISE_HOUR) / (M.SUNSET_HOUR - M.SUNRISE_HOUR)
  return dayProgress * math.pi
end

-- Get sun direction for shadow casting
function M.getSunDirection()
  local angle = M.getSunAngle()
  if not angle then
    return 0, 0.3  -- Night: minimal ambient shadow
  end
  local sunHeight = math.sin(angle)
  local sunX = -math.cos(angle)
  local shadowLength = 1.5 / math.max(sunHeight, 0.15)
  shadowLength = math.min(shadowLength, 5)  -- Desert shadows can be very long at dawn/dusk
  return -sunX * 0.5, shadowLength * 0.3
end

-- Get ambient light color and intensity
-- Arizona desert has distinctive warm light with intense midday bleaching
function M.getAmbientLight()
  local hour = M.getHour()

  -- Deep night (8PM - 4:30AM) — clear desert skies, cooler tone
  if hour < 4.5 or hour > 21 then
    return {0.08, 0.08, 0.18}, 0.2
  end

  -- Pre-dawn (4:30AM - 5:30AM) — navy to purple horizon
  if hour < 5.5 then
    local t = (hour - 4.5) / 1.0
    return {0.08 + t * 0.5, 0.08 + t * 0.25, 0.18 + t * 0.15}, 0.2 + t * 0.3
  end

  -- Dawn golden hour (5:30AM - 7AM) — warm desert orange
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return {0.58 + t * 0.35, 0.33 + t * 0.45, 0.33 + t * 0.4}, 0.5 + t * 0.3
  end

  -- Morning warmth (7AM - 9AM) — desert warming
  if hour < 9 then
    local t = (hour - 7) / 2
    return {0.93 + t * 0.05, 0.78 + t * 0.12, 0.73 + t * 0.15}, 0.8 + t * 0.12
  end

  -- Harsh midday (9AM - 4PM) — Arizona sun: intense, slightly bleached/white
  if hour < 16 then
    return {0.98, 0.95, 0.88}, 0.98
  end

  -- Afternoon golden hour (4PM - 6PM) — warm amber
  if hour < 18 then
    local t = (hour - 16) / 2
    return {0.98, 0.92 - t * 0.15, 0.85 - t * 0.25}, 0.98 - t * 0.1
  end

  -- Sunset (6PM - 7:30PM) — Arizona's famous vivid reds and oranges
  if hour < 19.5 then
    local t = (hour - 18) / 1.5
    return {0.95 - t * 0.3, 0.65 - t * 0.3, 0.45 - t * 0.2}, 0.88 - t * 0.35
  end

  -- Twilight (7:30PM - 9PM) — deep purple to navy
  if hour <= 21 then
    local t = (hour - 19.5) / 1.5
    return {0.65 - t * 0.55, 0.35 - t * 0.25, 0.25 - t * 0.05}, 0.53 - t * 0.33
  end

  return {0.08, 0.08, 0.18}, 0.2
end

-- Get sky gradient colors (Arizona desert skies)
function M.getSkyColors()
  local hour = M.getHour()

  -- Night — clear desert sky, stars visible
  if hour < 4.5 or hour > 21 then
    return {0.03, 0.03, 0.08}, {0.06, 0.06, 0.15}
  end

  -- Pre-dawn
  if hour < 5.5 then
    local t = (hour - 4.5) / 1.0
    return
      {0.05 + t * 0.7, 0.05 + t * 0.25, 0.10 + t * 0.15},
      {0.03 + t * 0.15, 0.03 + t * 0.15, 0.08 + t * 0.3}
  end

  -- Dawn
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return
      {0.75 + t * 0.15, 0.30 + t * 0.3, 0.25 + t * 0.25},
      {0.18 + t * 0.25, 0.18 + t * 0.35, 0.38 + t * 0.3}
  end

  -- Morning
  if hour < 10 then
    local t = (hour - 7) / 3
    return
      {0.90 - t * 0.15, 0.60 + t * 0.15, 0.50 + t * 0.3},
      {0.43 + t * 0.15, 0.53 + t * 0.15, 0.68 + t * 0.12}
  end

  -- Midday — deep clear Arizona blue
  if hour < 16 then
    return {0.75, 0.82, 0.92}, {0.35, 0.55, 0.85}
  end

  -- Afternoon to sunset
  if hour < 19.5 then
    local t = (hour - 16) / 3.5
    return
      {0.75 + t * 0.2, 0.82 - t * 0.45, 0.92 - t * 0.65},
      {0.35 + t * 0.2, 0.55 - t * 0.25, 0.85 - t * 0.5}
  end

  -- Twilight
  if hour <= 21 then
    local t = (hour - 19.5) / 1.5
    return
      {0.95 - t * 0.9, 0.37 - t * 0.3, 0.27 - t * 0.2},
      {0.55 - t * 0.5, 0.30 - t * 0.25, 0.35 - t * 0.2}
  end

  return {0.03, 0.03, 0.08}, {0.06, 0.06, 0.15}
end

-- Get sunset/sunrise glow intensity
function M.getSunsetGlow()
  local hour = M.getHour()
  -- Arizona sunset peaks
  if hour >= 17.5 and hour <= 20 then
    local peak = 19
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5)
  end
  -- Sunrise glow
  if hour >= 5 and hour <= 7 then
    local peak = 6
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5) * 0.8
  end
  return 0
end

-- Get day number for seeded randomness
function M.getDayNumber()
  return dayNumber
end

-- Check if it's night
function M.isNight()
  local hour = M.getHour()
  return hour < 5.5 or hour > 19.5
end

-- Check if lamps should be on
function M.lampsOn()
  local hour = M.getHour()
  return hour < 6 or hour > 19
end

-- Get desert heat shimmer intensity (0-1, peaks at midday)
function M.getHeatShimmer()
  local hour = M.getHour()
  if hour >= 10 and hour <= 16 then
    local peak = 13
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 3)
  end
  return 0
end

-- ═══════════════════════════════════════
-- SHADOW RENDERING
-- ═══════════════════════════════════════

-- Draw shadow for a rectangular object (building, boulder, etc)
function M.drawShadow(x, y, w, h, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    -- Night: faint ambient shadow
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.polygon("fill",
      x * gs, (y + h) * gs,
      (x + w) * gs, (y + h) * gs,
      (x + w) * gs + 6, (y + h) * gs + 6,
      x * gs + 6, (y + h) * gs + 6
    )
    return
  end

  local shadowOffsetX = sdx * w * gs * 0.6
  local shadowOffsetY = sdy * h * gs

  love.graphics.setColor(0, 0, 0, 0.22)
  love.graphics.polygon("fill",
    x * gs, (y + h) * gs,
    (x + w) * gs, (y + h) * gs,
    (x + w) * gs + shadowOffsetX, (y + h) * gs + shadowOffsetY,
    x * gs + shadowOffsetX, (y + h) * gs + shadowOffsetY
  )
end

-- Draw player shadow
function M.drawPlayerShadow(px, py)
  local sdx, sdy = M.getSunDirection()
  local shadowLength = 10 + sdy * 18
  local shadowWidth = 8

  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.ellipse("fill",
    px + sdx * shadowLength * 0.3,
    py + 10 + sdy * shadowLength * 0.5,
    shadowWidth,
    shadowLength * 0.3
  )
end

-- Draw saguaro cactus shadow
function M.drawSaguaroShadow(x, y, gs, arms, height)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.ellipse("fill", x * gs + gs / 2, y * gs + gs, gs * 0.3, gs * 0.15)
    return
  end

  local trunkH = (height or 3) * gs
  local shadowLen = trunkH * sdy * 1.0
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Main trunk shadow
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.polygon("fill",
    baseX - 4, baseY,
    baseX + 4, baseY,
    baseX + 4 + sdx * shadowLen * 0.3, baseY + shadowLen,
    baseX - 4 + sdx * shadowLen * 0.3, baseY + shadowLen
  )

  -- Arm shadows
  arms = arms or 2
  for i = 1, math.min(arms, 4) do
    local armY = baseY + shadowLen * (0.3 + i * 0.12)
    local armDir = (i % 2 == 0) and 1 or -1
    local armLen = shadowLen * 0.3
    love.graphics.polygon("fill",
      baseX + sdx * shadowLen * 0.3 * (0.4 + i * 0.1), armY - 2,
      baseX + sdx * shadowLen * 0.3 * (0.4 + i * 0.1), armY + 2,
      baseX + sdx * shadowLen * 0.3 * (0.4 + i * 0.1) + armDir * armLen, armY + 2,
      baseX + sdx * shadowLen * 0.3 * (0.4 + i * 0.1) + armDir * armLen, armY - 2
    )
  end
end

-- Draw desert tree shadow (palo verde, ironwood, mesquite)
function M.drawDesertTreeShadow(x, y, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    love.graphics.setColor(0, 0, 0, 0.1)
    love.graphics.ellipse("fill", x * gs + gs / 2, y * gs + gs, gs * 0.5, gs * 0.25)
    return
  end

  local shadowLen = gs * 2.5 * sdy
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Trunk shadow
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.polygon("fill",
    baseX - 3, baseY,
    baseX + 3, baseY,
    baseX + 3 + sdx * shadowLen * 0.25, baseY + shadowLen * 0.8,
    baseX - 3 + sdx * shadowLen * 0.25, baseY + shadowLen * 0.8
  )

  -- Canopy shadow (dappled — desert trees have sparse, lacy canopies)
  local canopyX = baseX + sdx * shadowLen * 0.3
  local canopyY = baseY + shadowLen * 0.8
  love.graphics.setColor(0, 0, 0, 0.12)
  love.graphics.ellipse("fill", canopyX, canopyY, gs * 0.9, gs * 0.5)
  -- Dappled light holes
  love.graphics.setColor(0, 0, 0, 0.06)
  for i = 1, 5 do
    local hx = canopyX + math.cos(i * 1.3 + x) * gs * 0.5
    local hy = canopyY + math.sin(i * 2.1 + y) * gs * 0.3
    love.graphics.ellipse("fill", hx, hy, gs * 0.15, gs * 0.1)
  end
end

-- Draw eucalyptus tree shadow (taller, fuller canopy)
function M.drawEucalyptusShadow(x, y, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.ellipse("fill", x * gs + gs / 2, y * gs + gs, gs * 0.6, gs * 0.3)
    return
  end

  local shadowLen = gs * 3.5 * sdy
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Trunk
  love.graphics.setColor(0, 0, 0, 0.18)
  love.graphics.polygon("fill",
    baseX - 4, baseY,
    baseX + 4, baseY,
    baseX + 4 + sdx * shadowLen * 0.2, baseY + shadowLen * 0.7,
    baseX - 4 + sdx * shadowLen * 0.2, baseY + shadowLen * 0.7
  )

  -- Full canopy shadow
  local canopyX = baseX + sdx * shadowLen * 0.25
  local canopyY = baseY + shadowLen * 0.7
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.ellipse("fill", canopyX, canopyY, gs * 1.1, gs * 0.7)
end

-- Draw fancy tree shadow (large, multi-layer canopy)
function M.drawFancyTreeShadow(x, y, gs, species)
  local sdx, sdy = M.getSunDirection()
  local baseX = x * gs + gs / 2
  local baseY = y * gs + gs

  -- Scale based on species size
  local sizeMult = 1.0
  if species == "copper_beech" then sizeMult = 1.3
  elseif species == "red_maple" then sizeMult = 1.15
  elseif species == "jacaranda" then sizeMult = 1.2
  elseif species == "golden_ash" then sizeMult = 1.05
  elseif species == "silver_birch" then sizeMult = 0.95
  elseif species == "desert_willow" then sizeMult = 1.25
  end

  if sdx == 0 and sdy == 0.3 then
    -- Night: faint ambient shadow
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.ellipse("fill", baseX, baseY, gs * 0.8 * sizeMult, gs * 0.4 * sizeMult)
    return
  end

  local shadowLen = gs * 4.5 * sdy * sizeMult
  
  -- Trunk shadow
  love.graphics.setColor(0, 0, 0, 0.20)
  love.graphics.polygon("fill",
    baseX - 5, baseY,
    baseX + 5, baseY,
    baseX + 5 + sdx * shadowLen * 0.2, baseY + shadowLen * 0.6,
    baseX - 5 + sdx * shadowLen * 0.2, baseY + shadowLen * 0.6
  )

  -- Large canopy shadow (dappled)
  local canopyX = baseX + sdx * shadowLen * 0.25
  local canopyY = baseY + shadowLen * 0.65
  love.graphics.setColor(0, 0, 0, 0.16)
  love.graphics.ellipse("fill", canopyX, canopyY, gs * 1.5 * sizeMult, gs * 0.9 * sizeMult)

  -- Dappled light holes in the canopy shadow
  love.graphics.setColor(0, 0, 0, 0.06)
  local treeSeed = x * 31 + y * 47
  for i = 1, 7 do
    local hx = canopyX + math.cos(i * 1.5 + treeSeed) * gs * 0.9 * sizeMult
    local hy = canopyY + math.sin(i * 2.3 + treeSeed) * gs * 0.5 * sizeMult
    love.graphics.ellipse("fill", hx, hy, gs * 0.18, gs * 0.12)
  end
end

-- Apply ambient lighting overlay for the full screen
function M.applyAmbientOverlay(screenW, screenH)
  local color, intensity = M.getAmbientLight()

  if intensity < 0.9 then
    local alpha = (1 - intensity) * 0.55
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Color tint (warmer than ocean — desert night has less blue)
    love.graphics.setColor(color[1], color[2], color[3], (1 - intensity) * 0.25)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  -- Midday heat bleach overlay (subtle white wash)
  local shimmer = M.getHeatShimmer()
  if shimmer > 0.1 then
    love.graphics.setColor(1, 0.98, 0.92, shimmer * 0.06)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

return M
