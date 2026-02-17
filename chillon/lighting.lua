-- chillon/lighting.lua
-- Day/night cycle and lighting system for Chillon (Montreux × Chamonix)
-- Alpine light: crisp mountain sun, long shadows, blue-white daylight,
-- deep blue nights, aurora borealis, frost shimmer

local M = {}

-- Time constants
M.CYCLE_DURATION = 30 * 60  -- 30 minutes real = 24 hours in-game
M.SUNRISE_HOUR = 7          -- Late arctic sunrise
M.SUNSET_HOUR = 17          -- Early arctic sunset (short days)

-- Current time state
local worldTime = 0
local dayNumber = 1

function M.init()
  worldTime = 10 / 24 * M.CYCLE_DURATION  -- Start at late morning
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

-- Get time of day string
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
    return nil
  end
  local dayProgress = (hour - M.SUNRISE_HOUR) / (M.SUNSET_HOUR - M.SUNRISE_HOUR)
  return dayProgress * math.pi
end

-- Get sun direction for shadows (arctic = very long shadows)
function M.getSunDirection()
  local angle = M.getSunAngle()
  if not angle then
    return 0, 0.3  -- Night: minimal ambient shadow
  end
  local sunHeight = math.sin(angle)
  local sunX = -math.cos(angle)
  -- Arctic sun is always low, so shadows are very long
  local shadowLength = 2.0 / math.max(sunHeight, 0.15)
  shadowLength = math.min(shadowLength, 6)
  return -sunX * 0.5, shadowLength * 0.3
end

-- ═══════════════════════════════════════
-- AMBIENT LIGHT (Arctic: cold, blue-white palette)
-- ═══════════════════════════════════════

function M.getAmbientLight()
  local hour = M.getHour()

  -- Deep night (dark blue-grey, arctic dark)
  if hour < 5.5 or hour > 19.5 then
    return {0.08, 0.10, 0.18}, 0.22
  end

  -- Pre-dawn (cold steel blue)
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return {0.08 + t * 0.25, 0.10 + t * 0.22, 0.18 + t * 0.15}, 0.22 + t * 0.25
  end

  -- Dawn / sunrise (7-8:30) — pale pink-gold on ice
  if hour < 8.5 then
    local t = (hour - 7) / 1.5
    return {0.33 + t * 0.35, 0.32 + t * 0.30, 0.33 + t * 0.22}, 0.47 + t * 0.25
  end

  -- Morning (8:30-10) — brightening cold white
  if hour < 10 then
    local t = (hour - 8.5) / 1.5
    return {0.68 + t * 0.12, 0.62 + t * 0.18, 0.55 + t * 0.25}, 0.72 + t * 0.15
  end

  -- Full day (10-14) — bright cold white-blue (arctic daylight)
  if hour < 14 then
    return {0.80, 0.82, 0.85}, 0.90
  end

  -- Afternoon (14-16) — golden hour starts early in arctic
  if hour < 16 then
    local t = (hour - 14) / 2
    return {0.80 + t * 0.10, 0.82 - t * 0.10, 0.85 - t * 0.18}, 0.90 - t * 0.08
  end

  -- Sunset (16-17) — deep amber-pink on snow
  if hour < 17 then
    local t = (hour - 16)
    return {0.90 - t * 0.35, 0.72 - t * 0.28, 0.67 - t * 0.20}, 0.82 - t * 0.22
  end

  -- Twilight (17-18.5) — deep blue-violet, alpenglow on peaks
  if hour < 18.5 then
    local t = (hour - 17) / 1.5
    return {0.55 - t * 0.30, 0.44 - t * 0.22, 0.47 - t * 0.15}, 0.60 - t * 0.22
  end

  -- Dusk to night (18.5-19.5) — deepening to arctic darkness
  if hour <= 19.5 then
    local t = (hour - 18.5)
    return {0.25 - t * 0.17, 0.22 - t * 0.12, 0.32 - t * 0.14}, 0.38 - t * 0.16
  end

  return {0.08, 0.10, 0.18}, 0.22
