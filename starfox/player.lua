local M = {}

local SPEED = 250
local INERTIA = 0.9
local BARREL_ROLL_DURATION = 0.5
local BARREL_ROLL_COOLDOWN = 1.0

function M.new()
  return {
    x = 400,
    y = 500,
    vx = 0,
    vy = 0,
    width = 40,
    height = 30,
    health = 100,
    maxHealth = 100,
    lives = 3,
    bombs = 3,
    score = 0,
    barrelRolling = false,
    barrelRollTimer = 0,
    barrelRollCooldown = 0,
    barrelRollAngle = 0,
    invulnerable = false,
    invulnerableTimer = 0,
    damageTimer = 0,
    chargeLevel = 0,
    charging = false
  }
end

function M.update(player, dt)
  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  player.vx = player.vx * INERTIA
  player.vy = player.vy * INERTIA

  player.x = math.max(30, math.min(770, player.x))
  player.y = math.max(100, math.min(570, player.y))

  if player.barrelRolling then
    player.barrelRollTimer = player.barrelRollTimer - dt
    player.barrelRollAngle = player.barrelRollAngle + dt * 12

    if player.barrelRollTimer <= 0 then
      player.barrelRolling = false
      player.barrelRollAngle = 0
    end
  end

  player.barrelRollCooldown = math.max(0, player.barrelRollCooldown - dt)
  player.invulnerableTimer = math.max(0, player.invulnerableTimer - dt)
  player.invulnerable = player.barrelRolling or player.invulnerableTimer > 0

  player.damageTimer = math.max(0, player.damageTimer - dt)
  if player.damageTimer <= 0 and player.health < player.maxHealth then
    player.health = math.min(player.maxHealth, player.health + dt)
  end
end

function M.move(player, dx, dy)
  player.vx = player.vx + dx * SPEED * 0.1
  player.vy = player.vy + dy * SPEED * 0.1
end

function M.barrelRoll(player)
  if player.barrelRollCooldown <= 0 and not player.barrelRolling then
    player.barrelRolling = true
    player.barrelRollTimer = BARREL_ROLL_DURATION
    player.barrelRollCooldown = BARREL_ROLL_COOLDOWN
    player.barrelRollAngle = 0
    return true
  end
  return false
end

function M.takeDamage(player, amount)
  if player.invulnerable then
    return false
  end

  player.health = player.health - amount
  player.damageTimer = 3
  player.invulnerableTimer = 0.5

  if player.health <= 0 then
    player.lives = player.lives - 1
    if player.lives > 0 then
      player.health = player.maxHealth
      player.invulnerableTimer = 2
    end
    return true
  end
  return false
end

function M.useBomb(player)
  if player.bombs > 0 then
    player.bombs = player.bombs - 1
    return true
  end
  return false
end

function M.addScore(player, points)
  player.score = player.score + points
end

function M.isAlive(player)
  return player.lives > 0
end

return M
