-- elendil/lighting.lua
-- HD-2D lighting system for Elendil — Zanaris blue palette
-- Cool blue-teal tones, neon glow accents, deep indigo nights,
-- cyan god rays, bioluminescent bloom effects

local M = {}

-- Time constants
M.CYCLE_DURATION = 30 * 60  -- 30 minutes real = 24 hours in-game
M.SUNRISE_HOUR = 5.5
M.SUNSET_HOUR = 19

-- Current time state
local worldTime = 0
local dayNumber = 1

-- HD-2D bloom state
local bloomPulse = 0

function M.init()
  worldTime = 8 / 24 * M.CYCLE_DURATION  -- Start at morning golden hour
  dayNumber = math.floor(os.time() / 86400)
  bloomPulse = 0
end

function M.update(dt)
  worldTime = worldTime + dt
  if worldTime >= M.CYCLE_DURATION then
    worldTime = worldTime - M.CYCLE_DURATION
    dayNumber = dayNumber + 1
  end
  bloomPulse = bloomPulse + dt
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

-- Get sun direction for shadows
function M.getSunDirection()
  local angle = M.getSunAngle()
  if not angle then
    return 0, 0.3
  end
  local sunHeight = math.sin(angle)
  local sunX = -math.cos(angle)
  local shadowLength = 1.5 / math.max(sunHeight, 0.2)
  shadowLength = math.min(shadowLength, 4)
  return -sunX * 0.5, shadowLength * 0.3
end

-- Zanaris ambient light — cool blue-teal, neon-tinged, deep indigo nights
function M.getAmbientLight()
  local hour = M.getHour()

  -- Deep night (indigo-blue with neon undertone)
  if hour < 4.5 or hour > 21 then
    return {0.06, 0.08, 0.22}, 0.30
  end

  -- Pre-dawn (deep blue-violet, first cyan light)
  if hour < 5.5 then
    local t = (hour - 4.5) / 1
    local r = 0.06 + t * 0.14
    local g = 0.08 + t * 0.22
    local b = 0.22 + t * 0.18
    return {r, g, b}, 0.30 + t * 0.20
  end

  -- Dawn / sunrise (5:30-7:00) — cool cyan-teal glow
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return {0.20 + t * 0.30, 0.30 + t * 0.40, 0.40 + t * 0.30}, 0.50 + t * 0.30
  end

  -- Morning (7-9) — brightening blue-white
  if hour < 9 then
    local t = (hour - 7) / 2
    return {0.50 + t * 0.20, 0.70 + t * 0.12, 0.70 + t * 0.15}, 0.80 + t * 0.12
  end

  -- Full day (9-16) — bright cool blue-white with subtle teal
  if hour < 16 then
    return {0.70, 0.82, 0.88}, 0.94
  end

  -- Afternoon (16-18) — deepening teal
  if hour < 18 then
    local t = (hour - 16) / 2
    return {0.70 - t * 0.15, 0.82 - t * 0.10, 0.88 - t * 0.05}, 0.94 - t * 0.08
  end

  -- Sunset (18-19) — blue-violet dusk
  if hour < 19 then
    local t = (hour - 18)
    return {0.55 - t * 0.20, 0.72 - t * 0.30, 0.83 - t * 0.25}, 0.86 - t * 0.22
  end

  -- Twilight (19-20) — deep indigo, neon hour
  if hour < 20 then
    local t = (hour - 19)
    return {0.35 - t * 0.18, 0.42 - t * 0.20, 0.58 - t * 0.18}, 0.64 - t * 0.20
  end

  -- Dusk to night (20-21) — deepening to neon-tinged indigo
  if hour <= 21 then
    local t = (hour - 20)
    return {0.17 - t * 0.11, 0.22 - t * 0.14, 0.40 - t * 0.18}, 0.44 - t * 0.14
  end

  return {0.06, 0.08, 0.22}, 0.30
end

