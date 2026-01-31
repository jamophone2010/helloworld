local M = {}

local INITIAL_SPEED = math.rad(1080)
local SPIN_DURATION = 3.5
local SETTLE_DURATION = 0.5

function M.new()
  return {
    angle = 0,
    velocity = 0,
    spinning = false,
    phase = "idle",
    timer = 0,
    finalPocket = nil,
    bounceOffset = 0
  }
end

function M.update(ball, dt)
  if not ball.spinning then return end

  ball.timer = ball.timer + dt
  ball.angle = ball.angle + ball.velocity * dt

  if ball.angle >= 2 * math.pi then
    ball.angle = ball.angle - 2 * math.pi
  elseif ball.angle < 0 then
    ball.angle = ball.angle + 2 * math.pi
  end

  if ball.phase == "spinning" then
    local t = math.min(ball.timer / SPIN_DURATION, 1)
    local easeOut = 1 - math.pow(1 - t, 2)
    ball.velocity = -INITIAL_SPEED * (1 - easeOut)

    if t >= 1 then
      ball.phase = "settling"
      ball.timer = 0
      ball.bounceOffset = math.random(-2, 2)
    end

  elseif ball.phase == "settling" then
    local t = math.min(ball.timer / SETTLE_DURATION, 1)
    ball.velocity = ball.velocity * (1 - t * 0.5)

    if t >= 1 then
      ball.velocity = 0
      ball.spinning = false
      ball.phase = "stopped"
    end
  end
end

function M.spin(ball, targetPocket, numPockets)
  if ball.spinning then return false end

  ball.spinning = true
  ball.phase = "spinning"
  ball.timer = 0
  ball.velocity = -INITIAL_SPEED
  ball.finalPocket = targetPocket
  ball.angle = math.pi

  return true
end

function M.isStopped(ball)
  return ball.phase == "stopped"
end

return M