end

-- ═══════════════════════════════════════
-- SKY COLORS (Arctic palette)
-- ═══════════════════════════════════════

function M.getSkyColors()
  local hour = M.getHour()

  -- Night — deep blue-black arctic sky
  if hour < 5.5 or hour > 19.5 then
    return {0.03, 0.04, 0.12}, {0.05, 0.06, 0.18}
  end

  -- Pre-dawn — steel blue to pale violet
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return
      {0.05 + t * 0.35, 0.06 + t * 0.15, 0.15 + t * 0.20},
      {0.03 + t * 0.12, 0.05 + t * 0.15, 0.18 + t * 0.22}
  end

  -- Sunrise — pink-gold horizon, steel-blue zenith
  if hour < 8.5 then
    local t = (hour - 7) / 1.5
    return
      {0.40 + t * 0.30, 0.21 + t * 0.35, 0.35 + t * 0.15},
      {0.15 + t * 0.20, 0.20 + t * 0.28, 0.40 + t * 0.25}
  end

  -- Morning — clearing to cold blue
  if hour < 10 then
    local t = (hour - 8.5) / 1.5
    return
      {0.70 - t * 0.15, 0.56 + t * 0.12, 0.50 + t * 0.20},
      {0.35 + t * 0.10, 0.48 + t * 0.12, 0.65 + t * 0.10}
  end

  -- Midday — pale arctic blue, almost white at horizon
  if hour < 14 then
    return {0.58, 0.70, 0.82}, {0.35, 0.52, 0.78}
  end

  -- Afternoon to sunset — deepening amber and pink
  if hour < 17 then
    local t = (hour - 14) / 3
    return
      {0.58 + t * 0.35, 0.70 - t * 0.38, 0.82 - t * 0.52},
      {0.35 + t * 0.10, 0.52 - t * 0.20, 0.78 - t * 0.35}
  end

  -- Dusk — deep indigo and violet
  if hour <= 19.5 then
    local t = (hour - 17) / 2.5
    return
      {0.93 - t * 0.88, 0.32 - t * 0.26, 0.30 - t * 0.16},
      {0.45 - t * 0.40, 0.32 - t * 0.26, 0.43 - t * 0.23}
  end

  return {0.03, 0.04, 0.12}, {0.05, 0.06, 0.18}
end

-- Sunset glow intensity
function M.getSunsetGlow()
  local hour = M.getHour()
  if hour >= 15.5 and hour <= 18 then
    local peak = 17
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5)
  end
  if hour >= 6 and hour <= 8.5 then
    local peak = 7.5
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5) * 0.8
  end
  return 0
end

function M.getDayNumber()
  return dayNumber
end

function M.isNight()
  local hour = M.getHour()
  return hour < 7 or hour > 17.5
end

function M.lampsOn()
  local hour = M.getHour()
  return hour < 7.5 or hour > 16.5
end

-- ═══════════════════════════════════════
-- SHADOW SYSTEM
-- Extra-long arctic shadows
-- ═══════════════════════════════════════