-- Zanaris sky gradient (deep blue-teal, cyan-indigo)
function M.getSkyColors()
  local hour = M.getHour()

  -- Night — deep indigo with subtle neon glow
  if hour < 4.5 or hour > 21 then
    return {0.02, 0.03, 0.12}, {0.04, 0.06, 0.18}
  end

  -- Pre-dawn — indigo to cyan
  if hour < 5.5 then
    local t = (hour - 4.5) / 1
    return
      {0.04 + t * 0.12, 0.06 + t * 0.20, 0.18 + t * 0.22},
      {0.04 + t * 0.08, 0.06 + t * 0.18, 0.18 + t * 0.25}
  end

  -- Sunrise — cyan-teal through data-mist
  if hour < 7 then
    local t = (hour - 5.5) / 1.5
    return
      {0.16 + t * 0.14, 0.26 + t * 0.30, 0.40 + t * 0.25},
      {0.12 + t * 0.10, 0.24 + t * 0.28, 0.43 + t * 0.27}
  end

  -- Morning — brightening to cool blue
  if hour < 10 then
    local t = (hour - 7) / 3
    return
      {0.30 + t * 0.05, 0.56 + t * 0.12, 0.65 + t * 0.12},
      {0.22 + t * 0.10, 0.52 + t * 0.12, 0.70 + t * 0.10}
  end

  -- Midday — bright blue-cyan sky
  if hour < 16 then
    return {0.35, 0.68, 0.80}, {0.25, 0.55, 0.82}
  end

  -- Afternoon to sunset — deepening teal-indigo
  if hour < 19 then
    local t = (hour - 16) / 3
    return
      {0.35 - t * 0.12, 0.68 - t * 0.30, 0.80 - t * 0.25},
      {0.25 - t * 0.08, 0.55 - t * 0.22, 0.82 - t * 0.30}
  end

  -- Dusk — deep indigo, last cyan glow on the horizon
  if hour <= 21 then
    local t = (hour - 19) / 2
    return
      {0.23 - t * 0.19, 0.38 - t * 0.30, 0.55 - t * 0.38},
      {0.17 - t * 0.11, 0.33 - t * 0.24, 0.52 - t * 0.30}
  end

  return {0.02, 0.03, 0.12}, {0.04, 0.06, 0.18}
end

-- Sunset glow intensity
function M.getSunsetGlow()
  local hour = M.getHour()
  if hour >= 17.5 and hour <= 20 then
    local peak = 19
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5)
  end
  if hour >= 5 and hour <= 7.5 then
    local peak = 6
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
  return hour < 5.5 or hour > 19.5
end

function M.lampsOn()
  local hour = M.getHour()
  return hour < 6 or hour > 18
end

-- ═══════════════════════════════════════
-- SHADOW SYSTEM
-- Soft, layered shadows with warm tones
-- ═══════════════════════════════════════

