-- Police Patrol Robot system for Asteroids
local M = {}

local bullet = require("asteroids.bullet")
local particle = require("asteroids.particle")

-- Patrol robot types
M.TYPE_NORMAL = "normal"
M.TYPE_BIG = "big"
M.TYPE_MEGA = "mega"
M.TYPE_AGENT = "agent"

-- Ship size reference for tractor beam range
local SHIP_SIZE = 19

local PATROL_DEFS = {
  [M.TYPE_NORMAL] = {
    size = 18,
    health = 3,
    speed = 140,
    chaseSpeed = 180,
    tractorRange = 5 * SHIP_SIZE,
    canShoot = false,
    score = 50,
    flashLights = false,
  },
  [M.TYPE_BIG] = {
    size = 36,
    health = 7,
    speed = 160,
    chaseSpeed = 200,
    tractorRange = 10 * SHIP_SIZE,
    canShoot = true,
    shootCooldown = 1.5,
    bulletSlow = 0.25,
    bulletSlowDuration = 2.0,
    score = 200,
    flashLights = true,
  },
  [M.TYPE_MEGA] = {
    size = 72,
    health = 15,
    speed = 170,
    chaseSpeed = 220,
    tractorRange = 20 * SHIP_SIZE,
    canShoot = true,
    shootCooldown = 0.8,
    bulletSlow = 0.25,
    bulletSlowDuration = 2.0,
    score = 500,
    flashLights = true,
  },
  [M.TYPE_AGENT] = {
    size = 50,
    health = 25,
    speed = 200,
    chaseSpeed = 260,
    tractorRange = 15 * SHIP_SIZE,
    canShoot = true,
    shootCooldown = 0.6,
    bulletSlow = 0.25,
    bulletSlowDuration = 2.0,
    bulletDamage = 10,
    score = 1000,
    flashLights = true,
  },
}

function M.new(x, y, patrolType)
  patrolType = patrolType or M.TYPE_NORMAL
  local def = PATROL_DEFS[patrolType]

  return {
    x = x,
    y = y,
    vx = 0,
    vy = 0,
    patrolType = patrolType,
    size = def.size,
    health = def.health,
    maxHealth = def.health,
    speed = def.speed,
    chaseSpeed = def.chaseSpeed,
    tractorRange = def.tractorRange,
    canShoot = def.canShoot,
    shootTimer = def.canShoot and (def.shootCooldown or 1.5) or 999,
    shootCooldown = def.shootCooldown or 1.5,
    bulletSlow = def.bulletSlow or 0,
    bulletSlowDuration = def.bulletSlowDuration or 0,
    bulletDamage = def.bulletDamage or 0,
    score = def.score,
    flashLights = def.flashLights,
    flashTimer = 0,
    -- AI states
    state = "patrol",  -- patrol, chase, tractor, caught, warping_in, warping_out, destroyed
    hitCount = 0,  -- shots taken from player
    -- Patrol movement
    patrolAngle = math.random() * math.pi * 2,
    patrolChangeTimer = 2 + math.random() * 3,
    -- Tractor beam state
    tractorActive = false,
    tractorTimer = 0,
    tractorParticles = {},
    -- Warp-in animation
    warpTimer = 0,
    warpDuration = 1.5,
    -- Destruction
    dead = false,
    explosionTimer = 0,
    explosionParticles = {},
    -- Agent-specific
    sayonaraTimer = 0,
    sayonaraActive = false,
    agentWarpParticles = {},
  }
end

function M.getDef(patrolType)
  return PATROL_DEFS[patrolType]
end

