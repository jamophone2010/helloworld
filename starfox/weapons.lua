local M = {}

local LASER_SPEED = 600
local LASER_COOLDOWN = 0.15
local CHARGE_TIME = 2.0
local BOMB_EXPAND_SPEED = 400

M.lasers = {}
M.bombs = {}
M.shootCooldown = 0

function M.reset()
  M.lasers = {}
  M.bombs = {}
  M.shootCooldown = 0
end

function M.update(dt, player)
  M.shootCooldown = math.max(0, M.shootCooldown - dt)

  if player.charging then
    player.chargeLevel = math.min(1, player.chargeLevel + dt / CHARGE_TIME)
  end

  for i = #M.lasers, 1, -1 do
    local laser = M.lasers[i]
    laser.y = laser.y + laser.vy * dt

    if laser.y < -20 or laser.y > 620 then
      table.remove(M.lasers, i)
    end
  end

  for i = #M.bombs, 1, -1 do
    local bomb = M.bombs[i]
    bomb.radius = bomb.radius + BOMB_EXPAND_SPEED * dt
    bomb.alpha = bomb.alpha - dt

    if bomb.alpha <= 0 then
      table.remove(M.bombs, i)
    end
  end
end

function M.shoot(player)
  if M.shootCooldown <= 0 then
    table.insert(M.lasers, {
      x = player.x,
      y = player.y - 20,
      vy = -LASER_SPEED,
      damage = 1,
      width = 4,
      height = 15,
      owner = "player",
      charged = false
    })
    M.shootCooldown = LASER_COOLDOWN
    return true
  end
  return false
end

function M.startCharge(player)
  player.charging = true
  player.chargeLevel = 0
end

function M.releaseCharge(player)
  if player.charging and player.chargeLevel > 0.5 then
    local damage = math.floor(player.chargeLevel * 5)
    table.insert(M.lasers, {
      x = player.x,
      y = player.y - 20,
      vy = -LASER_SPEED * 0.8,
      damage = damage,
      width = 20 + player.chargeLevel * 20,
      height = 40,
      owner = "player",
      charged = true,
      piercing = true
    })
    player.charging = false
    player.chargeLevel = 0
    return true
  end
  player.charging = false
  player.chargeLevel = 0
  return false
end

function M.fireBomb(player)
  table.insert(M.bombs, {
    x = player.x,
    y = player.y,
    radius = 10,
    alpha = 1,
    damage = 10
  })
  return true
end

function M.fireEnemyLaser(x, y, targetX, targetY)
  local dx = targetX - x
  local dy = targetY - y
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist > 0 then
    dx = dx / dist
    dy = dy / dist
  else
    dy = 1
  end

  table.insert(M.lasers, {
    x = x,
    y = y,
    vx = dx * 300,
    vy = dy * 300,
    damage = 5,
    width = 6,
    height = 6,
    owner = "enemy"
  })
end

return M
