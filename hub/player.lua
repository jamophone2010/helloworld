local M = {}

local SPEED = 200

function M.new(x, y)
  return {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    radius = 15
  }
end

function M.update(player, dt, width, height)
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  player.x = math.max(player.radius, math.min(width - player.radius, player.x))
  player.y = math.max(player.radius, math.min(height - player.radius, player.y))
end

function M.setVelocity(player, vx, vy)
  player.vx = vx * SPEED
  player.vy = vy * SPEED
end

return M
