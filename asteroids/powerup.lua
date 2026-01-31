local M = {}

M.TYPES = {
  shield = {duration = 10, color = {0.3, 0.5, 1}},
  rapidfire = {duration = 15, color = {1, 0.5, 0}},
  health = {amount = 30, color = {0, 1, 0}}
}

function M.new(x, y, type)
  local powerupType = type or (function()
    local types = {"shield", "rapidfire", "health"}
    return types[math.random(#types)]
  end)()

  return {
    x = x,
    y = y,
    type = powerupType,
    lifetime = 10,
    rotation = 0,
    size = 12
  }
end

function M.update(powerup, dt)
  powerup.lifetime = powerup.lifetime - dt
  powerup.rotation = powerup.rotation + dt * 2
end

function M.isAlive(powerup)
  return powerup.lifetime > 0
end

function M.apply(powerup, ship)
  if powerup.type == "shield" then
    ship.shieldTimer = M.TYPES.shield.duration
  elseif powerup.type == "rapidfire" then
    ship.rapidFireTimer = M.TYPES.rapidfire.duration
  elseif powerup.type == "health" then
    return M.TYPES.health.amount
  end
  return 0
end

return M
