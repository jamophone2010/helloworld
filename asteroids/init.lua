local M = {}

local ship = require("asteroids.ship")
local bullet = require("asteroids.bullet")
local asteroid = require("asteroids.asteroid")
local ufo = require("asteroids.ufo")
local powerup = require("asteroids.powerup")
local particle = require("asteroids.particle")
local level = require("asteroids.level")
local audio = require("asteroids.audio")
local ui = require("asteroids.ui")
local worldmap = require("asteroids.worldmap")
local starfoxShips = require("starfox.ships")
local nebula = require("asteroids.nebula")

local gameState = {}

-- Callbacks for hub integration
M.returnToHub = nil
M.enterStarfox = nil

-- Portal entry tracking
local portalEntryTile = {
  x = 0,
  y = 0
}

-- Fade animation state
local fadeState = {
  active = false,
  alpha = 0,
  fadeIn = false,
  callback = nil
}

-- Landing state for station
local landingState = {
  hovering = false,
  selectedPad = nil,
  landingProgress = 0
}

-- Portal state
local portalState = {
  nearPortal = false,
  portalInfo = nil
}

-- Edge hit animation state
local edgeHitState = {
  active = false,
  timer = 0,
  duration = 0.5,
  hitX = 0,
  hitY = 0,
  particles = {}
}

-- Warp transition state (No Man's Sky style)
local warpState = {
  active = false,
  phase = "idle",  -- idle, entering, tunnel, exiting
  timer = 0,
  duration = 3.0,
  callback = nil,
  particles = {},
  tunnelRings = {},
  shipZ = 0,
  targetLevelId = nil
}

function M.load()
  gameState.state = "playing"
  gameState.pauseMenuIndex = 1
  gameState.width = 1366
  gameState.height = 768

  worldmap.init()
  nebula.init(gameState.width, gameState.height, 0, 0)
  audio.load()
  ui.load()

  -- Auto-start game (skip menu)
  M.startGame()
end

function M.restoreFromPortal()
  -- Deactivate any warp state (we don't want white flash on return)
  warpState.active = false
  warpState.phase = "idle"

  -- Return to the tile where player entered portal
  worldmap.setPosition(portalEntryTile.x, portalEntryTile.y)
  nebula.init(gameState.width, gameState.height, portalEntryTile.x, portalEntryTile.y)
  M.spawnTileContent()

  -- Position ship ~200px below the portal (center of tile)
  if gameState.ship then
    gameState.ship.x = gameState.width / 2
    gameState.ship.y = gameState.height / 2 + 200
    gameState.ship.angle = -math.pi / 2 -- Face upward toward portal
  end

  -- Start fade-in from black
  fadeState.active = true
  fadeState.alpha = 1.0
  fadeState.fadeIn = true
  fadeState.callback = nil
end

function M.startGame()
  local shipDef = starfoxShips.getSelectedDef()

  gameState.ship = ship.new(gameState.width / 2, gameState.height / 2)
  gameState.ship.shipType = starfoxShips.getSelected()
  gameState.ship.shipColor = shipDef.color
  gameState.ship.accentColor = shipDef.accentColor

  gameState.bullets = {}
  gameState.asteroids = {}
  gameState.ufos = {}
  gameState.powerups = {}
  gameState.particles = {}
  gameState.level = level.new()
  gameState.score = 0
  gameState.health = 100 * shipDef.healthMultiplier
  gameState.maxHealth = gameState.health
  gameState.damageTimer = 0

  -- Reset worldmap to center
  worldmap.init()

  -- Regenerate nebula for starting tile
  nebula.init(gameState.width, gameState.height, 0, 0)

  -- Spawn asteroids based on current tile
  M.spawnTileContent()

  gameState.state = "playing"
end

function M.spawnTileContent()
  local tile = worldmap.getCurrentTile()
  local baseCount = 4 + gameState.level.number * 2

  if tile.type == worldmap.TILE_STATION then
    gameState.asteroids = {}
  elseif tile.type == worldmap.TILE_PORTAL then
    local count = worldmap.getAsteroidCount(baseCount)
    gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count)
  else
    local count = worldmap.getAsteroidCount(baseCount)
    gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count)
  end

  -- Clear other entities on tile transition
  gameState.bullets = {}
  gameState.ufos = {}
  gameState.powerups = {}

  -- Reset landing state
  landingState.hovering = false
  landingState.selectedPad = nil
  landingState.landingProgress = 0

  -- Reset portal state
  portalState.nearPortal = false
  portalState.portalInfo = nil
end