function M.update(patrol, dt, shipX, shipY, chasing)
  if patrol.dead then
    patrol.explosionTimer = patrol.explosionTimer + dt
    M.updateExplosionParticles(patrol, dt)
    return
  end

  if patrol.state == "warping_in" then
    patrol.warpTimer = patrol.warpTimer + dt
    if patrol.warpTimer >= patrol.warpDuration then
      patrol.state = chasing and "chase" or "patrol"
    end
    return
  end

  if patrol.state == "warping_out" then
    patrol.warpTimer = patrol.warpTimer + dt
    return
  end

  patrol.flashTimer = patrol.flashTimer + dt
  patrol.shootTimer = patrol.shootTimer - dt

  if patrol.state == "patrol" then
    -- Gentle patrol movement
    patrol.patrolChangeTimer = patrol.patrolChangeTimer - dt
    if patrol.patrolChangeTimer <= 0 then
      patrol.patrolAngle = math.random() * math.pi * 2
      patrol.patrolChangeTimer = 2 + math.random() * 3
    end

    patrol.vx = math.cos(patrol.patrolAngle) * patrol.speed * 0.5
    patrol.vy = math.sin(patrol.patrolAngle) * patrol.speed * 0.5

  elseif patrol.state == "chase" then
    -- Chase the player
    local dx = shipX - patrol.x
    local dy = shipY - patrol.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0 then
      patrol.vx = (dx / dist) * patrol.chaseSpeed
      patrol.vy = (dy / dist) * patrol.chaseSpeed
    end

    -- Check if in tractor beam range
    if dist < patrol.tractorRange then
      patrol.state = "tractor"
      patrol.tractorActive = true
      patrol.tractorTimer = 0
    end

    -- Shoot at player if capable
    if patrol.canShoot and patrol.shootTimer <= 0 and dist < 400 then
      patrol.shootTimer = patrol.shootCooldown
      patrol.shouldShoot = true
      patrol.shootAngle = math.atan2(dy, dx)
    end

  elseif patrol.state == "tractor" then
    -- Tractor beam - pull player in
    patrol.tractorTimer = patrol.tractorTimer + dt
    patrol.tractorActive = true

    -- Still move toward player but slower
    local dx = shipX - patrol.x
    local dy = shipY - patrol.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0 then
      patrol.vx = (dx / dist) * patrol.speed * 0.3
      patrol.vy = (dy / dist) * patrol.speed * 0.3
    end

    -- If player escapes range, go back to chase
    if dist > patrol.tractorRange * 1.5 then
      patrol.state = "chase"
      patrol.tractorActive = false
    end

    -- Shoot at player if capable
    if patrol.canShoot and patrol.shootTimer <= 0 and dist < 500 then
      patrol.shootTimer = patrol.shootCooldown
      patrol.shouldShoot = true
      patrol.shootAngle = math.atan2(dy, dx)
    end

    -- Update tractor beam particles
    M.updateTractorParticles(patrol, dt, shipX, shipY)

  elseif patrol.state == "caught" then
    -- Holding player, no movement
    patrol.vx = 0
    patrol.vy = 0
    patrol.tractorActive = false
  end

  patrol.x = patrol.x + patrol.vx * dt
  patrol.y = patrol.y + patrol.vy * dt
end

function M.updateTractorParticles(patrol, dt, shipX, shipY)
  -- Remove expired particles
  for i = #patrol.tractorParticles, 1, -1 do
    local p = patrol.tractorParticles[i]
    p.life = p.life - dt
    p.progress = p.progress + dt * p.speed
    if p.life <= 0 or p.progress >= 1 then
      table.remove(patrol.tractorParticles, i)
    end
  end

  -- Spawn new particles along beam
  if patrol.tractorActive and math.random() < 0.8 then
    local dx = shipX - patrol.x
    local dy = shipY - patrol.y
    local perpX = -dy
    local perpY = dx
    local len = math.sqrt(perpX * perpX + perpY * perpY)
    if len > 0 then
      perpX = perpX / len
      perpY = perpY / len
    end

    local offset = (math.random() - 0.5) * 20
    table.insert(patrol.tractorParticles, {
      startX = patrol.x + perpX * offset,
      startY = patrol.y + perpY * offset,
      endX = shipX + perpX * offset * 0.5,
      endY = shipY + perpY * offset * 0.5,
      progress = 0,
      speed = 1.5 + math.random() * 1.0,
      life = 0.8,
      maxLife = 0.8,
      size = 1 + math.random() * 2,
    })
  end
