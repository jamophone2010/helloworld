local M = {}

local MAX_SPEED = 400
local THRUST_ACCEL = 200
local ROTATION_SPEED = 4
local DRAG = 0.98
local SHOOT_COOLDOWN = 0.25

function M.new(x, y)
  return {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    angle = -math.pi / 2,
    size = 15,
    shootTimer = 0,
    hyperspaceTimer = 0,
    shieldTimer = 0,
    rapidFireTimer = 0,
    invulnerable = false,
    damageTimer = 0
  }
end

function M.update(ship, dt)
  ship.x = ship.x + ship.vx * dt
  ship.y = ship.y + ship.vy * dt

  ship.vx = ship.vx * DRAG
  ship.vy = ship.vy * DRAG

  ship.shootTimer = math.max(0, ship.shootTimer - dt)
  ship.hyperspaceTimer = math.max(0, ship.hyperspaceTimer - dt)
  ship.shieldTimer = math.max(0, ship.shieldTimer - dt)
  ship.rapidFireTimer = math.max(0, ship.rapidFireTimer - dt)
  ship.damageTimer = math.max(0, ship.damageTimer - dt)

  ship.invulnerable = ship.shieldTimer > 0
end

function M.thrust(ship, dt)
  ship.vx = ship.vx + math.cos(ship.angle) * THRUST_ACCEL * dt
  ship.vy = ship.vy + math.sin(ship.angle) * THRUST_ACCEL * dt

  local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
  if speed > MAX_SPEED then
    ship.vx = (ship.vx / speed) * MAX_SPEED
    ship.vy = (ship.vy / speed) * MAX_SPEED
  end
end

function M.rotate(ship, direction, dt)
  ship.angle = ship.angle + direction * ROTATION_SPEED * dt
end

function M.canShoot(ship)
  local cooldown = ship.rapidFireTimer > 0 and SHOOT_COOLDOWN / 2 or SHOOT_COOLDOWN
  return ship.shootTimer <= 0
end

function M.shoot(ship)
  if M.canShoot(ship) then
    local cooldown = ship.rapidFireTimer > 0 and SHOOT_COOLDOWN / 2 or SHOOT_COOLDOWN
    ship.shootTimer = cooldown
    return true
  end
  return false
end

function M.hyperspace(ship, width, height)
  if ship.hyperspaceTimer <= 0 then
    ship.x = math.random(50, width - 50)
    ship.y = math.random(50, height - 50)
    ship.vx = 0
    ship.vy = 0
    ship.hyperspaceTimer = 5
    return math.random() < 0.1
  end
  return false
end

function M.wrap(ship, width, height)
  if ship.x < 0 then ship.x = width end
  if ship.x > width then ship.x = 0 end
  if ship.y < 0 then ship.y = height end
  if ship.y > height then ship.y = 0 end
end

function M.getPoints(ship)
  local points = {}
  local cos = math.cos(ship.angle)
  local sin = math.sin(ship.angle)

  points[1] = ship.x + cos * ship.size
  points[2] = ship.y + sin * ship.size
  points[3] = ship.x + math.cos(ship.angle + 2.5) * ship.size * 0.6
  points[4] = ship.y + math.sin(ship.angle + 2.5) * ship.size * 0.6
  points[5] = ship.x + math.cos(ship.angle - 2.5) * ship.size * 0.6
  points[6] = ship.y + math.sin(ship.angle - 2.5) * ship.size * 0.6

  return points
end

return M