function M.transitionToTile(newX, newY, shipWrapX, shipWrapY)
  worldmap.setPosition(newX, newY)
  gameState.ship.x = shipWrapX
  gameState.ship.y = shipWrapY
  M.spawnTileContent()

  -- Regenerate nebula with new tile seed
  nebula.init(gameState.width, gameState.height, newX, newY)
end

function M.startFade(callback)
  fadeState.active = true
  fadeState.alpha = 0
  fadeState.fadeIn = false
  fadeState.callback = callback
end

function M.updateFade(dt)
  if not fadeState.active then return end

  if fadeState.fadeIn then
    fadeState.alpha = fadeState.alpha - dt * 2
    if fadeState.alpha <= 0 then
      fadeState.alpha = 0
      fadeState.active = false
    end
  else
    fadeState.alpha = fadeState.alpha + dt * 2
    if fadeState.alpha >= 1 then
      fadeState.alpha = 1
      if fadeState.callback then
        fadeState.callback()
        fadeState.callback = nil
      end
      fadeState.fadeIn = true
    end
  end
end

-- Start warp transition (No Man's Sky style)
function M.startWarp(levelId, callback)
  -- Store current tile position for return
  portalEntryTile.x = worldmap.tileX
  portalEntryTile.y = worldmap.tileY

  warpState.active = true
  warpState.phase = "entering"
  warpState.timer = 0
  warpState.duration = 3.0
  warpState.callback = callback
  warpState.targetLevelId = levelId
  warpState.shipZ = 0
  warpState.particles = {}
  warpState.tunnelRings = {}

  -- Generate tunnel rings
  for i = 1, 20 do
    table.insert(warpState.tunnelRings, {
      z = i * 100,
      rotation = math.random() * math.pi * 2,
      rotSpeed = (math.random() - 0.5) * 2,
      color = {
        0.3 + math.random() * 0.4,
        0.5 + math.random() * 0.3,
        0.8 + math.random() * 0.2
      }
    })
  end

  -- Generate streaking particles
  for i = 1, 100 do
    table.insert(warpState.particles, {
      x = (math.random() - 0.5) * 800,
      y = (math.random() - 0.5) * 600,
      z = math.random() * 2000,
      speed = 500 + math.random() * 500,
      size = 1 + math.random() * 2
    })
  end
end

function M.updateWarp(dt)
  if not warpState.active then return end

  warpState.timer = warpState.timer + dt

  if warpState.phase == "entering" then
    -- Ship accelerates into portal (0.8s)
    warpState.shipZ = warpState.shipZ + dt * 500
    if warpState.timer >= 0.8 then
      warpState.phase = "tunnel"
      warpState.timer = 0
    end

  elseif warpState.phase == "tunnel" then
    -- Flying through warp tunnel (1.5s)
    warpState.shipZ = warpState.shipZ + dt * 2000

    -- Move tunnel rings toward camera
    for _, ring in ipairs(warpState.tunnelRings) do
      ring.z = ring.z - dt * 1500
      ring.rotation = ring.rotation + ring.rotSpeed * dt
      if ring.z < -100 then
        ring.z = ring.z + 2000
      end
    end

    -- Move particles
    for _, p in ipairs(warpState.particles) do
      p.z = p.z - dt * p.speed * 3
      if p.z < 0 then
        p.z = p.z + 2000
        p.x = (math.random() - 0.5) * 800
        p.y = (math.random() - 0.5) * 600
      end
    end

    if warpState.timer >= 1.5 then
      warpState.phase = "exiting"
      warpState.timer = 0
      -- Trigger the callback now
      if warpState.callback then
        warpState.callback()
        warpState.callback = nil
      end
    end

  elseif warpState.phase == "exiting" then
    -- Fade out effect (0.7s)
    if warpState.timer >= 0.7 then
      warpState.active = false
      warpState.phase = "idle"
    end
  end
end

function M.drawWarp()
  if not warpState.active then return end

  local width, height = gameState.width, gameState.height
  local centerX, centerY = width / 2, height / 2
  local progress = 0

  -- Dark background
  love.graphics.setColor(0, 0, 0.05, 1)
  love.graphics.rectangle("fill", 0, 0, width, height)

  if warpState.phase == "entering" then
    progress = warpState.timer / 0.8

    -- Portal opening effect
    local portalRadius = 50 + progress * 300
    local glowIntensity = progress

    -- Outer glow rings
    for i = 5, 1, -1 do
      local r = portalRadius + i * 30
      local alpha = glowIntensity * (1 - i * 0.15)
      love.graphics.setColor(0.3, 0.5, 1, alpha * 0.3)
      love.graphics.circle("line", centerX, centerY, r)
    end

    -- Portal core
    love.graphics.setColor(0.5, 0.7, 1, glowIntensity)
    love.graphics.circle("fill", centerX, centerY, portalRadius)

    -- White center
    love.graphics.setColor(1, 1, 1, glowIntensity * 0.8)
    love.graphics.circle("fill", centerX, centerY, portalRadius * 0.5)

    -- Draw ship being pulled in
    if gameState.ship and not gameState.ship.dead then
      local shipScale = 1 - progress * 0.5
      love.graphics.push()
      love.graphics.translate(centerX, centerY)
      love.graphics.scale(shipScale, shipScale)
      love.graphics.translate(-centerX, -centerY)
      M.drawStarfoxShip(gameState.ship)
      love.graphics.pop()
    end

  elseif warpState.phase == "tunnel" then
    progress = warpState.timer / 1.5

    -- Draw tunnel rings (centered)
    for _, ring in ipairs(warpState.tunnelRings) do
      if ring.z > 10 then
        local scale = 800 / ring.z
        local radius = 400 * scale
        local alpha = math.min(1, (ring.z / 500))

        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(ring.rotation)

        -- Ring glow
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], alpha * 0.6)
        love.graphics.setLineWidth(3 * scale + 1)
        love.graphics.circle("line", 0, 0, radius)

        -- Inner detail
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", 0, 0, radius * 0.9)

        love.graphics.pop()
      end
    end

    -- Draw streaking particles (star lines)
    for _, p in ipairs(warpState.particles) do
      if p.z > 10 then
        local scale = 400 / p.z
        local screenX = centerX + p.x * scale
        local screenY = centerY + p.y * scale

        -- Calculate streak length based on speed
        local streakLen = math.min(50, p.speed * 0.05 / (p.z / 500))
        local endScale = 400 / (p.z + streakLen * 10)
        local endX = centerX + p.x * endScale
        local endY = centerY + p.y * endScale

        local alpha = math.min(1, p.z / 200)
        love.graphics.setColor(0.8, 0.9, 1, alpha)
        love.graphics.setLineWidth(p.size * scale)
        love.graphics.line(screenX, screenY, endX, endY)
      end
    end

    -- Central bright core
    local coreSize = 20 + math.sin(warpState.timer * 10) * 5
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", centerX, centerY, coreSize)
    love.graphics.setColor(0.7, 0.8, 1, 0.5)
    love.graphics.circle("fill", centerX, centerY, coreSize * 2)

  elseif warpState.phase == "exiting" then
    progress = warpState.timer / 0.7

    -- White flash fading out
    local alpha = 1 - progress
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  love.graphics.setLineWidth(1)
end

