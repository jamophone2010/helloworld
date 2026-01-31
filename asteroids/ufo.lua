local M = {}

function M.new(x, y, type)
  local ufoType = type or (math.random() < 0.5 and "small" or "large")

  return {
    x = x,
    y = y,
    vx = (math.random() < 0.5 and -1 or 1) * 100,
    type = ufoType,
    size = ufoType == "small" and 15 or 25,
    shootTimer = math.random() * 2 + 1,
    score = ufoType == "small" and 200 or 100,
    waveOffset = math.random() * math.pi * 2
  }
end

function M.update(ufo, dt)
  ufo.x = ufo.x + ufo.vx * dt
  ufo.waveOffset = ufo.waveOffset + dt * 2
  ufo.y = ufo.y + math.sin(ufo.waveOffset) * 50 * dt

  ufo.shootTimer = ufo.shootTimer - dt
end

function M.canShoot(ufo)
  return ufo.shootTimer <= 0
end

function M.shoot(ufo, targetX, targetY)
  ufo.shootTimer = math.random() * 2 + 1

  local angle
  if ufo.type == "small" then
    angle = math.atan2(targetY - ufo.y, targetX - ufo.x)
    angle = angle + (math.random() - 0.5) * 0.3
  else
    angle = math.random() * math.pi * 2
  end

  return angle
end

function M.isOffScreen(ufo, width)
  return ufo.x < -100 or ufo.x > width + 100
end

return M
