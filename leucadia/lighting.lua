-- leucadia/lighting.lua
-- Dynamic day/night cycle with realistic shadows
-- 30 minute real-time = 24 hour in-game cycle
-- Sunrise at 6am, sunset at 6pm

local M = {}

-- Time constants
M.CYCLE_DURATION = 30 * 60  -- 30 minutes in seconds for full day
M.SUNRISE_HOUR = 6
M.SUNSET_HOUR = 18

-- Current time state (preserved across building entries)
local worldTime = 0  -- Seconds into the cycle
local dayNumber = 1  -- For cloud seed

function M.init()
  -- Start at noon for nice initial lighting
  worldTime = M.CYCLE_DURATION / 2
  dayNumber = math.floor(os.time() / 86400)  -- Different clouds each real day
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

-- Get sun position (angle in radians, 0 = east horizon, pi/2 = zenith, pi = west horizon)
function M.getSunAngle()
  local hour = M.getHour()
  if hour < M.SUNRISE_HOUR or hour > M.SUNSET_HOUR then
    return nil  -- Sun below horizon
  end
  local dayProgress = (hour - M.SUNRISE_HOUR) / (M.SUNSET_HOUR - M.SUNRISE_HOUR)
  return dayProgress * math.pi
end

-- Get sun direction for shadows (returns dx, dy normalized)
function M.getSunDirection()
  local angle = M.getSunAngle()
  if not angle then
    return 0, 0.3  -- Night: no sun, minimal ambient shadow
  end
  -- Sun moves from east (left) to west (right)
  -- Morning: shadows point right (east)
  -- Noon: shadows point down (minimal)
  -- Evening: shadows point left (west)
  local sunHeight = math.sin(angle)  -- 0 at horizon, 1 at noon
  local sunX = -math.cos(angle)  -- -1 (east) to 1 (west)

  -- Shadow direction is opposite of sun, length based on height
  local shadowLength = 1.5 / math.max(sunHeight, 0.2)  -- Longer shadows at sunrise/sunset
  shadowLength = math.min(shadowLength, 4)  -- Cap max length

  return -sunX * 0.5, shadowLength * 0.3
end

-- Get ambient light color and intensity
function M.getAmbientLight()
  local hour = M.getHour()

  -- Night (6pm - 6am)
  if hour < 5 or hour > 20 then
    return {0.15, 0.15, 0.25}, 0.3  -- Dark blue night
  end

  -- Dawn (5am - 7am)
  if hour < 7 then
    local t = (hour - 5) / 2
    local r = 0.15 + t * 0.7
    local g = 0.15 + t * 0.5
    local b = 0.25 + t * 0.3
    return {r, g, b}, 0.3 + t * 0.5
  end

  -- Morning golden hour (7am - 9am)
  if hour < 9 then
    local t = (hour - 7) / 2
    return {0.85 + t * 0.1, 0.65 + t * 0.25, 0.55 + t * 0.35}, 0.8 + t * 0.15
  end

  -- Midday (9am - 4pm)
  if hour < 16 then
    return {0.95, 0.92, 0.88}, 0.95  -- Bright daylight
  end

  -- Golden hour (4pm - 6pm)
  if hour < 18 then
    local t = (hour - 16) / 2
    return {0.95, 0.85 - t * 0.2, 0.75 - t * 0.3}, 0.95 - t * 0.15
  end

  -- Sunset (6pm - 7pm)
  if hour < 19 then
    local t = (hour - 18)
    return {0.85 - t * 0.4, 0.55 - t * 0.25, 0.4 - t * 0.1}, 0.8 - t * 0.3
  end

  -- Dusk (7pm - 8pm)
  if hour <= 20 then
    local t = (hour - 19)
    return {0.45 - t * 0.3, 0.3 - t * 0.15, 0.3}, 0.5 - t * 0.2
  end

  return {0.15, 0.15, 0.25}, 0.3
end