function M.update(dt)
  M.updateFade(dt)
  M.updateWarp(dt)
  M.updateEdgeHit(dt)
  nebula.update(dt)

  if gameState.state == "paused" then
    return  -- Don't update game logic when paused
  end

  if gameState.state == "playing" then
    M.updatePlaying(dt)

    if not gameState.ship.dead then
      if love.keyboard.isDown("left") then
        ship.rotate(gameState.ship, -1, dt)
      end
      if love.keyboard.isDown("right") then
        ship.rotate(gameState.ship, 1, dt)
      end
      if love.keyboard.isDown("up") then
        ship.thrust(gameState.ship, dt)
      end
    end
  end
end

function M.updatePlaying(dt)
  ship.update(gameState.ship, dt)

  -- Check for tile transitions instead of simple wrap
  local transitioned, newTileX, newTileY, wrapX, wrapY =
    worldmap.checkEdgeTransition(gameState.ship.x, gameState.ship.y, gameState.width, gameState.height)

  if transitioned then
    M.transitionToTile(newTileX, newTileY, wrapX, wrapY)
  else
    -- Check if we hit a grid boundary (position was clamped)
    local hitEdge = false
    local hitX, hitY = gameState.ship.x, gameState.ship.y

    if gameState.ship.x ~= wrapX or gameState.ship.y ~= wrapY then
      hitEdge = true
      hitX = wrapX
      hitY = wrapY
    end

    -- Clamp ship position if at grid boundary
    gameState.ship.x = wrapX
    gameState.ship.y = wrapY

    -- Bounce back when hitting edge to prevent getting stuck
    if hitEdge then
      local bounceSpeed = 100
      -- Determine which edge was hit and bounce away from it
      if wrapX == 0 then
        gameState.ship.vx = bounceSpeed  -- Hit left edge, bounce right
      elseif wrapX == gameState.width then
        gameState.ship.vx = -bounceSpeed  -- Hit right edge, bounce left
      end
      if wrapY == 0 then
        gameState.ship.vy = bounceSpeed  -- Hit top edge, bounce down
      elseif wrapY == gameState.height then
        gameState.ship.vy = -bounceSpeed  -- Hit bottom edge, bounce up
      end
    end

    -- Trigger edge hit animation
    if hitEdge and not edgeHitState.active then
      edgeHitState.active = true
      edgeHitState.timer = 0
      edgeHitState.hitX = hitX
      edgeHitState.hitY = hitY
      edgeHitState.particles = {}

      -- Generate blue particles
      for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 150
        table.insert(edgeHitState.particles, {
          x = hitX,
          y = hitY,
          vx = math.cos(angle) * speed,
          vy = math.sin(angle) * speed,
          life = 0.5,
          size = 2 + math.random() * 3
        })
      end
    end
  end

  -- Update landing state at station
  if worldmap.isAtStation() then
    M.updateStationLanding(dt)
  end

  -- Update portal proximity
  if worldmap.isAtPortal() then
    M.updatePortalProximity()
  end

  gameState.damageTimer = math.max(0, gameState.damageTimer - dt)
  if gameState.damageTimer <= 0 then
    gameState.health = math.min(gameState.maxHealth, gameState.health + dt * 5)
  end

  for i = #gameState.bullets, 1, -1 do
    bullet.update(gameState.bullets[i], dt)
    bullet.wrap(gameState.bullets[i], gameState.width, gameState.height)

    if not bullet.isAlive(gameState.bullets[i]) then
      table.remove(gameState.bullets, i)
    end
  end

  for _, a in ipairs(gameState.asteroids) do
    asteroid.update(a, dt)
    asteroid.wrap(a, gameState.width, gameState.height)
  end

  for i = #gameState.ufos, 1, -1 do
    local u = gameState.ufos[i]
    ufo.update(u, dt)

    if ufo.canShoot(u) then
      local angle = ufo.shoot(u, gameState.ship.x, gameState.ship.y)
      table.insert(gameState.bullets, bullet.new(u.x, u.y, angle, "ufo"))
    end

    if ufo.isOffScreen(u, gameState.width) then
      table.remove(gameState.ufos, i)
    end
  end

  for i = #gameState.powerups, 1, -1 do
    powerup.update(gameState.powerups[i], dt)

    if not powerup.isAlive(gameState.powerups[i]) then
      table.remove(gameState.powerups, i)
    end
  end

  particle.update(gameState.particles, dt)

  -- Only do level progression in non-station tiles
  if not worldmap.isAtStation() and not worldmap.isAtPortal() then
    level.update(gameState.level, dt, #gameState.asteroids)

    if level.shouldSpawnUFO(gameState.level) then
      local side = math.random() < 0.5 and -50 or gameState.width + 50
      local y = math.random(100, gameState.height - 100)
      table.insert(gameState.ufos, ufo.new(side, y))
    end

    if gameState.level.cleared then
      level.nextLevel(gameState.level)
      local baseCount = 4 + gameState.level.number * 2
      local count = worldmap.getAsteroidCount(baseCount)
      gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count)
    end
  end

  M.checkCollisions()

  if gameState.health <= 0 then
    gameState.state = "game_over"
  end