function M.drawShadow(x, y, w, h, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    -- Night: soft ambient shadow
    love.graphics.setColor(0.05, 0.02, 0.10, 0.18)
    love.graphics.polygon("fill",
      x * gs, (y + h) * gs,
      (x + w) * gs, (y + h) * gs,
      (x + w) * gs + 6, (y + h) * gs + 6,
      x * gs + 6, (y + h) * gs + 6
    )
    return
  end

  local shadowOffsetX = sdx * w * gs * 0.5
  local shadowOffsetY = sdy * h * gs

  -- HD-2D: layered semi-transparent shadow with warm edge
  -- Outer soft shadow
  love.graphics.setColor(0.05, 0.02, 0.08, 0.12)
  love.graphics.polygon("fill",
    x * gs - 2, (y + h) * gs,
    (x + w) * gs + 2, (y + h) * gs,
    (x + w) * gs + shadowOffsetX + 4, (y + h) * gs + shadowOffsetY + 4,
    x * gs + shadowOffsetX - 4, (y + h) * gs + shadowOffsetY + 4
  )
  -- Inner sharper shadow
  love.graphics.setColor(0.05, 0.03, 0.10, 0.22)
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
  local shadowLength = 12 + sdy * 20
  local shadowWidth = 10

  -- Soft warm-tinted shadow
  love.graphics.setColor(0.05, 0.03, 0.08, 0.18)
  love.graphics.ellipse("fill",
    px + sdx * shadowLength * 0.3,
    py + 10 + sdy * shadowLength * 0.5,
    shadowWidth,
    shadowLength * 0.3
  )
end

-- Draw tree shadow (oaks, pines, willows)
function M.drawTreeShadow(x, y, gs, treeType)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    love.graphics.setColor(0.05, 0.02, 0.10, 0.12)
    love.graphics.ellipse("fill", x * gs + gs/2, y * gs + gs, gs * 0.5, gs * 0.25)
    return
  end

  local trunkHeight = gs * 2.5
  local shadowLength = trunkHeight * sdy * 1.0

  -- Trunk shadow
  love.graphics.setColor(0.05, 0.03, 0.08, 0.15)
  love.graphics.polygon("fill",
    x * gs + gs/2 - 4, y * gs + gs,
    x * gs + gs/2 + 4, y * gs + gs,
    x * gs + gs/2 + 4 + sdx * shadowLength * 0.3, y * gs + gs + shadowLength,
    x * gs + gs/2 - 4 + sdx * shadowLength * 0.3, y * gs + gs + shadowLength
  )

  -- Crown shadow
  local crownRadius = treeType == "pine_tree" and gs * 0.5 or gs * 0.8
  local crownX = x * gs + gs/2 + sdx * shadowLength * 0.3
  local crownY = y * gs + gs + shadowLength
  love.graphics.setColor(0.05, 0.03, 0.08, 0.12)
  love.graphics.ellipse("fill", crownX, crownY, crownRadius, crownRadius * 0.6)
end

-- ═══════════════════════════════════════
-- HD-2D AMBIENT OVERLAY
-- Tilt-shift + color grading + bloom
-- ═══════════════════════════════════════

function M.applyAmbientOverlay(screenW, screenH)
  local color, intensity = M.getAmbientLight()

  -- Night darkening with blue-violet tint
  if intensity < 0.85 then
    local alpha = (1 - intensity) * 0.45
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Color tint (deep blue-indigo at night for Zanaris feel)
    love.graphics.setColor(color[1] * 0.3, color[2] * 0.4, color[3] * 0.9, (1 - intensity) * 0.25)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  -- HD-2D bloom effect: cool neon-blue glow during transition hours
  local hour = M.getHour()
  if (hour >= 6 and hour <= 9) or (hour >= 16.5 and hour <= 19) then
    local bloomIntensity = 0
    if hour <= 9 then
      bloomIntensity = math.max(0, 1 - math.abs(hour - 7.5) / 1.5) * 0.08
    else
      bloomIntensity = math.max(0, 1 - math.abs(hour - 18) / 1.5) * 0.10
    end
    love.graphics.setColor(0.20, 0.60, 0.95, bloomIntensity)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

end

-- ═══════════════════════════════════════
-- HD-2D GOD RAYS
-- Volumetric light shafts through trees/buildings
-- ═══════════════════════════════════════

function M.drawGodRays(screenW, screenH, cameraX, cameraY, time)
  local angle = M.getSunAngle()
  if not angle then return end  -- No rays at night

  local sunHeight = math.sin(angle)
  -- God rays are most visible at low sun angles (morning/evening)
  if sunHeight > 0.7 then return end

  local rayIntensity = (1 - sunHeight) * 0.12
  local sunX = -math.cos(angle)

  -- Position rays based on sun direction
  local numRays = 6
  for i = 1, numRays do
    local rayX = (i / numRays) * screenW + sunX * 200 - cameraX * 0.05
    local rayWidth = 30 + math.sin(time * 0.3 + i * 2.1) * 15
    local rayAlpha = rayIntensity * (0.6 + math.sin(time * 0.5 + i * 1.7) * 0.4)

    -- Cool cyan ray color
    love.graphics.setColor(0.40, 0.75, 0.95, rayAlpha)

    -- Angled light shaft
    local angleOffset = sunX * 150
    love.graphics.polygon("fill",
      rayX - rayWidth / 2, 0,
      rayX + rayWidth / 2, 0,
      rayX + angleOffset + rayWidth, screenH * 0.7,
      rayX + angleOffset - rayWidth, screenH * 0.7
    )
  end
end

-- Draw moonlight glow at night
function M.drawMoonlight(screenW, screenH, time)
  if not M.isNight() then return end

  local hour = M.getHour()
  local moonProgress = 0
  if hour > 19.5 then
    moonProgress = (hour - 19.5) / 4.5  -- Moon rises in evening
  elseif hour < 5.5 then
    moonProgress = 1 - hour / 5.5  -- Moon sets before dawn
  end

  if moonProgress <= 0 then return end

  -- Moon position (arcs across sky)
  local moonAngle = moonProgress * math.pi
  local moonX = screenW * 0.3 + math.cos(moonAngle) * screenW * 0.4
  local moonY = 60 - math.sin(moonAngle) * 40

  -- Moon glow (cyan-neon tinted)
  love.graphics.setColor(0.3, 0.65, 0.85, 0.15 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 80)
  love.graphics.setColor(0.4, 0.75, 0.95, 0.25 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 40)
  -- Moon disc (blue-white)
  love.graphics.setColor(0.70, 0.88, 0.95, 0.7 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 12)
  love.graphics.setColor(0.80, 0.92, 1.0, 0.9 * moonProgress)
  love.graphics.circle("fill", moonX, moonY, 10)

  -- Subtle neon moonlight tint on scene
  love.graphics.setColor(0.1, 0.30, 0.55, 0.06 * moonProgress)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)
end

return M
