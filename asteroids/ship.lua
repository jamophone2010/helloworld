local M = {}

local MAX_SPEED = 600
local THRUST_ACCEL = 200
local ROTATION_SPEED = 4
local DRAG = 1.0  -- No deceleration
local SHOOT_COOLDOWN = 0.25
local RETRO_THRUST_ACCEL = THRUST_ACCEL * 0.5
local RESPAWN_DELAY = 2

M.THRUST_ACCEL = THRUST_ACCEL

function M.new(x, y)
  return {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    angle = -math.pi / 2,
    size = 19,  -- 1.25x larger (was 15),
    shootTimer = 0,
    hyperspaceTimer = 0,
    shieldTimer = 0,
    rapidFireTimer = 0,
    invulnerable = false,
    damageTimer = 0,
    dead = false,
    respawnTimer = 0,
    spawnX = x,
    spawnY = y,
    lives = 3,
    exploding = false,
    explosionTimer = 0,
    explosionParticles = {},
    explosionRings = {},
    explosionDebris = {},
    slowTimer = 0,
    speedMultiplier = 1.0,
    -- Smart bombs
    bombs = 3,
    bombCooldown = 0,
    -- Missiles (first shots are missiles, then revert to lasers)
    missiles = 0,
    maxMissiles = 0,
    missileEntryCount = 0,  -- missiles when entering stage (for restart)
    -- Active shield
    shieldActive = false,
    shieldEnergy = 100,
    shieldMaxEnergy = 100,
    -- New powerup timers
    multishotTimer = 0,
    speedBoostTimer = 0,
    magnetTimer = 0,
  }
end

function M.update(ship, dt)
  if ship.exploding then
    ship.explosionTimer = ship.explosionTimer + dt
    M.updateExplosion(ship, dt)
    if ship.explosionTimer >= 2.0 then
      ship.exploding = false
      ship.dead = true
      ship.respawnTimer = 0.01  -- Respawn immediately after explosion finishes
    end
    return
  end

  if ship.dead then
    ship.respawnTimer = ship.respawnTimer - dt
    if ship.respawnTimer <= 0 then
      M.respawn(ship)
    end
    return
  end

  ship.x = ship.x + ship.vx * dt * ship.speedMultiplier
  ship.y = ship.y + ship.vy * dt * ship.speedMultiplier

  ship.vx = ship.vx * DRAG
  ship.vy = ship.vy * DRAG

  ship.shootTimer = math.max(0, ship.shootTimer - dt)
  ship.hyperspaceTimer = math.max(0, ship.hyperspaceTimer - dt)
  ship.shieldTimer = math.max(0, ship.shieldTimer - dt)
  ship.rapidFireTimer = math.max(0, ship.rapidFireTimer - dt)
  ship.damageTimer = math.max(0, ship.damageTimer - dt)
  ship.bombCooldown = math.max(0, ship.bombCooldown - dt)

  -- New powerup timers
  ship.multishotTimer = math.max(0, (ship.multishotTimer or 0) - dt)
  ship.speedBoostTimer = math.max(0, (ship.speedBoostTimer or 0) - dt)
  ship.magnetTimer = math.max(0, (ship.magnetTimer or 0) - dt)

  -- Active shield energy drain/recharge
  if ship.shieldActive then
    ship.shieldEnergy = ship.shieldEnergy - 40 * dt  -- Drains over ~2.5s
    if ship.shieldEnergy <= 0 then
      ship.shieldEnergy = 0
      ship.shieldActive = false
    end
  else
    ship.shieldEnergy = math.min(ship.shieldMaxEnergy, ship.shieldEnergy + 15 * dt)  -- Recharges over ~6.7s
  end

  -- Slow effect
  if ship.slowTimer > 0 then
    ship.slowTimer = ship.slowTimer - dt
    if ship.slowTimer <= 0 then
      ship.speedMultiplier = 1.0
      ship.slowTimer = 0
    end
  end

  ship.invulnerable = ship.shieldTimer > 0
