-- pooltable/cue.lua
-- Cue stick aiming and power control

local M = {}

function M.new()
  return {
    angle = 0,           -- Aim angle in radians
    power = 0,           -- 0.0 to 1.0
    charging = false,    -- Is the player holding to charge
    chargeDir = 1,       -- 1 = increasing, -1 = decreasing (oscillate)
    visible = true,
    pullBack = 0,        -- Visual pull-back distance
  }
end

function M.update(cue, dt, cueBall, mouseX, mouseY)
  if not cueBall or not cueBall.active then return end

  -- Aim towards mouse
  local dx = mouseX - cueBall.x
  local dy = mouseY - cueBall.y
  cue.angle = math.atan2(dy, dx)

  -- Power charging (oscillating bar)
  if cue.charging then
    cue.power = cue.power + cue.chargeDir * dt * 1.2
    if cue.power >= 1.0 then
      cue.power = 1.0
      cue.chargeDir = -1
    elseif cue.power <= 0 then
      cue.power = 0
      cue.chargeDir = 1
    end
    -- Cue pull-back visual (proportional to power)
    cue.pullBack = cue.power * 60
  else
    cue.pullBack = 0
  end
end

function M.startCharge(cue)
  cue.charging = true
  cue.power = 0
  cue.chargeDir = 1
end

function M.releaseCharge(cue)
  local power = cue.power
  cue.charging = false
  cue.power = 0
  cue.pullBack = 0
  return power
end

function M.resetPower(cue)
  cue.power = 0
  cue.charging = false
  cue.pullBack = 0
end

return M
