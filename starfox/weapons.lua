local M = {}
local screen = require("starfox.screen")

local LASER_SPEED = 600
local LASER_COOLDOWN = 0.15
local CHARGE_TIME = 2.0
local BOMB_EXPAND_SPEED = 400
local SPARTAN_LASER_MAX_TIME = 5.0

M.lasers = {}
M.bombs = {}
M.missiles = {}
M.shotgunPellets = {}
M.chargedBlasts = {}
M.shootCooldown = 0
M.spartanLaserBeam = nil
M.paladinCharging = false
M.paladinChargeLevel = 0

function M.reset()
  M.lasers = {}
  M.bombs = {}
  M.missiles = {}
  M.shotgunPellets = {}
  M.chargedBlasts = {}
  M.shootCooldown = 0
  M.spartanLaserBeam = nil
  M.paladinCharging = false
  M.paladinChargeLevel = 0
end

function M.fireHomingMissiles(player, targets)
  for _, target in ipairs(targets) do
    table.insert(M.missiles, {
      x = player.x,
      y = player.y - 20,
      vx = 0,
      vy = -400,
      damage = 1,
      width = 6,
      height = 12,
      owner = "player",
      targetRef = target.ref,
      targetX = target.x,
      targetY = target.y,
      age = 0,
      maxAge = 2
    })
  end
  M.shootCooldown = 0.3
end

function M.update(dt, player)
  M.shootCooldown = math.max(0, M.shootCooldown - dt)

  if player.charging then
    player.chargeLevel = math.min(1, player.chargeLevel + dt / CHARGE_TIME)
  end

  for i = #M.lasers, 1, -1 do
    local laser = M.lasers[i]
    laser.x = laser.x + (laser.vx or 0) * dt
    laser.y = laser.y + laser.vy * dt

    -- Remove if off-screen or stuck (near-zero velocity)
    local speed = math.sqrt((laser.vx or 0)^2 + laser.vy^2)
    if laser.y < -20 or laser.y > screen.HEIGHT + 20 or laser.x < -20 or laser.x > screen.WIDTH + 20 or speed < 10 then
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

  -- Update missiles
  for i = #M.missiles, 1, -1 do
    local m = M.missiles[i]
    m.age = m.age + dt
    if m.age > m.maxAge then
      table.remove(M.missiles, i)
      goto continue
    end

    -- Update target pos if alive
    if m.targetRef and m.targetRef.health and m.targetRef.health > 0 then
      m.targetX = m.targetRef.x
      m.targetY = m.targetRef.y
    elseif m.targetRef and m.targetRef.health and m.targetRef.health <= 0 then
      -- Target is dead, remove missile immediately
      table.remove(M.missiles, i)
      goto continue
    end

    -- Homing trajectory
    local dx = m.targetX - m.x
    local dy = m.targetY - m.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > 1 then
      local speed = 500
      m.vx = (dx/dist)*speed
      m.vy = (dy/dist)*speed
    end

    m.x = m.x + m.vx*dt
    m.y = m.y + m.vy*dt

    if m.y < -50 or m.y > screen.HEIGHT + 50 or m.x < -50 or m.x > screen.WIDTH + 50 then
      table.remove(M.missiles, i)
    end
    ::continue::
  end

  -- Update shotgun pellets
  for i = #M.shotgunPellets, 1, -1 do
    local p = M.shotgunPellets[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.age = p.age + dt

    -- Fade out over lifetime
    p.alpha = 1 - (p.age / p.maxAge)

    if p.age >= p.maxAge or p.y < -20 or p.y > screen.HEIGHT + 20 or p.x < -20 or p.x > screen.WIDTH + 20 then
      table.remove(M.shotgunPellets, i)
    end
  end

  -- Update charged blasts (Paladin special)
  for i = #M.chargedBlasts, 1, -1 do
    local blast = M.chargedBlasts[i]
    blast.y = blast.y + blast.vy * dt
    blast.age = blast.age + dt

    -- Expand radius slightly as it travels for visual effect
    blast.currentRadius = blast.radius + (blast.age * 20)

    if blast.y < -50 or blast.age >= blast.maxAge then
      table.remove(M.chargedBlasts, i)
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
    damage = 5
  })
  return true