end

function M.die(ship)
  ship.lives = ship.lives - 1
  ship.exploding = true
  ship.explosionTimer = 0
  ship.vx = 0
  ship.vy = 0
  ship.shieldActive = false

  -- Generate explosion particles (sparks)
  ship.explosionParticles = {}
  for i = 1, 40 do
    local angle = (i / 40) * math.pi * 2 + (math.random() - 0.5) * 0.3
    local speed = 60 + math.random() * 200
    table.insert(ship.explosionParticles, {
      x = ship.x,
      y = ship.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.8 + math.random() * 1.2,
      maxLife = 2.0,
      size = 1 + math.random() * 3,
      r = 1,
      g = 0.3 + math.random() * 0.5,
      b = 0
    })
  end

  -- Generate expanding shockwave rings
  ship.explosionRings = {}
  for i = 1, 3 do
    table.insert(ship.explosionRings, {
      radius = 5,
      maxRadius = 80 + i * 40,
      speed = 150 + i * 60,
      alpha = 1.0,
      delay = (i - 1) * 0.15,
      started = false
    })
  end

  -- Generate hull debris (triangular fragments)
  ship.explosionDebris = {}
  for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2 + math.random() * 0.5
    local speed = 40 + math.random() * 100
    table.insert(ship.explosionDebris, {
      x = ship.x + (math.random() - 0.5) * 8,
      y = ship.y + (math.random() - 0.5) * 8,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      rotation = math.random() * math.pi * 2,
      rotSpeed = (math.random() - 0.5) * 8,
      size = 3 + math.random() * 5,
      life = 1.0 + math.random() * 1.0,
      maxLife = 2.0
    })
  end
end

function M.updateExplosion(ship, dt)
  -- Update sparks
  for i = #ship.explosionParticles, 1, -1 do
    local p = ship.explosionParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vx = p.vx * 0.98  -- Slight drag
    p.vy = p.vy * 0.98
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(ship.explosionParticles, i)
    end
  end

  -- Update shockwave rings
  for _, ring in ipairs(ship.explosionRings) do
    if ship.explosionTimer >= ring.delay then
      ring.started = true
    end
    if ring.started then
      ring.radius = ring.radius + ring.speed * dt
      ring.alpha = math.max(0, 1.0 - (ring.radius / ring.maxRadius))
    end
  end

  -- Update debris
  for i = #ship.explosionDebris, 1, -1 do
    local d = ship.explosionDebris[i]
    d.x = d.x + d.vx * dt
    d.y = d.y + d.vy * dt
    d.vy = d.vy + 20 * dt  -- Slight gravity
    d.rotation = d.rotation + d.rotSpeed * dt
    d.life = d.life - dt
    if d.life <= 0 then
      table.remove(ship.explosionDebris, i)
    end
  end
end