end

function M.getTractorPull(patrol, shipX, shipY, thrustAccel)
  -- Returns vx, vy force to apply to the ship
  if not patrol.tractorActive then return 0, 0 end

  local dx = patrol.x - shipX
  local dy = patrol.y - shipY
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist <= 0 then return 0, 0 end

  -- Pull accelerates at the same rate the ship accelerates
  local pullStrength = thrustAccel
  -- Stronger pull as player gets closer
  local closeness = 1.0 - math.min(1.0, dist / patrol.tractorRange)
  pullStrength = pullStrength * (0.5 + closeness * 1.0)

  return (dx / dist) * pullStrength, (dy / dist) * pullStrength
end

function M.checkCaught(patrol, shipX, shipY)
  if patrol.state ~= "tractor" then return false end
  local dx = shipX - patrol.x
  local dy = shipY - patrol.y
  local dist = math.sqrt(dx * dx + dy * dy)
  return dist < patrol.size + 20
end

function M.damage(patrol, amount)
  patrol.health = patrol.health - (amount or 1)
  if patrol.health <= 0 then
    patrol.dead = true
    patrol.state = "destroyed"
    patrol.explosionTimer = 0
    M.spawnDestroyExplosion(patrol)
    return true
  end
  return false
end

function M.spawnDestroyExplosion(patrol)
  patrol.explosionParticles = {}
  local count = patrol.size * 2
  for i = 1, count do
    local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.5
    local speed = 40 + math.random() * 160
    table.insert(patrol.explosionParticles, {
      x = patrol.x + (math.random() - 0.5) * patrol.size * 0.5,
      y = patrol.y + (math.random() - 0.5) * patrol.size * 0.5,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.5 + math.random() * 1.0,
      maxLife = 1.5,
      size = 1 + math.random() * 3,
      r = 0.2 + math.random() * 0.3,
      g = 0.4 + math.random() * 0.3,
      b = 0.8 + math.random() * 0.2,
    })
  end
end

function M.updateExplosionParticles(patrol, dt)
  for i = #patrol.explosionParticles, 1, -1 do
    local p = patrol.explosionParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vx = p.vx * 0.97
    p.vy = p.vy * 0.97
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(patrol.explosionParticles, i)
    end
  end
end

function M.isExplosionDone(patrol)
  return patrol.dead and #patrol.explosionParticles == 0
end

function M.wrap(patrol, width, height)
  -- Patrols follow player between tiles, so allow going off-screen but reposition when too far
  if patrol.x < -200 then patrol.x = -200 end
  if patrol.x > width + 200 then patrol.x = width + 200 end
  if patrol.y < -200 then patrol.y = -200 end
  if patrol.y > height + 200 then patrol.y = height + 200 end
end

-- Drawing functions

