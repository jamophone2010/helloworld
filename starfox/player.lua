local M = {}
local screen = require("starfox.screen")

local SPEED = 250
local INERTIA = 0.9
local BARREL_ROLL_DURATION = 0.5
local BARREL_ROLL_COOLDOWN = 1.0
local DODGE_DISTANCE = 200
local DODGE_WINDOW = 0.15
local DODGE_COOLDOWN = 1.0

function M.new(startFromPortal)
  local startY = startFromPortal and (screen.HEIGHT + 50) or (screen.HEIGHT - 100)
  return {
    x = screen.WIDTH / 2,
    y = startY,
    vx = 0,
    vy = 0,
    width = 40,
    height = 30,
    health = 100,
    maxHealth = 100,
    lives = 3,
    bombs = 3,
    enemiesDefeated = 0,
    enemiesEscaped = 0,
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
    dodgeDirection = nil,
    currentWeapon = "blaster",
    hasLaser = false,
    laserFiring = false,
    laserFireTime = 0,
    laserCooldown = 0,
    speedMultiplier = 1.0,
    dodgeMultiplier = 1.0,
    shipType = "starwing",
    hasSpecial = false,
    shotgunHeld = false,
    portalEntryTimer = startFromPortal and 1.0 or 0,
    portalEntryActive = startFromPortal or false,
    stunned = false,
    stunnedTimer = 0,
    justDied = false,
  }
end

function M.update(player, dt)
  -- Handle stun timer
  if player.stunned then
    player.stunnedTimer = player.stunnedTimer - dt
    if player.stunnedTimer <= 0 then
      player.stunned = false
      player.stunnedTimer = 0
    end
    -- While stunned: no movement, drift to a stop
    player.vx = player.vx * 0.95
    player.vy = player.vy * 0.95
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    player.x = math.max(30, math.min(screen.WIDTH - 30, player.x))
    player.y = math.max(100, math.min(screen.HEIGHT - 30, player.y))
    -- Still update cooldowns while stunned
    player.barrelRollCooldown = math.max(0, player.barrelRollCooldown - dt)
    player.invulnerableTimer = math.max(0, player.invulnerableTimer - dt)
    player.invulnerable = player.barrelRolling or player.invulnerableTimer > 0
    player.dodgeCooldown = math.max(0, player.dodgeCooldown - dt)
    player.laserCooldown = math.max(0, player.laserCooldown - dt)
    return
  end

  -- Handle portal entry animation
  if player.portalEntryActive then
    player.portalEntryTimer = player.portalEntryTimer - dt
    -- Automatically fly upward from bottom to normal position
    player.y = player.y - 150 * dt

    if player.portalEntryTimer <= 0 or player.y <= (screen.HEIGHT - 100) then
      player.y = screen.HEIGHT - 100
      player.portalEntryActive = false
      player.portalEntryTimer = 0
    end
  end

  player.x = player.x + player.vx * dt
  player.y = player.y + player.vy * dt

  player.vx = player.vx * INERTIA
  player.vy = player.vy * INERTIA

  player.x = math.max(30, math.min(screen.WIDTH - 30, player.x))
  player.y = math.max(100, math.min(screen.HEIGHT - 30, player.y))

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

  -- Update laser cooldown
  player.laserCooldown = math.max(0, player.laserCooldown - dt)
end

function M.move(player, dx, dy)
  if player.stunned then return end
  local lateralSpeed = SPEED * (player.speedMultiplier or 1.0)
  player.vx = player.vx + dx * lateralSpeed * 0.1
  player.vy = player.vy + dy * SPEED * 0.1
end

function M.barrelRoll(player)
  if player.stunned then return false end
  if player.barrelRollCooldown <= 0 and not player.barrelRolling then
    player.barrelRolling = true
    player.barrelRollTimer = BARREL_ROLL_DURATION
    player.barrelRollCooldown = BARREL_ROLL_COOLDOWN
    return true
  end
  return false
end

function M.tryDodge(player, direction)
  if player.stunned then return false end
  local currentTime = love.timer.getTime()
  
  -- Check if infinite dodge is active (Lancer/Paladin special abilities)
  local abilities = require("starfox.abilities")
  local hasInfiniteDodge = abilities.hasInfiniteDodge and abilities.hasInfiniteDodge()

  if player.dodgeCooldown > 0 and not hasInfiniteDodge then
    player.lastTapDirection = direction
    player.lastTapTime = currentTime
    return false
  end

  if player.lastTapDirection == direction and (currentTime - player.lastTapTime) < DODGE_WINDOW then
    return M.forceDodge(player, direction)
  end

  player.lastTapDirection = direction
  player.lastTapTime = currentTime
  return false
end

--- Execute a dodge immediately (used by gamepad double-tap detection which
--- has already validated the double-tap timing externally).
function M.forceDodge(player, direction)
  if player.stunned then return false end

  local abilities = require("starfox.abilities")
  local hasInfiniteDodge = abilities.hasInfiniteDodge and abilities.hasInfiniteDodge()

  if player.dodgeCooldown > 0 and not hasInfiniteDodge then
    return false
  end

  local dodgeDist = DODGE_DISTANCE * (player.dodgeMultiplier or 1.0)
  local dodgeX = direction == "left" and -dodgeDist or dodgeDist
  player.dodgeStartX = player.x
  player.x = player.x + dodgeX
  player.x = math.max(30, math.min(screen.WIDTH - 30, player.x))
  player.dodging = true
  player.dodgeTimer = 0.15
  player.dodgeCooldown = DODGE_COOLDOWN
  player.dodgeDirection = direction
  player.lastTapDirection = nil
  player.lastTapTime = 0
  return true
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
      player.justDied = true  -- Flag for boss fight death/respawn
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
  player.enemiesDefeated = player.enemiesDefeated + 1
end

function M.isAlive(player)
  return player.lives > 0
end

function M.getDodgeCooldownMax()
  return DODGE_COOLDOWN
end

function M.switchWeapon(player)
  if player.hasLaser then
    if player.currentWeapon == "blaster" then
      player.currentWeapon = "laser"
    else
      player.currentWeapon = "blaster"
    end
    return true
  end
  return false
end

return M
