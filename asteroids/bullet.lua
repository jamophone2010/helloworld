local M = {}

local BULLET_SPEED = 500
local BULLET_LIFETIME = 2

function M.new(x, y, angle, owner, isMissile)
  return {
    x = x,
    y = y,
    vx = math.cos(angle) * BULLET_SPEED,
    vy = math.sin(angle) * BULLET_SPEED,
    lifetime = BULLET_LIFETIME,
    owner = owner or "player",
    size = isMissile and 4 or 2,
    isMissile = isMissile or false,
    missileTrail = {},  -- trail particles for missile animation
    angle = angle,
  }
end

function M.update(bullet, dt)
  bullet.x = bullet.x + bullet.vx * dt
  bullet.y = bullet.y + bullet.vy * dt
  bullet.lifetime = bullet.lifetime - dt

  -- Update missile trail
  if bullet.isMissile then
    -- Add trail particle
    table.insert(bullet.missileTrail, {
      x = bullet.x, y = bullet.y,
      life = 0.3,
      maxLife = 0.3,
      size = 3 + math.random() * 2
    })
    -- Age and remove old trail particles
    for i = #bullet.missileTrail, 1, -1 do
      bullet.missileTrail[i].life = bullet.missileTrail[i].life - dt
      if bullet.missileTrail[i].life <= 0 then
        table.remove(bullet.missileTrail, i)
      end
    end
  end
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
