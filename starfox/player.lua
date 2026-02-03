local M = {}

local SPEED = 250
local INERTIA = 0.9
local BARREL_ROLL_DURATION = 0.5
local BARREL_ROLL_COOLDOWN = 1.0
local DODGE_DISTANCE = 100
local DODGE_WINDOW = 0.25
local DODGE_COOLDOWN = 1.0

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
    invulnerable = false,
    invulnerableTimer = 0,
    damageTimer = 0,
    chargeLevel = 0,
    charging = false,
    lastTapDirection = nil,
    lastTapTime = 0,
    dodgeCooldown = 0,
    dodging = false,
    dodgeTimer = 0,
    dodgeDirection = nil
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

    if player.barrelRollTimer <= 0 then
      player.barrelRolling = false
    end
  end

  player.barrelRollCooldown = math.max(0, player.barrelRollCooldown - dt)
  player.invulnerableTimer = math.max(0, player.invulnerableTimer - dt)
  player.invulnerable = player.barrelRolling or player.invulnerableTimer > 0

  player.damageTimer = math.max(0, player.damageTimer - dt)
  if player.damageTimer <= 0 and player.health < player.maxHealth then
    player.health = math.min(player.maxHealth, player.health + dt)
  end

  player.dodgeCooldown = math.max(0, player.dodgeCooldown - dt)
  if player.dodging then
    player.dodgeTimer = player.dodgeTimer - dt
    if player.dodgeTimer <= 0 then
      player.dodging = false
    end
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
    return true
  end
  return false
end

function M.tryDodge(player, direction)
  local currentTime = love.timer.getTime()

  if player.dodgeCooldown > 0 then
    player.lastTapDirection = direction
    player.lastTapTime = currentTime
    return false
  end

  if player.lastTapDirection == direction and (currentTime - player.lastTapTime) < DODGE_WINDOW then
    local dodgeX = direction == "left" and -DODGE_DISTANCE or DODGE_DISTANCE
    player.x = player.x + dodgeX
    player.x = math.max(30, math.min(770, player.x))
    player.dodging = true
    player.dodgeTimer = 0.15
    player.dodgeCooldown = DODGE_COOLDOWN
    player.dodgeDirection = direction
    player.lastTapDirection = nil
    player.lastTapTime = 0
    return true
  end

  player.lastTapDirection = direction
  player.lastTapTime = currentTime
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

function M.getDodgeCooldownMax()
  return DODGE_COOLDOWN
end

return M
