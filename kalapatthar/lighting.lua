-- kalapatthar/lighting.lua
-- High-altitude Himalayan lighting — perpetual twilight/night with dramatic stars
-- Kala Patthar in Deep Space has no day/night cycle, just eternal starlit darkness
-- with occasional aurora-like cosmic light effects.
-- All world-space draw functions omit camX/camY (called inside translate block).

local M = {}

local gameTime = 0
local CYCLE_LENGTH = 1800  -- 30 min real = one cosmic cycle

function M.load()
  gameTime = 0
end

function M.update(dt)
  gameTime = gameTime + dt
end

function M.getHour()
  return 22  -- always night
end

function M.getTimeString()
  return "Deep Space"
end

function M.isNight()
  return true
end

function M.lampsOn()
  return true
end

function M.getCosmicPulse()
  local phase = (gameTime % CYCLE_LENGTH) / CYCLE_LENGTH
  return math.sin(phase * math.pi * 2) * 0.5 + 0.5
end

function M.getAmbientLight()
  local pulse = M.getCosmicPulse()
  return {
    0.08 + pulse * 0.04,
    0.08 + pulse * 0.06,
    0.12 + pulse * 0.05,
  }
end

function M.getTemperature()
  local pulse = M.getCosmicPulse()
  return math.floor(-25 + pulse * 5)
end

-- =============================================
-- SCREEN-SPACE: Cosmic aurora (before translate)
-- =============================================

function M.drawCosmicAurora(screenW, screenH, time)
  local pulse = M.getCosmicPulse()
  if pulse < 0.3 then return end

  local intensity = (pulse - 0.3) / 0.7

  for i = 1, 5 do
    local y = screenH * 0.15 + i * 20
    local wave = math.sin(time * 0.3 + i * 0.8) * 40

    -- Aurora ribbon
    local r = 0.15 + math.sin(time * 0.2 + i) * 0.1
    local g = 0.40 + math.sin(time * 0.3 + i * 0.5) * 0.15
    local b = 0.60 + math.sin(time * 0.25 + i * 0.7) * 0.1

    love.graphics.setColor(r, g, b, intensity * 0.08)
    love.graphics.rectangle("fill", 0, y + wave, screenW, 15)
  end
end

-- =============================================
-- WORLD-SPACE: Building glow (inside translate block)
-- =============================================

function M.drawBuildingGlow(bx, by, bw, bh, glowColor)
  local gc = glowColor or {0.90, 0.70, 0.30}
  love.graphics.setColor(gc[1], gc[2], gc[3], 0.08)
  love.graphics.circle("fill", bx + bw / 2, by + bh / 2, math.max(bw, bh) * 1.2)
  love.graphics.setColor(gc[1], gc[2], gc[3], 0.04)
  love.graphics.circle("fill", bx + bw / 2, by + bh / 2, math.max(bw, bh) * 2)
end

-- =============================================
-- WORLD-SPACE: Shadows (inside translate block)
-- =============================================

function M.drawBuildingShadow(bx, by, bw, bh)
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.polygon("fill",
    bx + bw, by + bh,
    bx + bw + 8, by + bh + 6,
    bx + 8, by + bh + 6,
    bx, by + bh
  )
end

function M.drawPlayerShadow(px, py)
  love.graphics.setColor(0, 0, 0, 0.12)
  love.graphics.ellipse("fill", px, py + 16, 8, 3)
end

-- =============================================
-- SCREEN-SPACE: Ambient overlay (after pop)
-- =============================================

function M.drawAmbientOverlay(screenW, screenH)
  local ambient = M.getAmbientLight()
  -- Very subtle blue-purple tint over everything
  love.graphics.setColor(0.05, 0.03, 0.12, 0.25)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Vignette at edges
  local vw = screenW * 0.4
  local vh = screenH * 0.4
  love.graphics.setColor(0, 0, 0, 0.15)
  love.graphics.rectangle("fill", 0, 0, vw, screenH)
  love.graphics.rectangle("fill", screenW - vw, 0, vw, screenH)
  love.graphics.rectangle("fill", 0, 0, screenW, vh * 0.5)
  love.graphics.rectangle("fill", 0, screenH - vh * 0.5, screenW, vh * 0.5)
end

return M