end

function M.fireShotgun(player)
  local PELLET_COUNT = 12
  local SPREAD_ANGLE = math.pi / 3  -- 60 degree spread
  local BASE_SPEED = 500
  local SPEED_VARIANCE = 100

  for i = 1, PELLET_COUNT do
    -- Spread pellets in a cone upward
    local angle = -math.pi/2 + (math.random() - 0.5) * SPREAD_ANGLE
    local speed = BASE_SPEED + (math.random() - 0.5) * SPEED_VARIANCE

    table.insert(M.shotgunPellets, {
      x = player.x,
      y = player.y - 15,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      damage = 2,  -- Base damage per pellet
      width = 4,
      height = 4,
      owner = "player",
      age = 0,
      maxAge = 0.5,  -- Short lifetime for close-range
      alpha = 1
    })
  end

  M.shootCooldown = 0.3
  return true
end

function M.startPaladinCharge()
  M.paladinCharging = true
  M.paladinChargeLevel = 0
end

function M.updatePaladinCharge(dt)
  if M.paladinCharging then
    M.paladinChargeLevel = math.min(1, M.paladinChargeLevel + dt / 2.0)  -- 2 second max charge
  end
end

function M.firePaladinBlast(player)
  if not M.paladinCharging or M.paladinChargeLevel < 0.1 then
    return false
  end

  local baseRadius = 15  -- 0.5x smaller (was 30)
  local maxRadius = 75   -- 0.5x smaller (was 150)
  local radius = baseRadius + (maxRadius - baseRadius) * M.paladinChargeLevel
  local damage = math.floor(5 + 20 * M.paladinChargeLevel)  -- 5-25 damage

  table.insert(M.chargedBlasts, {
    x = player.x,
    y = player.y - 30,
    vy = -400,
    radius = radius,
    currentRadius = radius,
    damage = damage,
    chargeLevel = M.paladinChargeLevel,
    age = 0,
    maxAge = 2.0,
    owner = "player",
    hitEnemies = {}  -- Track which enemies have been hit
  })

  M.paladinCharging = false
  M.paladinChargeLevel = 0
  M.shootCooldown = 0.5
  return true
end

function M.cancelPaladinCharge()
  M.paladinCharging = false
  M.paladinChargeLevel = 0
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
    damage = 10,
    width = 6,
    height = 6,
    owner = "enemy"
  })
end

function M.fireAllyLaser(x, y, targetX, targetY)
  local dx = targetX - x
  local dy = targetY - y
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist > 0 then
    dx = dx / dist
    dy = dy / dist
  else
    dy = -1
  end

  table.insert(M.lasers, {
    x = x,
    y = y,
    vx = dx * 400,
    vy = dy * 400,
    damage = 1,
    width = 4,
    height = 10,
    owner = "ally"
  })
end

function M.fireConvertedAllyLaser(x, y, targetX, targetY)
  local dx = targetX - x
  local dy = targetY - y
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist > 0 then
    dx = dx / dist
    dy = dy / dist
  else
    dy = -1
  end

  table.insert(M.lasers, {
    x = x,
    y = y,
    vx = dx * 400,
    vy = dy * 400,
    damage = 1,
    width = 5,
    height = 12,
    owner = "ally",
    converted = true  -- flag for purple glow rendering
  })
end