end

function M.updateStationLanding(dt)
  local helipads = worldmap.getHelipads()
  local closestPad = nil
  local closestDist = 80 -- Landing range

  for i, pad in ipairs(helipads) do
    local dx = gameState.ship.x - pad.x
    local dy = gameState.ship.y - pad.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < closestDist then
      closestDist = dist
      closestPad = i
    end
  end

  if closestPad then
    landingState.hovering = true
    landingState.selectedPad = closestPad

    -- Check if ship is slow enough to land
    local speed = math.sqrt(gameState.ship.vx^2 + gameState.ship.vy^2)
    if speed < 30 then
      landingState.landingProgress = landingState.landingProgress + dt
      if landingState.landingProgress >= 1.5 then
        landingState.landingProgress = 1.5
        landingState.hovering = false
        landingState.selectedPad = nil
        -- Land - fade to appropriate hub based on station type
        local stationInfo = worldmap.getStationInfo()
        M.startFade(function()
          if M.returnToHub then
            M.returnToHub(stationInfo)
          end
        end)
      end
    else
      landingState.landingProgress = math.max(0, landingState.landingProgress - dt * 2)
    end
  else
    landingState.hovering = false
    landingState.selectedPad = nil
    landingState.landingProgress = 0
  end
end

function M.updatePortalProximity()
  local portalInfo = worldmap.getPortalInfo()
  local portalX = gameState.width / 2
  local portalY = gameState.height / 2

  local dx = gameState.ship.x - portalX
  local dy = gameState.ship.y - portalY
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist < 100 then
    portalState.nearPortal = true
    portalState.portalInfo = portalInfo
  else
    portalState.nearPortal = false
    portalState.portalInfo = nil
  end
