local M = {}

M.TYPES = {
  shield = {duration = 10, color = {0.3, 0.5, 1}, label = "S", desc = "Shield"},
  rapidfire = {duration = 15, color = {1, 0.5, 0}, label = "R", desc = "Rapid Fire"},
  health = {amount = 30, color = {0, 1, 0}, label = "+", desc = "Repair"},
  multishot = {duration = 12, color = {1, 0.2, 0.8}, label = "M", desc = "Multi-Shot"},
  speed = {duration = 10, color = {0.2, 1, 1}, label = "V", desc = "Speed Boost"},
  magnet = {duration = 15, color = {1, 1, 0.2}, label = "◎", desc = "Magnet"},
  timeslow = {duration = 8, color = {0.6, 0.3, 1}, label = "T", desc = "Time Warp"},
  bomb = {amount = 1, color = {1, 0.3, 0.1}, label = "B", desc = "Bomb"},
  score = {amount = 500, color = {1, 0.85, 0}, label = "$", desc = "Bonus"},
}

-- Labels for display
function M.getLabel(type)
  local t = M.TYPES[type]
  return t and t.label or "?"
end

-- Weighted random type selection — rarer powerups have lower weight
local typeWeights = {
  {type = "health",    weight = 30},
  {type = "shield",    weight = 20},
  {type = "rapidfire", weight = 18},
  {type = "speed",     weight = 14},
  {type = "multishot", weight = 10},
  {type = "magnet",    weight = 8},
  {type = "timeslow",  weight = 6},
  {type = "bomb",      weight = 5},
  {type = "score",     weight = 12},
}

local function weightedRandom()
  local totalWeight = 0
  for _, entry in ipairs(typeWeights) do
    totalWeight = totalWeight + entry.weight
  end
  local roll = math.random() * totalWeight
  local running = 0
  for _, entry in ipairs(typeWeights) do
    running = running + entry.weight
    if roll <= running then
      return entry.type
    end
  end
  return "health"
end

function M.new(x, y, type)
  local powerupType = type or weightedRandom()

  return {
    x = x,
    y = y,
    type = powerupType,
    lifetime = 12,
    rotation = 0,
    size = 14,
    collected = false,
    collectTimer = 0,
    collectFlash = 0,
  }
end

function M.update(powerup, dt)
  powerup.lifetime = powerup.lifetime - dt
  powerup.rotation = powerup.rotation + dt * 2

  -- Flash when about to expire
  if powerup.lifetime < 3 then
    powerup.collectFlash = math.sin(powerup.lifetime * 8) * 0.5 + 0.5
  end

  -- Collection animation
  if powerup.collected then
    powerup.collectTimer = powerup.collectTimer + dt
  end
end

function M.isAlive(powerup)
  return powerup.lifetime > 0 and not powerup.collected
end

function M.apply(powerup, ship)
  if powerup.type == "shield" then
    ship.shieldTimer = M.TYPES.shield.duration
  elseif powerup.type == "rapidfire" then
    ship.rapidFireTimer = M.TYPES.rapidfire.duration
  elseif powerup.type == "health" then
    return {health = M.TYPES.health.amount}
  elseif powerup.type == "multishot" then
    ship.multishotTimer = (ship.multishotTimer or 0) + M.TYPES.multishot.duration
  elseif powerup.type == "speed" then
    ship.speedBoostTimer = (ship.speedBoostTimer or 0) + M.TYPES.speed.duration
  elseif powerup.type == "magnet" then
    ship.magnetTimer = (ship.magnetTimer or 0) + M.TYPES.magnet.duration
  elseif powerup.type == "timeslow" then
    return {timeslow = M.TYPES.timeslow.duration}
  elseif powerup.type == "bomb" then
    ship.bombs = (ship.bombs or 0) + M.TYPES.bomb.amount
    return {message = "+1 BOMB"}
  elseif powerup.type == "score" then
    return {score = M.TYPES.score.amount, message = "+" .. M.TYPES.score.amount}
  end
  return {}
end

return M