function M.drawExplosion(ship)
  local progress = ship.explosionTimer / 2.0

  -- Draw shockwave rings
  for _, ring in ipairs(ship.explosionRings) do
    if ring.started and ring.alpha > 0 then
      love.graphics.setLineWidth(2 + ring.alpha * 3)
      -- Outer ring: blue-white
      love.graphics.setColor(0.5, 0.7, 1.0, ring.alpha * 0.6)
      love.graphics.circle("line", ship.x, ship.y, ring.radius)
      -- Inner glow
      love.graphics.setColor(1, 0.8, 0.5, ring.alpha * 0.3)
      love.graphics.circle("line", ship.x, ship.y, ring.radius * 0.8)
    end
  end

  -- Draw central fireball (fades over time)
  if progress < 0.5 then
    local fireAlpha = 1.0 - progress * 2
    local fireSize = 10 + progress * 60
    -- Core white
    love.graphics.setColor(1, 1, 1, fireAlpha * 0.9)
    love.graphics.circle("fill", ship.x, ship.y, fireSize * 0.3)
    -- Mid orange
    love.graphics.setColor(1, 0.6, 0.1, fireAlpha * 0.7)
    love.graphics.circle("fill", ship.x, ship.y, fireSize * 0.6)
    -- Outer red glow
    love.graphics.setColor(1, 0.2, 0, fireAlpha * 0.4)
    love.graphics.circle("fill", ship.x, ship.y, fireSize)
  end

  -- Draw debris fragments
  for _, d in ipairs(ship.explosionDebris) do
    local alpha = d.life / d.maxLife
    love.graphics.setColor(0.6, 0.6, 0.7, alpha)
    love.graphics.push()
    love.graphics.translate(d.x, d.y)
    love.graphics.rotate(d.rotation)
    love.graphics.polygon("fill",
      -d.size, -d.size * 0.5,
      d.size * 0.5, -d.size * 0.3,
      0, d.size * 0.6
    )
    love.graphics.pop()
  end

  -- Draw spark particles
  for _, p in ipairs(ship.explosionParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
  end

  love.graphics.setLineWidth(1)
end

function M.respawn(ship)
  ship.dead = false
  ship.exploding = false
  ship.explosionTimer = 0
  ship.explosionParticles = {}
  ship.explosionRings = {}
  ship.explosionDebris = {}
  ship.x = ship.spawnX
  ship.y = ship.spawnY
  ship.vx = 0
  ship.vy = 0
  ship.angle = -math.pi / 2
  ship.shieldTimer = 2
  ship.invulnerable = true
  ship.shieldActive = false
  ship.bombCooldown = 0
end

function M.thrust(ship, dt)
  local thrustMult = (ship.speedBoostTimer and ship.speedBoostTimer > 0) and 1.6 or 1.0
  ship.vx = ship.vx + math.cos(ship.angle) * THRUST_ACCEL * thrustMult * dt
  ship.vy = ship.vy + math.sin(ship.angle) * THRUST_ACCEL * thrustMult * dt

  local maxSpd = (ship.speedBoostTimer and ship.speedBoostTimer > 0) and (MAX_SPEED * 1.4) or MAX_SPEED
  local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
  if speed > maxSpd then
    ship.vx = (ship.vx / speed) * maxSpd
    ship.vy = (ship.vy / speed) * maxSpd
  end
end

function M.decelerate(ship, dt)
  local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
  if speed < 1 then
    ship.vx = 0
    ship.vy = 0
    return
  end
  -- Apply braking force opposite to current velocity direction
  local brakeForce = RETRO_THRUST_ACCEL * dt
  local newSpeed = math.max(0, speed - brakeForce)
  ship.vx = (ship.vx / speed) * newSpeed
  ship.vy = (ship.vy / speed) * newSpeed
end

function M.rotate(ship, direction, dt)
  ship.angle = ship.angle + direction * ROTATION_SPEED * dt
end

function M.canShoot(ship)
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

function M.hasMultishot(ship)
  return (ship.multishotTimer or 0) > 0
end

function M.hasMagnet(ship)
  return (ship.magnetTimer or 0) > 0
end

function M.hasSpeedBoost(ship)
  return (ship.speedBoostTimer or 0) > 0
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

function M.applySlow(ship, amount, duration)
  ship.speedMultiplier = math.max(0.1, ship.speedMultiplier - amount)
  ship.slowTimer = duration
end

function M.useBomb(ship)
  if ship.bombs > 0 and ship.bombCooldown <= 0 then
    ship.bombs = ship.bombs - 1
    ship.bombCooldown = 1.0  -- 1s cooldown between bombs
    return true
  end
  return false
end

function M.toggleShield(ship)
  if ship.shieldActive then
    ship.shieldActive = false
  elseif ship.shieldEnergy > 10 then  -- Need at least 10% to activate
    ship.shieldActive = true
  end
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