end

function M.checkCollisions()
  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]

    for j = #gameState.asteroids, 1, -1 do
      local a = gameState.asteroids[j]
      local dist = math.sqrt((b.x - a.x)^2 + (b.y - a.y)^2)

      if dist < asteroid.getRadius(a) and b.owner == "player" then
        local splits, score = asteroid.split(a)
        gameState.score = gameState.score + score

        for _, split in ipairs(splits) do
          table.insert(gameState.asteroids, split)
        end

        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        table.remove(gameState.asteroids, j)
        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]

    for j = #gameState.ufos, 1, -1 do
      local u = gameState.ufos[j]
      local dist = math.sqrt((b.x - u.x)^2 + (b.y - u.y)^2)

      if dist < u.size and b.owner == "player" then
        gameState.score = gameState.score + u.score
        for _, p in ipairs(particle.new(u.x, u.y)) do
          table.insert(gameState.particles, p)
        end

        if math.random() < 0.3 then
          table.insert(gameState.powerups, powerup.new(u.x, u.y))
        end

        table.remove(gameState.ufos, j)
        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  if not gameState.ship.invulnerable and not gameState.ship.dead then
    for _, a in ipairs(gameState.asteroids) do
      local dist = math.sqrt((gameState.ship.x - a.x)^2 + (gameState.ship.y - a.y)^2)

      if dist < asteroid.getRadius(a) + gameState.ship.size then
        gameState.health = gameState.health - 25
        gameState.damageTimer = 3
        ship.die(gameState.ship)
        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        break
      end
    end

    for i = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[i]

      if b.owner == "ufo" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)

        if dist < gameState.ship.size then
          gameState.health = gameState.health - 15
          gameState.damageTimer = 3
          table.remove(gameState.bullets, i)
        end
      end
    end
  end

  for i = #gameState.powerups, 1, -1 do
    local p = gameState.powerups[i]
    local dist = math.sqrt((gameState.ship.x - p.x)^2 + (gameState.ship.y - p.y)^2)

    if dist < gameState.ship.size + p.size then
      local healAmount = powerup.apply(p, gameState.ship)
      gameState.health = math.min(gameState.maxHealth, gameState.health + healAmount)
      table.remove(gameState.powerups, i)
    end
  end
end

function M.updateEdgeHit(dt)
  if not edgeHitState.active then return end

  edgeHitState.timer = edgeHitState.timer + dt

  -- Update particles
  for i = #edgeHitState.particles, 1, -1 do
    local p = edgeHitState.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt

    if p.life <= 0 then
      table.remove(edgeHitState.particles, i)
    end
  end

  if edgeHitState.timer >= edgeHitState.duration then
    edgeHitState.active = false
  end
end

function M.draw()
  love.graphics.setBackgroundColor(0, 0, 0)

  if gameState.state == "playing" then
    M.drawPlaying()
  elseif gameState.state == "game_over" then
    ui.drawGameOver(gameState.score, gameState.level.number)
  elseif gameState.state == "paused" then
    -- Draw game in background
    M.drawPlaying()
    -- Draw pause menu overlay
    M.drawPauseMenu()
  end

  -- Draw fade overlay
  if fadeState.active then
    love.graphics.setColor(0, 0, 0, fadeState.alpha)
    love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)
  end

  -- Draw warp transition (on top of everything)
  if warpState.active then
    M.drawWarp()
  end
end

function M.drawPlaying()
  -- Draw nebula background
  nebula.draw(gameState.width, gameState.height)

  -- Draw tile-specific content
  if worldmap.isAtStation() then
    M.drawStation()
  elseif worldmap.isAtPortal() then
    M.drawPortal()
  end

  local color = gameState.level.color
  if not gameState.ship.dead then
    M.drawStarfoxShip(gameState.ship)
  end

  for _, a in ipairs(gameState.asteroids) do
    ui.drawAsteroid(a, color)
  end

  for _, b in ipairs(gameState.bullets) do
    ui.drawBullet(b)
  end

  for _, u in ipairs(gameState.ufos) do
    ui.drawUFO(u)
  end

  for _, p in ipairs(gameState.powerups) do
    ui.drawPowerup(p)
  end

  for _, p in ipairs(gameState.particles) do
    ui.drawParticle(p)
  end

  -- Draw HUD with tile info
  M.drawHUD()

  -- Draw landing UI
  if landingState.hovering then
    M.drawLandingUI()
  end

  -- Draw portal interaction UI
  if portalState.nearPortal then
    M.drawPortalUI()
  end

  -- Draw edge hit effect
  if edgeHitState.active then
    M.drawEdgeHit()
  end
