local M = {}

M.POCKETS = {0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1, "00", 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2}

M.RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}

local BASE_SPEED = math.rad(360)
local SPIN_SPEED = math.rad(720)
local ACCEL_TIME = 0.5
local COAST_TIME = 2.0
local DECEL_TIME = 1.5

function M.new()
  return {
    angle = 0,
    velocity = BASE_SPEED,
    spinning = false,
    phase = "idle",
    timer = 0,
    targetPocket = nil
  }
end

function M.getColor(number)
  if number == 0 or number == "00" then
    return "green"
  end

  local num = tonumber(number)
  if not num then return "green" end

  for _, red in ipairs(M.RED_NUMBERS) do
    if num == red then
      return "red"
    end
  end

  return "black"
end

function M.update(wheel, dt)
  wheel.angle = wheel.angle + wheel.velocity * dt

  if wheel.angle >= 2 * math.pi then
    wheel.angle = wheel.angle - 2 * math.pi
  end

  if not wheel.spinning then return end

  wheel.timer = wheel.timer + dt

  if wheel.phase == "accel" then
    local t = math.min(wheel.timer / ACCEL_TIME, 1)
    wheel.velocity = BASE_SPEED + (SPIN_SPEED - BASE_SPEED) * t

    if t >= 1 then
      wheel.phase = "coast"
      wheel.timer = 0
    end

  elseif wheel.phase == "coast" then
    wheel.velocity = SPIN_SPEED

    if wheel.timer >= COAST_TIME then
      wheel.phase = "decel"
      wheel.timer = 0
    end

  elseif wheel.phase == "decel" then
    local t = math.min(wheel.timer / DECEL_TIME, 1)
    local easeOut = 1 - math.pow(1 - t, 3)
    wheel.velocity = SPIN_SPEED - (SPIN_SPEED - BASE_SPEED) * easeOut

    if t >= 1 then
      local pocketIndex = wheel.targetPocket
      local targetAngle = (pocketIndex / #M.POCKETS) * 2 * math.pi
      wheel.angle = targetAngle
      wheel.velocity = 0
      wheel.spinning = false
      wheel.phase = "stopped"
    end
  end
end

function M.spin(wheel)
  if wheel.spinning then return false end

  wheel.spinning = true
  wheel.phase = "accel"
  wheel.timer = 0
  wheel.targetPocket = math.random(1, #M.POCKETS)

  return true
end

function M.getCurrentPocket(wheel)
  if not wheel.targetPocket then return nil end
  return M.POCKETS[wheel.targetPocket]
end

function M.isStopped(wheel)
  return wheel.phase == "stopped"
end

return M
