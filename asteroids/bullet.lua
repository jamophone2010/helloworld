local M = {}

local BULLET_SPEED = 500
local BULLET_LIFETIME = 2

function M.new(x, y, angle, owner)
  return {
    x = x,
    y = y,
    vx = math.cos(angle) * BULLET_SPEED,
    vy = math.sin(angle) * BULLET_SPEED,
    lifetime = BULLET_LIFETIME,
    owner = owner or "player",
    size = 2
  }
end

function M.update(bullet, dt)
  bullet.x = bullet.x + bullet.vx * dt
  bullet.y = bullet.y + bullet.vy * dt
  bullet.lifetime = bullet.lifetime - dt
end

function M.isAlive(bullet)
  return bullet.lifetime > 0
end

function M.wrap(bullet, width, height)
  if bullet.x < 0 then bullet.x = width end
  if bullet.x > width then bullet.x = 0 end
  if bullet.y < 0 then bullet.y = height end
  if bullet.y > height then bullet.y = 0 end
end

return M