function M.drawShadow(x, y, w, h, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    -- Night: soft ambient shadow
    love.graphics.setColor(0.03, 0.03, 0.08, 0.15)
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

  -- Outer soft shadow (blue-tinted for snow)
  love.graphics.setColor(0.05, 0.05, 0.12, 0.12)
  love.graphics.polygon("fill",
    x * gs - 2, (y + h) * gs,
    (x + w) * gs + 2, (y + h) * gs,
    (x + w) * gs + shadowOffsetX + 4, (y + h) * gs + shadowOffsetY + 4,
    x * gs + shadowOffsetX - 4, (y + h) * gs + shadowOffsetY + 4
  )
  -- Inner shadow
  love.graphics.setColor(0.05, 0.05, 0.10, 0.20)
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
  local shadowLength = 14 + sdy * 24
  local shadowWidth = 10

  love.graphics.setColor(0.03, 0.03, 0.08, 0.15)
  love.graphics.ellipse("fill",
    px + sdx * shadowLength * 0.3,
    py + 10 + sdy * shadowLength * 0.5,
    shadowWidth,
    shadowLength * 0.3
  )
end

-- Draw tree shadow
function M.drawTreeShadow(x, y, gs, treeType)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    love.graphics.setColor(0.03, 0.03, 0.08, 0.10)
    love.graphics.ellipse("fill", x * gs + gs/2, y * gs + gs, gs * 0.5, gs * 0.25)
    return
  end

  local trunkHeight = gs * 2.5
  local shadowLength = trunkHeight * sdy * 1.2  -- Longer arctic shadows

  -- Trunk shadow
  love.graphics.setColor(0.03, 0.03, 0.08, 0.12)
  love.graphics.polygon("fill",
    x * gs + gs/2 - 4, y * gs + gs,
    x * gs + gs/2 + 4, y * gs + gs,
    x * gs + gs/2 + 4 + sdx * shadowLength * 0.3, y * gs + gs + shadowLength,
    x * gs + gs/2 - 4 + sdx * shadowLength * 0.3, y * gs + gs + shadowLength
  )

  -- Crown shadow (triangular for pines)
  local crownSize = gs * 0.6
  local crownX = x * gs + gs/2 + sdx * shadowLength * 0.3
  local crownY = y * gs + gs + shadowLength
  love.graphics.setColor(0.03, 0.03, 0.08, 0.10)
  love.graphics.polygon("fill",
    crownX, crownY - crownSize * 0.5,
    crownX - crownSize, crownY + crownSize * 0.3,
    crownX + crownSize, crownY + crownSize * 0.3
  )
end

-- ═══════════════════════════════════════
-- AMBIENT OVERLAY
-- Arctic tint: blue shadows at night, crisp white during day
-- ═══════════════════════════════════════

function M.applyAmbientOverlay(screenW, screenH)
  local color, intensity = M.getAmbientLight()

  -- Night darkening with blue-ice tint
  if intensity < 0.85 then
    local alpha = (1 - intensity) * 0.50
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Cold blue-violet tint (stronger than Elendil for arctic feel)
    love.graphics.setColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.9, (1 - intensity) * 0.25)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  -- Golden hour glow (short-lived in arctic)
  local hour = M.getHour()
  if (hour >= 7 and hour <= 8.5) or (hour >= 15.5 and hour <= 17) then
    local bloomIntensity = 0
    if hour <= 8.5 then
      bloomIntensity = math.max(0, 1 - math.abs(hour - 7.75) / 0.75) * 0.10
    else
      bloomIntensity = math.max(0, 1 - math.abs(hour - 16.25) / 0.75) * 0.12
    end
    love.graphics.setColor(1.0, 0.80, 0.50, bloomIntensity)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

-- ═══════════════════════════════════════
-- MOONLIGHT (bright arctic moon)
-- ═══════════════════════════════════════

function M.drawMoonlight(screenW, screenH, time)
  if not M.isNight() then return end

  local hour = M.getHour()
  local moonProgress = 0
  if hour > 17.5 then
    moonProgress = (hour - 17.5) / 4.5
  elseif hour < 7 then
    moonProgress = 1 - hour / 7
  end

  if moonProgress <= 0 then return end

  -- Moon position
  local moonAngle = moonProgress * math.pi
  local moonX = screenW * 0.3 + math.cos(moonAngle) * screenW * 0.4
  local moonY = 50 - math.sin(moonAngle) * 35

  -- Arctic moon: bright, cold, larger
  love.graphics.setColor(0.60, 0.65, 0.85, 0.12 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 100)
  love.graphics.setColor(0.70, 0.75, 0.90, 0.20 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 50)
  love.graphics.setColor(0.88, 0.90, 0.95, 0.70 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 14)
  love.graphics.setColor(0.92, 0.94, 1.0, 0.90 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 12)

  -- Moonlight on snow (subtle brightening)
  love.graphics.setColor(0.25, 0.30, 0.50, 0.04 * moonProgress)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)
end

return M