-- Get sky gradient colors
function M.getSkyColors()
  local hour = M.getHour()

  -- Night
  if hour < 5 or hour > 20 then
    return {0.05, 0.05, 0.15}, {0.1, 0.1, 0.25}  -- Dark blue gradient
  end

  -- Dawn
  if hour < 7 then
    local t = (hour - 5) / 2
    return
      {0.1 + t * 0.8, 0.1 + t * 0.3, 0.2 + t * 0.2},  -- Horizon (orange)
      {0.05 + t * 0.3, 0.1 + t * 0.4, 0.2 + t * 0.5}   -- Zenith (blue)
  end

  -- Morning
  if hour < 10 then
    local t = (hour - 7) / 3
    return
      {0.9 - t * 0.2, 0.7 + t * 0.1, 0.5 + t * 0.3},
      {0.35 + t * 0.2, 0.5 + t * 0.3, 0.7 + t * 0.15}
  end

  -- Midday
  if hour < 16 then
    return {0.7, 0.85, 0.95}, {0.4, 0.6, 0.9}  -- Bright blue
  end

  -- Afternoon to sunset
  if hour < 19 then
    local t = (hour - 16) / 3
    return
      {0.7 + t * 0.25, 0.85 - t * 0.4, 0.95 - t * 0.6},  -- Warm horizon
      {0.4 + t * 0.1, 0.6 - t * 0.2, 0.9 - t * 0.4}
  end

  -- Dusk
  if hour <= 20 then
    local t = (hour - 19)
    return
      {0.95 - t * 0.85, 0.45 - t * 0.35, 0.35 - t * 0.2},
      {0.5 - t * 0.4, 0.4 - t * 0.3, 0.5 - t * 0.25}
  end

  return {0.05, 0.05, 0.15}, {0.1, 0.1, 0.25}
end

-- Get sunset glow intensity for clouds (0-1)
function M.getSunsetGlow()
  local hour = M.getHour()
  if hour >= 17 and hour <= 19.5 then
    local peak = 18.5
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5)
  end
  if hour >= 5.5 and hour <= 7.5 then
    local peak = 6.5
    local dist = math.abs(hour - peak)
    return math.max(0, 1 - dist / 1.5) * 0.7  -- Sunrise glow is softer
  end
  return 0
end

-- Get day number for cloud seed
function M.getDayNumber()
  return dayNumber
end

-- Check if it's night
function M.isNight()
  local hour = M.getHour()
  return hour < 6 or hour > 19
end

-- Check if street lamps should be on
function M.lampsOn()
  local hour = M.getHour()
  return hour < 6.5 or hour > 18.5
end

-- Draw shadow for a rectangle (building, object, etc)
function M.drawShadow(x, y, w, h, gs)
  local sdx, sdy = M.getSunDirection()
  if sdx == 0 and sdy == 0.3 then
    -- Night: simple ambient shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.polygon("fill",
      x * gs, (y + h) * gs,
      (x + w) * gs, (y + h) * gs,
      (x + w) * gs + 8, (y + h) * gs + 8,
      x * gs + 8, (y + h) * gs + 8
    )
    return
  end

  local shadowOffsetX = sdx * w * gs * 0.5
  local shadowOffsetY = sdy * h * gs

  love.graphics.setColor(0, 0, 0, 0.25)
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

  love.graphics.setColor(0, 0, 0, 0.2)
  love.graphics.ellipse("fill",
    px + sdx * shadowLength * 0.3,
    py + 10 + sdy * shadowLength * 0.5,
    shadowWidth,
    shadowLength * 0.3
  )
end

-- Apply ambient lighting overlay
function M.applyAmbientOverlay(screenW, screenH)
  local color, intensity = M.getAmbientLight()

  -- Only apply darkening at night/dusk/dawn
  if intensity < 0.9 then
    local alpha = (1 - intensity) * 0.5
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Add color tint
    love.graphics.setColor(color[1], color[2], color[3], (1 - intensity) * 0.3)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

return M