end

function M.drawPauseMenu()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)

  -- Title
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.setNewFont(36)
  love.graphics.printf("PAUSED", 0, 250, gameState.width, "center")

  -- Menu options
  love.graphics.setNewFont(20)
  local options = {"Resume", "Options", "Exit to Station"}
  local startY = 350

  for i, option in ipairs(options) do
    if i == gameState.pauseMenuIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * 40, gameState.width, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(option, 0, startY + (i - 1) * 40, gameState.width, "center")
    end
  end

  -- Instructions
  love.graphics.setNewFont(14)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 550, gameState.width, "center")
end

function M.drawStarfoxShip(s)
  local shipDef = starfoxShips.getDef(s.shipType)
  local color = shipDef and shipDef.color or {0.3, 0.5, 1.0}
  local accent = shipDef and shipDef.accentColor or {0.5, 0.7, 1.0}

  love.graphics.push()
  love.graphics.translate(s.x, s.y)
  love.graphics.rotate(s.angle + math.pi / 2)

  -- Shield effect
  if s.invulnerable then
    love.graphics.setColor(0.3, 0.5, 1.0, 0.3 + math.sin(love.timer.getTime() * 10) * 0.2)
    love.graphics.circle("line", 0, 0, s.size * 1.5)
  end

  -- Main body
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.polygon("fill",
    0, -s.size,
    -s.size * 0.6, s.size * 0.6,
    0, s.size * 0.3,
    s.size * 0.6, s.size * 0.6
  )

  -- Wings
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.polygon("fill",
    -s.size * 0.4, 0,
    -s.size * 0.9, s.size * 0.5,
    -s.size * 0.4, s.size * 0.3
  )
  love.graphics.polygon("fill",
    s.size * 0.4, 0,
    s.size * 0.9, s.size * 0.5,
    s.size * 0.4, s.size * 0.3
  )

  -- Engine glow when thrusting
  if love.keyboard.isDown("up") then
    love.graphics.setColor(1, 0.5, 0.2, 0.8)
    love.graphics.polygon("fill",
      -s.size * 0.2, s.size * 0.5,
      0, s.size * (0.8 + math.random() * 0.3),
      s.size * 0.2, s.size * 0.5
    )
  end

  love.graphics.pop()
end

function M.drawStation()
  local helipads = worldmap.getHelipads()
  local tile = worldmap.getCurrentTile()

  -- Draw station structure
  love.graphics.setColor(0.3, 0.3, 0.4)
  love.graphics.rectangle("fill", 300, 200, 200, 200)

  love.graphics.setColor(0.4, 0.4, 0.5)
  love.graphics.rectangle("line", 300, 200, 200, 200)

  -- Station name
  love.graphics.setColor(0.8, 0.8, 0.9)
  local name = tile.name
  local font = love.graphics.getFont()
  local nameWidth = font:getWidth(name)
  love.graphics.print(name, 400 - nameWidth / 2, 150)

  -- Draw helipads
  for i, pad in ipairs(helipads) do
    local isSelected = (landingState.selectedPad == i)

    -- Helipad base
    if isSelected then
      love.graphics.setColor(0.2, 0.6, 0.3, 0.8)
    else
      love.graphics.setColor(0.2, 0.3, 0.4, 0.6)
    end
    love.graphics.circle("fill", pad.x, pad.y, 40)

    -- Helipad ring
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.circle("line", pad.x, pad.y, 40)
    love.graphics.circle("line", pad.x, pad.y, 30)

    -- H marking
    love.graphics.setColor(0.9, 0.9, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.line(pad.x - 10, pad.y - 15, pad.x - 10, pad.y + 15)
    love.graphics.line(pad.x + 10, pad.y - 15, pad.x + 10, pad.y + 15)
    love.graphics.line(pad.x - 10, pad.y, pad.x + 10, pad.y)
    love.graphics.setLineWidth(1)
  end
end

function M.drawPortal()
  local portalInfo = worldmap.getPortalInfo()
  local tile = worldmap.getCurrentTile()
  local centerX, centerY = gameState.width / 2, gameState.height / 2

  -- Portal swirl effect
  local time = love.timer.getTime()
  for i = 1, 8 do
    local angle = time * 2 + i * math.pi / 4
    local radius = 60 + math.sin(time * 3 + i) * 20
    local x = centerX + math.cos(angle) * radius
    local y = centerY + math.sin(angle) * radius

    love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 0.6)
    love.graphics.circle("fill", x, y, 10 + math.sin(time * 4 + i) * 5)
  end

  -- Portal core
  love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 0.8)
  love.graphics.circle("fill", centerX, centerY, 50 + math.sin(time * 2) * 10)

  love.graphics.setColor(1, 1, 1, 0.5)
  love.graphics.circle("fill", centerX, centerY, 30)

  -- Portal name above
  love.graphics.setColor(1, 1, 1)
  local name = portalInfo.name
  local font = love.graphics.getFont()
  local nameWidth = font:getWidth(name)
  love.graphics.print(name, centerX - nameWidth / 2, centerY - 100)