function M.draw(patrol)
  if patrol.dead then
    M.drawExplosion(patrol)
    return
  end

  if patrol.state == "warping_in" then
    M.drawWarpIn(patrol)
    return
  end

  if patrol.state == "warping_out" then
    M.drawWarpOut(patrol)
    return
  end

  local s = patrol.size
  local time = love.timer.getTime()

  love.graphics.push()
  love.graphics.translate(patrol.x, patrol.y)

  -- Main body (rounded rectangular robot shape)
  if patrol.patrolType == M.TYPE_AGENT then
    love.graphics.setColor(0.15, 0.15, 0.2)
  else
    love.graphics.setColor(0.3, 0.4, 0.6)
  end
  love.graphics.polygon("fill",
    -s * 0.5, -s * 0.7,
    s * 0.5, -s * 0.7,
    s * 0.6, -s * 0.3,
    s * 0.6, s * 0.3,
    s * 0.5, s * 0.7,
    -s * 0.5, s * 0.7,
    -s * 0.6, s * 0.3,
    -s * 0.6, -s * 0.3
  )

  -- Accent stripe
  if patrol.patrolType == M.TYPE_AGENT then
    love.graphics.setColor(0.6, 0.1, 0.1)
  else
    love.graphics.setColor(0.2, 0.3, 0.5)
  end
  love.graphics.rectangle("fill", -s * 0.4, -s * 0.1, s * 0.8, s * 0.2)

  -- "POLICE" text area (small bar)
  love.graphics.setColor(0.9, 0.9, 0.9)
  love.graphics.rectangle("fill", -s * 0.3, -s * 0.05, s * 0.6, s * 0.1)

  -- Eye/sensor
  love.graphics.setColor(0.9, 0.2, 0.2)
  love.graphics.circle("fill", 0, -s * 0.35, s * 0.15)
  love.graphics.setColor(1, 0.5, 0.5, 0.5 + math.sin(time * 5) * 0.3)
  love.graphics.circle("fill", 0, -s * 0.35, s * 0.1)

  -- Flashing red/blue lights
  if patrol.flashLights then
    local flashPhase = math.sin(time * 12)
    -- Left light (red)
    local redAlpha = flashPhase > 0 and 0.9 or 0.2
    love.graphics.setColor(1, 0.1, 0.1, redAlpha)
    love.graphics.circle("fill", -s * 0.4, -s * 0.55, s * 0.1)
    -- Glow
    love.graphics.setColor(1, 0.1, 0.1, redAlpha * 0.3)
    love.graphics.circle("fill", -s * 0.4, -s * 0.55, s * 0.25)

    -- Right light (blue)
    local blueAlpha = flashPhase < 0 and 0.9 or 0.2
    love.graphics.setColor(0.1, 0.3, 1, blueAlpha)
    love.graphics.circle("fill", s * 0.4, -s * 0.55, s * 0.1)
    -- Glow
    love.graphics.setColor(0.1, 0.3, 1, blueAlpha * 0.3)
    love.graphics.circle("fill", s * 0.4, -s * 0.55, s * 0.25)
  end

  -- Side thrusters
  love.graphics.setColor(0.2, 0.5, 0.8, 0.6)
  love.graphics.circle("fill", -s * 0.55, 0, s * 0.08)
  love.graphics.circle("fill", s * 0.55, 0, s * 0.08)

  -- Health bar above
  if patrol.health < patrol.maxHealth then
    local barW = s * 1.0
    local barH = 4
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", -barW / 2, -s * 0.9, barW, barH)
    love.graphics.setColor(0.2, 0.8, 0.3)
    love.graphics.rectangle("fill", -barW / 2, -s * 0.9, barW * (patrol.health / patrol.maxHealth), barH)
  end

  love.graphics.pop()

  -- Draw tractor beam
  if patrol.tractorActive then
    M.drawTractorBeam(patrol)
  end
end

function M.drawTractorBeam(patrol)
  local time = love.timer.getTime()

  -- Draw particles along beam
  for _, p in ipairs(patrol.tractorParticles) do
    local alpha = (p.life / p.maxLife) * 0.7
    local px = p.startX + (p.endX - p.startX) * p.progress
    local py = p.startY + (p.endY - p.startY) * p.progress

    love.graphics.setColor(0.3, 0.7, 1, alpha)
    love.graphics.circle("fill", px, py, p.size)
    love.graphics.setColor(0.6, 0.9, 1, alpha * 0.5)
    love.graphics.circle("fill", px, py, p.size * 2)
  end

  -- Draw beam cone/lines
  local beamAlpha = 0.15 + math.sin(time * 8) * 0.05
  love.graphics.setColor(0.3, 0.6, 1, beamAlpha)
  love.graphics.setLineWidth(2)

  -- Multiple flickering beam lines
  for i = 1, 3 do
    local offset = math.sin(time * 6 + i * 2) * 10
    for _, p in ipairs(patrol.tractorParticles) do
      if math.random() < 0.3 then
        local px = p.startX + (p.endX - p.startX) * p.progress
        local py = p.startY + (p.endY - p.startY) * p.progress
        love.graphics.line(patrol.x + offset, patrol.y, px, py)
      end
    end
  end

  love.graphics.setLineWidth(1)