function M.mirrorProjectiles(playerX, playerY, shieldRadius, isPaladinShield, laserList)
  local EDGE_THRESHOLD = 10  -- Distance from edge to detect collision
  local REFLECTED_SPEED = 600  -- Same as normal shot (LASER_SPEED)
  local lasers = laserList or M.lasers

  for _, laser in ipairs(lasers) do
    if (laser.owner == "enemy" or laser.owner == "prototype" or laser.owner == "prototype_emp") and not laser.mirrored then
      local dx = laser.x - playerX
      local dy = laser.y - playerY
      local dist = math.sqrt(dx*dx + dy*dy)

      -- Check if laser is at or near the shield edge
      if dist >= shieldRadius - EDGE_THRESHOLD and dist <= shieldRadius + EDGE_THRESHOLD then
        -- Calculate if laser is moving towards the center
        local velocityX = laser.vx or 0
        local velocityY = laser.vy or 0
        local dotProduct = dx * velocityX + dy * velocityY

        -- Only reflect if moving towards center (dot product < 0)
        if dotProduct < 0 then
          -- Calculate surface normal (points outward from center)
          local normalX = dx / dist
          local normalY = dy / dist

          -- Reflect velocity vector off the surface
          -- Reflected = V - 2*(V·N)*N
          local dotVN = velocityX * normalX + velocityY * normalY
          local reflectedVX = velocityX - 2 * dotVN * normalX
          local reflectedVY = velocityY - 2 * dotVN * normalY

          -- Normalize and set to normal shot speed for Paladin shield
          if isPaladinShield then
            local reflectedSpeed = math.sqrt(reflectedVX*reflectedVX + reflectedVY*reflectedVY)
            if reflectedSpeed > 0 then
              laser.vx = (reflectedVX / reflectedSpeed) * REFLECTED_SPEED
              laser.vy = (reflectedVY / reflectedSpeed) * REFLECTED_SPEED
            end
          else
            laser.vx = reflectedVX
            laser.vy = reflectedVY
          end

          -- Push laser slightly outside shield to prevent re-collision
          laser.x = playerX + normalX * (shieldRadius + EDGE_THRESHOLD + 5)
          laser.y = playerY + normalY * (shieldRadius + EDGE_THRESHOLD + 5)

          -- Mark as reflected; prototype projectiles keep their type for collision detection
          if laser.owner == "prototype" or laser.owner == "prototype_emp" then
            laser.reflected = true
            if laser.owner == "prototype_emp" then
              laser.isEmp = true
            end
          end
          laser.owner = "player"
          laser.mirrored = true
        end
      end
    end
  end
end

function M.startSpartanLaser(player)
  if player.laserCooldown > 0 then
    return false
  end
  
  player.laserFiring = true
  player.laserFireTime = 0
  
  M.spartanLaserBeam = {
    x = player.x,
    y = player.y,
    width = 10,
    maxReach = screen.HEIGHT,
    active = true,
    fireTime = 0,
    actualEndY = 0  -- Where beam actually ends (0 = top of screen, or boss y position)
  }
  
  return true
end

function M.stopSpartanLaser(player)
  if not player.laserFiring then
    return
  end
  
  player.laserFiring = false
  M.spartanLaserBeam = nil
  
  -- Set cooldown based on fire duration
  if player.laserFireTime >= SPARTAN_LASER_MAX_TIME then
    player.laserCooldown = 5.0
  else
    player.laserCooldown = 2.0
  end
  
  player.laserFireTime = 0
end

function M.updateSpartanLaser(dt, player)
  if not player.laserFiring or not M.spartanLaserBeam then
    return
  end
  
  -- Update fire time
  player.laserFireTime = player.laserFireTime + dt
  M.spartanLaserBeam.fireTime = player.laserFireTime
  
  -- Update beam position to follow player
  M.spartanLaserBeam.x = player.x
  M.spartanLaserBeam.y = player.y
  
  -- Reset actualEndY to top of screen (will be updated by collision detection if hitting boss)
  M.spartanLaserBeam.actualEndY = 0
  
  -- Increase beam width over time (starts at 10, grows to 25)
  M.spartanLaserBeam.width = 10 + (player.laserFireTime / SPARTAN_LASER_MAX_TIME) * 15
  
  -- Auto-stop at max time
  if player.laserFireTime >= SPARTAN_LASER_MAX_TIME then
    M.stopSpartanLaser(player)
  end
end

function M.getSpartanLaserDamage(fireTime)
  return math.pow(2.5, fireTime)
end

return M