end

function M.drawHUD()
  -- Health bar
  local healthPercent = gameState.health / gameState.maxHealth
  love.graphics.setColor(0.2, 0.2, 0.2)
  love.graphics.rectangle("fill", 10, 10, 200, 20)
  love.graphics.setColor(0.2, 0.8, 0.3)
  love.graphics.rectangle("fill", 10, 10, 200 * healthPercent, 20)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", 10, 10, 200, 20)

  -- Score
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Score: " .. gameState.score, 10, 35)

  -- Tile coordinates
  love.graphics.setColor(0.7, 0.7, 0.8)
  local tile = worldmap.getCurrentTile()
  local coords = "(" .. worldmap.tileX .. ", " .. worldmap.tileY .. ")"
  love.graphics.print(tile.name .. " " .. coords, 10, 55)

  -- Minimap
  M.drawMinimap()
end

function M.drawMinimap()
  local mapX = gameState.width - 120
  local mapY = 10
  local cellSize = 14
  local mapSize = 7 * cellSize

  -- Background
  love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
  love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize)

  -- Grid cells
  for x = worldmap.GRID_MIN, worldmap.GRID_MAX do
    for y = worldmap.GRID_MIN, worldmap.GRID_MAX do
      local tile = worldmap.getTile(x, y)
      local drawX = mapX + (x + 3) * cellSize
      local drawY = mapY + (y + 3) * cellSize

      if tile.type == worldmap.TILE_STATION then
        love.graphics.setColor(0.4, 0.6, 0.9, 0.8)
      elseif tile.type == worldmap.TILE_PORTAL then
        love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 0.8)
      else
        love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
      end

      love.graphics.rectangle("fill", drawX + 1, drawY + 1, cellSize - 2, cellSize - 2)
    end
  end

  -- Current position marker
  local playerX = mapX + (worldmap.tileX + 3) * cellSize + cellSize / 2
  local playerY = mapY + (worldmap.tileY + 3) * cellSize + cellSize / 2

  love.graphics.setColor(1, 1, 0)
  love.graphics.circle("fill", playerX, playerY, 4)

  -- Border
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.rectangle("line", mapX, mapY, mapSize, mapSize)
end

function M.drawLandingUI()
  local helipads = worldmap.getHelipads()
  if not landingState.selectedPad then return end

  local pad = helipads[landingState.selectedPad]

  -- Landing progress bar
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", pad.x - 50, pad.y + 50, 100, 15)

  love.graphics.setColor(0.3, 0.9, 0.4)
  love.graphics.rectangle("fill", pad.x - 50, pad.y + 50, math.min(100, 100 * (landingState.landingProgress / 1.5)), 15)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", pad.x - 50, pad.y + 50, 100, 15)

  -- Instructions
  love.graphics.setColor(1, 1, 1)
  local text = "Slow down to land..."
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(text)
  love.graphics.print(text, pad.x - textWidth / 2, pad.y + 70)
end

function M.drawPortalUI()
  if not portalState.portalInfo then return end

  local centerX = gameState.width / 2
  local centerY = gameState.height / 2

  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", centerX - 100, centerY + 80, 200, 40)

  love.graphics.setColor(1, 1, 1)
  local text = "Press ENTER to warp"
  local font = love.graphics.getFont()
  local textWidth = font:getWidth(text)
  love.graphics.print(text, centerX - textWidth / 2, centerY + 90)
end