end

function M.drawWarpIn(patrol)
  local progress = patrol.warpTimer / patrol.warpDuration
  local time = love.timer.getTime()

  -- Warp flash / portal effect
  local flashSize = patrol.size * (2.0 - progress) * 2
  local flashAlpha = (1.0 - progress) * 0.8

  -- Outer ring expanding
  love.graphics.setColor(0.3, 0.5, 1, flashAlpha * 0.5)
  love.graphics.circle("line", patrol.x, patrol.y, flashSize)
  love.graphics.setColor(0.5, 0.7, 1, flashAlpha * 0.3)
  love.graphics.circle("fill", patrol.x, patrol.y, flashSize * 0.5)

  -- Inner bright flash
  love.graphics.setColor(1, 1, 1, flashAlpha)
  love.graphics.circle("fill", patrol.x, patrol.y, patrol.size * progress)

  -- Streaking particles converging
  for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2 + time * 3
    local dist = flashSize * (1.0 - progress)
    local px = patrol.x + math.cos(angle) * dist
    local py = patrol.y + math.sin(angle) * dist
    love.graphics.setColor(0.4, 0.7, 1, flashAlpha)
    love.graphics.circle("fill", px, py, 3)
    love.graphics.line(patrol.x, patrol.y, px, py)
  end

  -- Draw robot fading in
  if progress > 0.5 then
    local robotAlpha = (progress - 0.5) * 2
    love.graphics.setColor(0.3, 0.4, 0.6, robotAlpha)
    love.graphics.push()
    love.graphics.translate(patrol.x, patrol.y)
    local scale = 0.5 + progress * 0.5
    love.graphics.scale(scale, scale)
    love.graphics.polygon("fill",
      -patrol.size * 0.5, -patrol.size * 0.7,
      patrol.size * 0.5, -patrol.size * 0.7,
      patrol.size * 0.6, patrol.size * 0.3,
      patrol.size * 0.5, patrol.size * 0.7,
      -patrol.size * 0.5, patrol.size * 0.7,
      -patrol.size * 0.6, patrol.size * 0.3
    )
    love.graphics.pop()
  end
end

function M.drawWarpOut(patrol)
  local progress = patrol.warpTimer / patrol.warpDuration
  local time = love.timer.getTime()

  -- Reverse of warp in - robot shrinks and flash expands
  local flashSize = patrol.size * progress * 3
  local flashAlpha = progress * 0.8

  love.graphics.setColor(0.3, 0.5, 1, flashAlpha * 0.5)
  love.graphics.circle("line", patrol.x, patrol.y, flashSize)
  love.graphics.setColor(1, 1, 1, flashAlpha)
  love.graphics.circle("fill", patrol.x, patrol.y, patrol.size * (1.0 - progress))

  -- Particles expanding outward
  for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2 + time * 3
    local dist = flashSize * progress
    local px = patrol.x + math.cos(angle) * dist
    local py = patrol.y + math.sin(angle) * dist
    love.graphics.setColor(0.4, 0.7, 1, (1.0 - progress))
    love.graphics.circle("fill", px, py, 3)
  end
end

function M.drawExplosion(patrol)
  for _, p in ipairs(patrol.explosionParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.r, p.g, p.b, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha + 1)
  end

  -- Central flash that fades
  if patrol.explosionTimer < 0.5 then
    local flashAlpha = 1.0 - patrol.explosionTimer * 2
    love.graphics.setColor(0.5, 0.7, 1, flashAlpha * 0.5)
    love.graphics.circle("fill", patrol.x, patrol.y, patrol.size * (1 + patrol.explosionTimer))
  end
end

return M