function M.drawPlaying()
  -- Draw nebula background
  nebula.draw(gameState.width, gameState.height)

  -- Draw tile-specific content
  if worldmap.isAtStation() then
    M.drawStation()
  elseif worldmap.isAtPortal() then
    M.drawPortal()
  end

  local color = gameState.level.color
  if not gameState.ship.dead then
    M.drawStarfoxShip(gameState.ship)
  end

  for _, a in ipairs(gameState.asteroids) do
    ui.drawAsteroid(a, color)
  end

  for _, b in ipairs(gameState.bullets) do
    ui.drawBullet(b)
  end

  for _, u in ipairs(gameState.ufos) do
    ui.drawUFO(u)
  end

  for _, p in ipairs(gameState.powerups) do
    ui.drawPowerup(p)
  end

  for _, p in ipairs(gameState.particles) do
    ui.drawParticle(p)
  end

  -- Draw HUD with tile info
  M.drawHUD()

  -- Draw landing UI
  if landingState.hovering then
    M.drawLandingUI()
  end

  -- Draw portal interaction UI
  if portalState.nearPortal then
    M.drawPortalUI()
  end

  -- Draw edge hit effect
  if edgeHitState.active then
    M.drawEdgeHit()
  end
end

function M.drawPauseMenu()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)

  -- Title
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.setNewFont(36)
  love.graphics.printf("PAUSED", 0, 250, gameState.width, "center")

  -- Menu options
  love.graphics.setNewFont(20)
  local options = {"Resume", "Options", "Exit to Station"}
  local startY = 350

  for i, option in ipairs(options) do
    if i == gameState.pauseMenuIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * 40, gameState.width, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(option, 0, startY + (i - 1) * 40, gameState.width, "center")
    end
  end

  -- Instructions
  love.graphics.setNewFont(14)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 550, gameState.width, "center")
end

function M.drawEdgeHit()
  local progress = edgeHitState.timer / edgeHitState.duration
  local alpha = 1.0 - progress

  -- Blue flash at impact point with bloom layers
  for i = 3, 1, -1 do
    local radius = 40 + (i * 20) + (progress * 60)
    local layerAlpha = alpha * 0.3 * (4 - i) / 3
    love.graphics.setColor(0.3, 0.5, 1, layerAlpha)
    love.graphics.circle("fill", edgeHitState.hitX, edgeHitState.hitY, radius)
  end

  -- Core flash
  love.graphics.setColor(0.6, 0.8, 1, alpha * 0.6)
  love.graphics.circle("fill", edgeHitState.hitX, edgeHitState.hitY, 25)

  -- Draw particles
  for _, p in ipairs(edgeHitState.particles) do
    local pAlpha = p.life / 0.5
    love.graphics.setColor(0.4, 0.7, 1, pAlpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
  end
end

function M.keypressed(key)
  if gameState.state == "paused" then
    if key == "escape" then
      gameState.state = "playing"
    elseif key == "up" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex - 1
      if gameState.pauseMenuIndex < 1 then
        gameState.pauseMenuIndex = 3
      end
    elseif key == "down" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex + 1
      if gameState.pauseMenuIndex > 3 then
        gameState.pauseMenuIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.pauseMenuIndex == 1 then
        -- Resume
        gameState.state = "playing"
      elseif gameState.pauseMenuIndex == 2 then
        -- Options (placeholder)
        gameState.state = "playing"  -- For now, just resume
      elseif gameState.pauseMenuIndex == 3 then
        -- Exit to Station with fade
        M.startFade(function()
          if M.returnToHub then
            M.returnToHub()
          end
        end)
      end
    end
  elseif gameState.state == "game_over" and key == "r" then
    M.startGame()
  elseif gameState.state == "playing" then
    if key == "escape" then
      gameState.state = "paused"
      gameState.pauseMenuIndex = 1
    elseif key == "return" or key == "space" then
      -- Check for portal warp
      if portalState.nearPortal and portalState.portalInfo and not warpState.active then
        -- Store the tile we're warping from
        portalEntryTile.x = worldmap.tileX
        portalEntryTile.y = worldmap.tileY
        
        local levelId = portalState.portalInfo.starfoxLevelId
        M.startWarp(levelId, function()
          if M.enterStarfox then
            M.enterStarfox(levelId)
          end
        end)
      elseif key == "space" and not gameState.ship.dead and not warpState.active and ship.shoot(gameState.ship) then
        local cos = math.cos(gameState.ship.angle)
        local sin = math.sin(gameState.ship.angle)
        local bx = gameState.ship.x + cos * gameState.ship.size
        local by = gameState.ship.y + sin * gameState.ship.size

        table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle, "player"))
      end
    elseif key == "x" and not gameState.ship.dead then
      local damaged = ship.hyperspace(gameState.ship, gameState.width, gameState.height)
      if damaged then
        gameState.health = gameState.health - 50
      end
    end
  end
end

return M
