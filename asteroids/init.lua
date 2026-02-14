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
local patrol = require("asteroids.patrol")
local wanted = require("asteroids.wanted")
local constellation = require("asteroids.constellation")
local puzzle = require("asteroids.puzzle")

local gameState = {}

-- Callbacks for hub integration
M.returnToHub = nil
M.enterStarfox = nil
M.goToMixiaPD = nil  -- Called when busted → spawn at Mixia L4 Galaxy PD HQ

-- Portal entry tracking
local portalEntryTile = {
  x = 0,
  y = 0
}

-- Mega Antenna acquisition overlay state
M.pendingMegaAntenna = false
local antennaOverlay = {
  phase = "none",       -- "none", "acquisition", "transmission", "done"
  timer = 0,
  fadeAlpha = 0,
  antennaGlow = 0,
  transmissionLine = 0,
  transmissionLines = {
    "INCOMING TRANSMISSION...",
    "",
    '"Great job, mate!"',
    '"When you get back to Hometown"',
    '"let\'s get this fired up!"',
    "",
    "— The Director"
  }
}

-- Power Amplifier acquisition overlay state
M.pendingPowerAmplifier = false
local amplifierOverlay = {
  phase = "none",       -- "none", "acquisition", "transmission", "done"
  timer = 0,
  fadeAlpha = 0,
  amplifierGlow = 0,
  transmissionLine = 0,
  transmissionLines = {
    "INCOMING TRANSMISSION...",
    "",
    '"Outstanding work!"',
    '"The Power Amplifier will"',
    '"supercharge our comms array."',
    '"Bring it home!"',
    "",
    "— The Director"
  }
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

-- Constellation hazard state
local hazardState = {
  coldActive = false,       -- Oort Cloud cold damage
  hotActive = false,        -- Pandora hot sector damage
  gravityActive = false,    -- Gargantua gravity pull
  gravityDX = 0,
  gravityDY = 0,
  pulsarWarning = false,    -- Vela pulsar warning
  pulsarBurst = false,      -- Vela pulsar burst active
  pulsarTimeLeft = 0,       -- Time until next burst
  pulsarBurstProgress = 0,  -- Burst animation progress
}

-- Time slow effect (from powerup)
local timeSlowState = {
  active = false,
  timer = 0,
  duration = 0,
  factor = 0.35,  -- 35% speed
}

-- Space event system (random encounters)
local spaceEventState = {
  timer = 0,
  interval = 25,  -- seconds between event checks
  activeEvent = nil,
  eventTimer = 0,
  eventData = {},
  messageTimer = 0,
  message = "",
  messageColor = {1,1,1},
}

-- Powerup pickup message popups
local pickupMessages = {}

-- Combo score tracking
local comboState = {
  count = 0,
  timer = 0,
  maxTimer = 2.5,  -- seconds to keep combo alive
  multiplier = 1,
  displayTimer = 0,
}

-- Smart bomb state (two-press: launch then detonate)
local bombState = {
  -- Projectile phase (B press #1)
  launched = false,
  projX = 0,
  projY = 0,
  projVX = 0,
  projVY = 0,
  projAngle = 0,
  projTimer = 0,
  projPulse = 0,
  -- Explosion phase (B press #2)
  active = false,
  timer = 0,
  duration = 1.5,
  x = 0,
  y = 0,
  rings = {},
  flash = 0,
}

-- Missile AOE explosion state (visual effects queue)
local missileExplosions = {}
local MISSILE_AOE_RADIUS = 120
local MISSILE_DAMAGE_MULT = 2.0  -- Missiles deal 2x damage to asteroids (instant split)

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

-- Set map progression from hub state
function M.setProgression(antennaInstalled, sentinelDefeated)
  worldmap.setProgression(antennaInstalled, sentinelDefeated)
end

-- Refresh missiles to max (called when returning from Hometown Station)
function M.refreshMissiles()
  if gameState.ship then
    gameState.ship.missiles = gameState.ship.maxMissiles
  end
end

function M.restoreFromPortal()
  -- Sync scan unlock (player may have just bought Scanner at Singularity)
  puzzle.syncScanUnlock()

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

  -- Check if Mega Antenna was just acquired
  if M.pendingMegaAntenna then
    M.pendingMegaAntenna = false
    antennaOverlay.phase = "acquisition"
    antennaOverlay.timer = 0
    antennaOverlay.fadeAlpha = 0
    antennaOverlay.antennaGlow = 0
    antennaOverlay.transmissionLine = 0
  end

  -- Check if Power Amplifier was just acquired
  if M.pendingPowerAmplifier then
    M.pendingPowerAmplifier = false
    amplifierOverlay.phase = "acquisition"
    amplifierOverlay.timer = 0
    amplifierOverlay.fadeAlpha = 0
    amplifierOverlay.amplifierGlow = 0
    amplifierOverlay.transmissionLine = 0
  end
end

function M.startGame()
  local shipDef = starfoxShips.getSelectedDef()

  -- Preserve missile state across restarts
  local prevMaxMissiles = gameState.ship and gameState.ship.maxMissiles or 0
  local prevMissiles = gameState.ship and gameState.ship.missiles or 0

  gameState.ship = ship.new(gameState.width / 2, gameState.height / 2)
  gameState.ship.shipType = starfoxShips.getSelected()
  gameState.ship.shipColor = shipDef.color
  gameState.ship.accentColor = shipDef.accentColor

  -- Restore missile state
  gameState.ship.maxMissiles = prevMaxMissiles
  gameState.ship.missiles = prevMissiles

  gameState.bullets = {}
  gameState.asteroids = {}
  gameState.ufos = {}
  gameState.powerups = {}
  gameState.particles = {}
  missileExplosions = {}
  gameState.level = level.new()
  gameState.score = 0
  gameState.health = 100 * shipDef.healthMultiplier
  gameState.maxHealth = gameState.health
  gameState.damageTimer = 0
  gameState.notes = gameState.notes or 100  -- Preserve notes across games, default 100

  -- Reset wanted system
  wanted.reset()

  -- Reset worldmap to center
  worldmap.init()

  -- Regenerate nebula for starting tile
  nebula.init(gameState.width, gameState.height, 0, 0)

  -- Initialize puzzle system and sync scan unlock from shop
  puzzle.initAssignments()
  puzzle.syncScanUnlock()

  -- Spawn asteroids based on current tile
  M.spawnTileContent()

  -- Save missile count at stage entry (for Restart Level)
  gameState.ship.missileEntryCount = gameState.ship.missiles

  gameState.state = "playing"
end

function M.spawnTileContent()
  local tile = worldmap.getCurrentTile()
  local baseCount = 4 + gameState.level.number * 2
  local cId = constellation.getConstellationId(worldmap.tileX, worldmap.tileY)
  local isOort = (cId == "oort")

  if tile.type == worldmap.TILE_STATION then
    gameState.asteroids = {}
  elseif tile.type == worldmap.TILE_PORTAL then
    local count = worldmap.getAsteroidCount(baseCount)
    gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count, isOort)
  else
    local count = worldmap.getAsteroidCount(baseCount)
    gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count, isOort)
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

  -- Try to spawn patrol robots (1/10 chance, only if no existing patrols)
  if tile.type ~= worldmap.TILE_STATION then
    wanted.trySpawnOnTileLoad(gameState.width, gameState.height)
  end

  -- Activate puzzle if this tile has one
  puzzle.rewardDrop = nil  -- Clear any previous reward
  puzzle.activatePuzzle(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)
end

function M.transitionToTile(newX, newY, shipWrapX, shipWrapY)
  worldmap.setPosition(newX, newY)
  local oldShipX = gameState.ship.x
  local oldShipY = gameState.ship.y
  gameState.ship.x = shipWrapX
  gameState.ship.y = shipWrapY
  M.spawnTileContent()

  -- Move patrols by the same offset so they follow the player between tiles
  local dx = shipWrapX - oldShipX
  local dy = shipWrapY - oldShipY
  for _, p in ipairs(wanted.patrols) do
    if not p.dead then
      p.x = p.x + dx
      p.y = p.y + dy
    end
  end

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

  -- Update antenna overlay (blocks all other input/gameplay)
  if antennaOverlay.phase ~= "none" and antennaOverlay.phase ~= "done" then
    M.updateAntennaOverlay(dt)
    return
  end

  -- Update amplifier overlay (blocks all other input/gameplay)
  if amplifierOverlay.phase ~= "none" and amplifierOverlay.phase ~= "done" then
    M.updateAmplifierOverlay(dt)
    return
  end

  if gameState.state == "paused" then
    return  -- Don't update game logic when paused
  end

  if gameState.state == "playing" then
    -- Don't update gameplay during busted/dialogue
    if not wanted.bustedState and not wanted.dialogueActive and not wanted.sentenceActive then
      M.updatePlaying(dt)
    elseif wanted.bustedState then
      -- Still update busted state
      gameState.notes = wanted.updateBusted(dt, gameState.notes)
      -- Still update patrols minimally during busted
      for _, p in ipairs(wanted.patrols) do
        if not p.dead then
          p.vx = 0
          p.vy = 0
        end
      end
    elseif wanted.sentenceActive then
      -- Sentence countdown is handled inside wanted.updateBusted
      gameState.notes = wanted.updateBusted(dt, gameState.notes)
      -- Auto-advance dialogue when sentence timer runs out
      if not wanted.sentenceActive or wanted.sentenceTimer <= 0 then
        if wanted.dialogueCallback then
          gameState.notes = wanted.advanceDialogue(gameState.width, gameState.height, gameState.notes)
        end
      end
    end

    if not gameState.ship.dead and not gameState.ship.exploding and not wanted.bustedState and not wanted.dialogueActive then
      if love.keyboard.isDown("left") then
        ship.rotate(gameState.ship, -1, dt)
      end
      if love.keyboard.isDown("right") then
        ship.rotate(gameState.ship, 1, dt)
      end
      if love.keyboard.isDown("up") then
        ship.thrust(gameState.ship, dt)
      end
      if love.keyboard.isDown("down") then
        ship.decelerate(gameState.ship, dt)
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

  -- ===== CONSTELLATION HAZARD UPDATES =====
  M.updateConstellationHazards(dt)

  -- ===== PUZZLE SYSTEM UPDATE =====
  -- Scan hold detection (S key while not using toggle shield)
  puzzle.scanActive = puzzle.scanUnlocked and love.keyboard.isDown("s") and not gameState.ship.dead and not gameState.ship.exploding
  
  local puzzleResult = puzzle.updatePuzzle(
    worldmap.tileX, worldmap.tileY, dt,
    gameState.ship.x, gameState.ship.y,
    gameState.bullets,
    gameState.width, gameState.height
  )
  -- Handle puzzle results
  if puzzleResult == "torpedo_pod" then
    -- Increase max missile capacity as torpedo pod reward
    gameState.ship.maxMissiles = gameState.ship.maxMissiles + 3
    gameState.ship.missiles = gameState.ship.missiles + 3
  elseif puzzleResult == "shield_cell" then
    -- Increase max shield energy
    gameState.ship.shieldMaxEnergy = gameState.ship.shieldMaxEnergy + 25
    gameState.ship.shieldEnergy = math.min(gameState.ship.shieldMaxEnergy, gameState.ship.shieldEnergy + 25)
  elseif puzzleResult == "heat_damage" then
    if not gameState.ship.shieldActive then
      gameState.health = gameState.health - 5 * dt
      if gameState.health <= 0 then
        ship.die(gameState.ship)
      end
    end
  elseif puzzleResult == "boulder_hit" then
    gameState.health = gameState.health - 20
    gameState.damageTimer = 3
    if gameState.health <= 0 then
      ship.die(gameState.ship)
    end
  elseif puzzleResult == "dart_hit" then
    gameState.health = gameState.health - 10
    gameState.damageTimer = 3
    if gameState.health <= 0 then
      ship.die(gameState.ship)
    end
  elseif puzzleResult == "pulsar_hit" then
    if not gameState.ship.shieldActive then
      gameState.health = gameState.health - 30
      gameState.damageTimer = 3
      if gameState.health <= 0 then
        ship.die(gameState.ship)
      end
    else
      gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - 40
      if gameState.ship.shieldEnergy <= 0 then
        gameState.ship.shieldEnergy = 0
        gameState.ship.shieldActive = false
      end
    end
  end
  -- Handle boss projectile collisions with player
  if type(puzzleResult) == "table" then
    for i = #puzzleResult, 1, -1 do
      local p = puzzleResult[i]
      if not gameState.ship.dead and not gameState.ship.exploding and not gameState.ship.invulnerable then
        local dist = math.sqrt((gameState.ship.x - p.x)^2 + (gameState.ship.y - p.y)^2)
        if dist < gameState.ship.size + p.size then
          if gameState.ship.shieldActive then
            gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - 15
            if gameState.ship.shieldEnergy <= 0 then
              gameState.ship.shieldEnergy = 0
              gameState.ship.shieldActive = false
            end
          else
            gameState.health = gameState.health - 15
            gameState.damageTimer = 3
            if gameState.health <= 0 then
              ship.die(gameState.ship)
            end
          end
          gameState.ship.shieldTimer = 0.3
          gameState.ship.invulnerable = true
          table.remove(puzzleResult, i)
        end
      end
    end
  end

  -- ===== TIME SLOW EFFECT =====
  local dtEff = dt
  if timeSlowState.active then
    timeSlowState.timer = timeSlowState.timer - dt
    if timeSlowState.timer <= 0 then
      timeSlowState.active = false
    else
      dtEff = dt * timeSlowState.factor  -- Slow enemies/asteroids
    end
  end

  -- ===== COMBO TIMER =====
  if comboState.timer > 0 then
    comboState.timer = comboState.timer - dt
    if comboState.timer <= 0 then
      comboState.count = 0
      comboState.multiplier = 1
    end
  end
  if comboState.displayTimer > 0 then
    comboState.displayTimer = comboState.displayTimer - dt
  end

  -- ===== MAGNET POWERUP: Attract nearby powerups =====
  if ship.hasMagnet(gameState.ship) then
    for _, p in ipairs(gameState.powerups) do
      local dx = gameState.ship.x - p.x
      local dy = gameState.ship.y - p.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 300 and dist > 5 then
        local pull = 200 / dist
        p.x = p.x + (dx / dist) * pull * dt * 60
        p.y = p.y + (dy / dist) * pull * dt * 60
      end
    end
  end

  -- ===== PICKUP MESSAGE POPUPS =====
  for i = #pickupMessages, 1, -1 do
    local msg = pickupMessages[i]
    msg.timer = msg.timer - dt
    msg.y = msg.y - 30 * dt
    if msg.timer <= 0 then
      table.remove(pickupMessages, i)
    end
  end

  -- ===== SPACE EVENTS =====
  M.updateSpaceEvents(dtEff)

  for i = #gameState.bullets, 1, -1 do
    bullet.update(gameState.bullets[i], dt)
    bullet.wrap(gameState.bullets[i], gameState.width, gameState.height)

    if not bullet.isAlive(gameState.bullets[i]) then
      table.remove(gameState.bullets, i)
    end
  end

  for _, a in ipairs(gameState.asteroids) do
    asteroid.update(a, dtEff)
    asteroid.wrap(a, gameState.width, gameState.height)
  end

  for i = #gameState.ufos, 1, -1 do
    local u = gameState.ufos[i]
    ufo.update(u, dtEff)

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

  -- Update patrol robots
  M.updatePatrols(dt)

  -- Update smart bomb effect
  M.updateSmartBomb(dt)

  -- Update missile AOE explosions
  M.updateMissileExplosions(dt)

  -- Update wanted/busted system
  if wanted.bustedState then
    gameState.notes = wanted.updateBusted(dt, gameState.notes)
  end

  -- Update agent sayonara sequence
  if wanted.agentSayonara then
    local done = wanted.updateAgentSayonara(dt)
    if done then
      wanted.agentSayonara = false
      -- Agent punished the player, clear wanted
      wanted.stars = 0
      wanted.clearAllPatrols()
    end
  end

  -- Check if busted sequence ended and player should be sent to Mixia PD HQ
  if wanted.sendToMixiaPD then
    wanted.sendToMixiaPD = false
    M.startFade(function()
      if M.goToMixiaPD then
        M.goToMixiaPD()
      end
    end)
  end

  if gameState.ship.lives <= 0 and not gameState.ship.exploding then
    gameState.state = "game_over"
  end

  -- Reset health when ship respawns after explosion
  if not gameState.ship.dead and not gameState.ship.exploding and gameState.health <= 0 and gameState.ship.lives > 0 then
    gameState.health = gameState.maxHealth
  end
end

-- Launch a bomb projectile from the ship (B press #1)
function M.launchBomb()
  local BOMB_SPEED = 120  -- slow-moving projectile
  bombState.launched = true
  bombState.projX = gameState.ship.x
  bombState.projY = gameState.ship.y
  bombState.projAngle = gameState.ship.angle
  bombState.projVX = math.cos(gameState.ship.angle) * BOMB_SPEED
  bombState.projVY = math.sin(gameState.ship.angle) * BOMB_SPEED
  bombState.projTimer = 0
  bombState.projPulse = 0
end

-- Detonate the bomb at its current position (B press #2)
function M.triggerSmartBomb()
  bombState.launched = false
  bombState.active = true
  bombState.timer = 0
  bombState.x = bombState.projX
  bombState.y = bombState.projY
  bombState.flash = 1.0
  bombState.rings = {}

  -- Create expanding shockwave rings
  for i = 1, 5 do
    table.insert(bombState.rings, {
      radius = 0,
      maxRadius = 200 + i * 150,
      speed = 400 + i * 100,
      alpha = 1.0,
      delay = (i - 1) * 0.08,
      started = false,
      color = i <= 2 and {1, 0.9, 0.5} or (i <= 4 and {0.3, 0.5, 1} or {0.8, 0.3, 1})
    })
  end

  -- Destroy all asteroids
  for _, a in ipairs(gameState.asteroids) do
    for _, p in ipairs(particle.new(a.x, a.y)) do
      table.insert(gameState.particles, p)
    end
    local _, score = asteroid.split(a)
    gameState.score = gameState.score + score
  end
  gameState.asteroids = {}

  -- Destroy all UFOs
  for _, u in ipairs(gameState.ufos) do
    for _, p in ipairs(particle.new(u.x, u.y)) do
      table.insert(gameState.particles, p)
    end
    gameState.score = gameState.score + u.score
  end
  gameState.ufos = {}

  -- Clear enemy bullets
  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]
    if b.owner ~= "player" then
      table.remove(gameState.bullets, i)
    end
  end
end

function M.updateSmartBomb(dt)
  -- Update flying bomb projectile
  if bombState.launched then
    bombState.projTimer = bombState.projTimer + dt
    bombState.projPulse = bombState.projPulse + dt * 5

    -- Move the bomb
    bombState.projX = bombState.projX + bombState.projVX * dt
    bombState.projY = bombState.projY + bombState.projVY * dt

    -- Wrap around screen edges
    if bombState.projX < 0 then bombState.projX = bombState.projX + gameState.width end
    if bombState.projX > gameState.width then bombState.projX = bombState.projX - gameState.width end
    if bombState.projY < 0 then bombState.projY = bombState.projY + gameState.height end
    if bombState.projY > gameState.height then bombState.projY = bombState.projY - gameState.height end

    -- Auto-detonate after 8 seconds if player forgets
    if bombState.projTimer >= 8.0 then
      M.triggerSmartBomb()
    end
  end

  -- Update explosion effect
  if not bombState.active then return end

  bombState.timer = bombState.timer + dt
  bombState.flash = math.max(0, bombState.flash - dt * 2)

  -- Update rings
  for _, ring in ipairs(bombState.rings) do
    if bombState.timer >= ring.delay then
      ring.started = true
    end
    if ring.started then
      ring.radius = ring.radius + ring.speed * dt
      ring.alpha = math.max(0, 1.0 - (ring.radius / ring.maxRadius))
    end
  end

  if bombState.timer >= bombState.duration then
    bombState.active = false
  end
end

function M.drawSmartBomb()
  -- Draw flying bomb projectile
  if bombState.launched then
    local bx, by = bombState.projX, bombState.projY
    local pulse = math.sin(bombState.projPulse) * 0.3

    -- Outer danger glow (pulsing)
    love.graphics.setColor(1, 0.4, 0, 0.2 + pulse * 0.15)
    love.graphics.circle("fill", bx, by, 18 + pulse * 4)

    -- Main bomb body
    love.graphics.setColor(0.5, 0.5, 0.55, 1)
    love.graphics.circle("fill", bx, by, 8)

    -- Dark band (equator line)
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.3, 0.3, 0.35, 1)
    love.graphics.circle("line", bx, by, 8)

    -- Blinking red warning light
    local blink = math.sin(bombState.projPulse * 2) > 0
    if blink then
      love.graphics.setColor(1, 0.1, 0.1, 0.9)
      love.graphics.circle("fill", bx, by - 3, 2.5)
    end

    -- Small exhaust trail behind the bomb
    local trailAngle = bombState.projAngle + math.pi
    for i = 1, 3 do
      local tx = bx + math.cos(trailAngle) * (10 + i * 5)
      local ty = by + math.sin(trailAngle) * (10 + i * 5)
      local trailAlpha = (0.5 - i * 0.15)
      love.graphics.setColor(1, 0.6, 0.2, trailAlpha)
      love.graphics.circle("fill", tx, ty, 3 - i * 0.5)
    end

    love.graphics.setLineWidth(1)
  end

  -- Draw explosion effect
  if not bombState.active then return end

  -- Screen flash
  if bombState.flash > 0 then
    love.graphics.setColor(1, 1, 1, bombState.flash * 0.6)
    love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)
  end

  -- Draw shockwave rings
  for _, ring in ipairs(bombState.rings) do
    if ring.started and ring.alpha > 0 then
      love.graphics.setLineWidth(3 + ring.alpha * 4)
      love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.alpha * 0.8)
      love.graphics.circle("line", bombState.x, bombState.y, ring.radius)
      -- Inner glow
      love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.alpha * 0.15)
      love.graphics.circle("fill", bombState.x, bombState.y, ring.radius)
    end
  end

  -- Central explosion glow
  local progress = bombState.timer / bombState.duration
  if progress < 0.3 then
    local glowAlpha = 1.0 - progress / 0.3
    local glowSize = 30 + progress * 200
    love.graphics.setColor(1, 1, 1, glowAlpha * 0.9)
    love.graphics.circle("fill", bombState.x, bombState.y, glowSize * 0.3)
    love.graphics.setColor(1, 0.7, 0.2, glowAlpha * 0.6)
    love.graphics.circle("fill", bombState.x, bombState.y, glowSize * 0.6)
    love.graphics.setColor(0.3, 0.5, 1, glowAlpha * 0.3)
    love.graphics.circle("fill", bombState.x, bombState.y, glowSize)
  end

  love.graphics.setLineWidth(1)
end

-- ===== MISSILE AOE SYSTEM =====

function M.triggerMissileExplosion(x, y)
  -- Create visual explosion
  local explosion = {
    x = x, y = y,
    timer = 0,
    duration = 0.8,
    rings = {},
    flash = 0.6,
  }
  -- Create 3 expanding rings (orange/red theme)
  for i = 1, 3 do
    table.insert(explosion.rings, {
      radius = 0,
      maxRadius = MISSILE_AOE_RADIUS * (0.5 + i * 0.25),
      speed = 300 + i * 80,
      alpha = 1.0,
      delay = (i - 1) * 0.05,
      started = false,
      color = i == 1 and {1, 0.9, 0.4} or (i == 2 and {1, 0.5, 0.1} or {0.8, 0.2, 0.05})
    })
  end
  table.insert(missileExplosions, explosion)

  -- AOE damage: destroy/split all asteroids within radius
  for j = #gameState.asteroids, 1, -1 do
    local a = gameState.asteroids[j]
    local dist = math.sqrt((x - a.x)^2 + (y - a.y)^2)
    if dist < MISSILE_AOE_RADIUS then
      local splits, score = asteroid.split(a)
      gameState.score = gameState.score + score
      for _, split in ipairs(splits) do
        table.insert(gameState.asteroids, split)
      end
      for _, p in ipairs(particle.new(a.x, a.y)) do
        table.insert(gameState.particles, p)
      end
      table.remove(gameState.asteroids, j)
    end
  end

  -- AOE damage: destroy UFOs within radius
  for j = #gameState.ufos, 1, -1 do
    local u = gameState.ufos[j]
    local dist = math.sqrt((x - u.x)^2 + (y - u.y)^2)
    if dist < MISSILE_AOE_RADIUS then
      gameState.score = gameState.score + u.score
      for _, p in ipairs(particle.new(u.x, u.y)) do
        table.insert(gameState.particles, p)
      end
      table.insert(gameState.powerups, powerup.new(u.x, u.y))
      table.remove(gameState.ufos, j)
    end
  end
end

function M.updateMissileExplosions(dt)
  for i = #missileExplosions, 1, -1 do
    local e = missileExplosions[i]
    e.timer = e.timer + dt
    e.flash = math.max(0, e.flash - dt * 3)

    for _, ring in ipairs(e.rings) do
      if e.timer >= ring.delay then
        ring.started = true
      end
      if ring.started then
        ring.radius = ring.radius + ring.speed * dt
        ring.alpha = math.max(0, 1.0 - (ring.radius / ring.maxRadius))
      end
    end

    if e.timer >= e.duration then
      table.remove(missileExplosions, i)
    end
  end
end

function M.drawMissileExplosions()
  for _, e in ipairs(missileExplosions) do
    -- Screen flash (localized)
    if e.flash > 0 then
      love.graphics.setColor(1, 0.7, 0.3, e.flash * 0.3)
      love.graphics.circle("fill", e.x, e.y, MISSILE_AOE_RADIUS * 1.5)
    end

    -- Draw shockwave rings
    for _, ring in ipairs(e.rings) do
      if ring.started and ring.alpha > 0 then
        love.graphics.setLineWidth(2 + ring.alpha * 3)
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.alpha * 0.7)
        love.graphics.circle("line", e.x, e.y, ring.radius)
        love.graphics.setColor(ring.color[1], ring.color[2], ring.color[3], ring.alpha * 0.1)
        love.graphics.circle("fill", e.x, e.y, ring.radius)
      end
    end

    -- Central fireball
    local progress = e.timer / e.duration
    if progress < 0.4 then
      local glowAlpha = 1.0 - progress / 0.4
      local glowSize = 15 + progress * 80
      love.graphics.setColor(1, 1, 0.9, glowAlpha * 0.8)
      love.graphics.circle("fill", e.x, e.y, glowSize * 0.3)
      love.graphics.setColor(1, 0.5, 0.1, glowAlpha * 0.5)
      love.graphics.circle("fill", e.x, e.y, glowSize * 0.7)
      love.graphics.setColor(0.8, 0.2, 0, glowAlpha * 0.3)
      love.graphics.circle("fill", e.x, e.y, glowSize)
    end
  end
  love.graphics.setLineWidth(1)
end

function M.drawShield()
  if not gameState.ship.shieldActive or gameState.ship.dead or gameState.ship.exploding then return end

  local sx, sy = gameState.ship.x, gameState.ship.y
  local radius = gameState.ship.size * 1.8
  local energyPct = gameState.ship.shieldEnergy / gameState.ship.shieldMaxEnergy
  local pulse = math.sin(love.timer.getTime() * 6) * 0.15

  -- Outer shield bubble
  love.graphics.setColor(0.3, 0.6, 1, (0.25 + pulse) * energyPct)
  love.graphics.circle("fill", sx, sy, radius)
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0.4, 0.7, 1, (0.7 + pulse) * energyPct)
  love.graphics.circle("line", sx, sy, radius)

  -- Inner shimmer
  love.graphics.setColor(0.6, 0.9, 1, (0.15 + pulse * 0.5) * energyPct)
  love.graphics.circle("fill", sx, sy, radius * 0.7)

  -- Hex pattern (decorative)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.5, 0.8, 1, 0.2 * energyPct)
  local hexCount = 6
  local time = love.timer.getTime() * 0.5
  for i = 1, hexCount do
    local angle = (i / hexCount) * math.pi * 2 + time
    local hx = sx + math.cos(angle) * radius * 0.6
    local hy = sy + math.sin(angle) * radius * 0.6
    love.graphics.circle("line", hx, hy, 6)
  end

  love.graphics.setLineWidth(1)
end

function M.updatePatrols(dt)
  local chasing = wanted.stars >= 1

  for i = #wanted.patrols, 1, -1 do
    local p = wanted.patrols[i]
    patrol.update(p, dt, gameState.ship.x, gameState.ship.y, chasing)
    patrol.wrap(p, gameState.width, gameState.height)

    -- Handle shooting
    if p.shouldShoot then
      p.shouldShoot = false
      local b = bullet.new(p.x, p.y, p.shootAngle, "patrol")
      b.slowEffect = p.bulletSlow
      b.slowDuration = p.bulletSlowDuration
      b.patrolDamage = p.bulletDamage
      table.insert(gameState.bullets, b)
    end

    -- Handle tractor beam pull on ship
    if p.tractorActive and not gameState.ship.dead and not gameState.ship.exploding then
      local pullX, pullY = patrol.getTractorPull(p, gameState.ship.x, gameState.ship.y, ship.THRUST_ACCEL)
      gameState.ship.vx = gameState.ship.vx + pullX * dt
      gameState.ship.vy = gameState.ship.vy + pullY * dt
    end

    -- Check if patrol caught the player
    if patrol.checkCaught(p, gameState.ship.x, gameState.ship.y) and not gameState.ship.dead and not gameState.ship.exploding then
      p.state = "caught"
      p.tractorActive = false
      gameState.ship.vx = 0
      gameState.ship.vy = 0

      if p.patrolType == patrol.TYPE_AGENT then
        -- Agent catch = player destroyed, agent says sayonara
        ship.die(gameState.ship)
        wanted.onAgentDestroyedPlayer(p)
      elseif wanted.stars <= 2 then
        -- 1-2 stars: patrol pulls ship in and delivers warning dialogue in-game
        wanted.startWarningCatch(p)
      else
        -- 3+ stars: full busted sequence with Police HQ
        wanted.startBusted(p)
      end
    end

    -- Clean up finished explosions
    if p.dead and patrol.isExplosionDone(p) then
      table.remove(wanted.patrols, i)
    end
  end
end

-- ===================== SPACE EVENTS SYSTEM =====================
-- Random encounters that keep exploration interesting

local SPACE_EVENTS = {
  {
    name = "Asteroid Storm",
    weight = 25,
    duration = 15,
    init = function(data, w, h)
      data.spawnTimer = 0
      data.spawnInterval = 0.4
      data.waveCount = 0
      return "⚠ ASTEROID STORM INCOMING!"
    end,
    update = function(data, dt, w, h)
      data.spawnTimer = data.spawnTimer + dt
      if data.spawnTimer >= data.spawnInterval then
        data.spawnTimer = 0
        data.waveCount = data.waveCount + 1
        -- Spawn asteroids from random edge
        local side = math.random(4)
        local x, y
        if side == 1 then x, y = -30, math.random(h)
        elseif side == 2 then x, y = w + 30, math.random(h)
        elseif side == 3 then x, y = math.random(w), -30
        else x, y = math.random(w), h + 30 end
        local a = asteroid.new(x, y, math.random() < 0.3 and "large" or "medium")
        -- Aim somewhat toward center
        local angle = math.atan2(h/2 - y, w/2 - x) + (math.random() - 0.5) * 1.5
        local spd = 100 + math.random() * 150
        a.vx = math.cos(angle) * spd
        a.vy = math.sin(angle) * spd
        table.insert(gameState.asteroids, a)
      end
    end,
  },
  {
    name = "Supply Drop",
    weight = 20,
    duration = 0,  -- instant
    init = function(data, w, h)
      -- Drop 3-5 powerups in a cluster
      local cx = 100 + math.random() * (w - 200)
      local cy = 100 + math.random() * (h - 200)
      for i = 1, 3 + math.random(2) do
        local px = cx + (math.random() - 0.5) * 120
        local py = cy + (math.random() - 0.5) * 120
        table.insert(gameState.powerups, powerup.new(px, py))
      end
      return "📦 SUPPLY DROP DETECTED!"
    end,
  },
  {
    name = "UFO Ambush",
    weight = 15,
    duration = 0,
    init = function(data, w, h)
      local count = 2 + math.floor(math.random() * 3)
      for i = 1, count do
        local side = math.random() < 0.5 and -50 or w + 50
        local y = math.random(100, h - 100)
        table.insert(gameState.ufos, ufo.new(side, y))
      end
      return "⚠ UFO AMBUSH!"
    end,
  },
  {
    name = "Bonus Wave",
    weight = 15,
    duration = 0,
    init = function(data, w, h)
      -- Spawn many small asteroids worth bonus points
      for i = 1, 12 do
        local x = math.random(100, w - 100)
        local y = math.random(100, h - 100)
        local a = asteroid.new(x, y, "small")
        a.vx = (math.random() - 0.5) * 80
        a.vy = (math.random() - 0.5) * 80
        table.insert(gameState.asteroids, a)
      end
      -- Also drop a score powerup
      table.insert(gameState.powerups, powerup.new(w/2, h/2, "score"))
      return "💰 BONUS WAVE!"
    end,
  },
  {
    name = "Electromagnetic Pulse",
    weight = 10,
    duration = 5,
    init = function(data, w, h)
      data.pulseTimer = 0
      return "⚡ EMP DETECTED - Controls flickering!"
    end,
    update = function(data, dt, w, h)
      -- Periodically reverse controls briefly (visual flicker only in this impl)
      data.pulseTimer = data.pulseTimer + dt
    end,
  },
}

function M.updateSpaceEvents(dt)
  -- Don't run events at stations/portals
  if worldmap.isAtStation() or worldmap.isAtPortal() then return end

  -- Update message timer
  if spaceEventState.messageTimer > 0 then
    spaceEventState.messageTimer = spaceEventState.messageTimer - dt
  end

  -- Update active event
  if spaceEventState.activeEvent then
    spaceEventState.eventTimer = spaceEventState.eventTimer - dt
    local evt = spaceEventState.activeEvent
    if evt.update then
      evt.update(spaceEventState.eventData, dt, gameState.width, gameState.height)
    end
    if spaceEventState.eventTimer <= 0 then
      spaceEventState.activeEvent = nil
    end
    return
  end

  -- Check for new event
  spaceEventState.timer = spaceEventState.timer + dt
  if spaceEventState.timer >= spaceEventState.interval then
    spaceEventState.timer = 0
    spaceEventState.interval = 20 + math.random() * 30  -- Randomize next interval

    -- Roll for event (30% chance)
    if math.random() < 0.3 then
      -- Weighted selection
      local totalWeight = 0
      for _, evt in ipairs(SPACE_EVENTS) do
        totalWeight = totalWeight + evt.weight
      end
      local roll = math.random() * totalWeight
      local running = 0
      for _, evt in ipairs(SPACE_EVENTS) do
        running = running + evt.weight
        if roll <= running then
          spaceEventState.eventData = {}
          local msg = evt.init(spaceEventState.eventData, gameState.width, gameState.height)
          if evt.duration > 0 then
            spaceEventState.activeEvent = evt
            spaceEventState.eventTimer = evt.duration
          end
          spaceEventState.message = msg or evt.name
          spaceEventState.messageTimer = 3.0
          spaceEventState.messageColor = {1, 0.8, 0.2}
          break
        end
      end
    end
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
        -- Land - immediately transition to hub based on station type
        local stationInfo = worldmap.getStationInfo()
        -- Clear wanted when landing at a station
        wanted.clearWantedOnLand()
        -- Immediately return to hub without fade delay
        if M.returnToHub then
          M.returnToHub(stationInfo)
        end
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

        -- Combo system
        comboState.count = comboState.count + 1
        comboState.timer = comboState.maxTimer
        comboState.multiplier = 1 + math.floor(comboState.count / 5) * 0.5
        comboState.multiplier = math.min(comboState.multiplier, 4)
        if comboState.count >= 5 then
          comboState.displayTimer = 1.5
        end

        local finalScore = math.floor(score * comboState.multiplier)
        gameState.score = gameState.score + finalScore

        for _, split in ipairs(splits) do
          table.insert(gameState.asteroids, split)
        end

        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end

        -- Powerup drop from asteroids (small chance, higher for small asteroids)
        local dropChance = a.size == "small" and 0.15 or (a.size == "medium" and 0.08 or 0.04)
        if math.random() < dropChance then
          table.insert(gameState.powerups, powerup.new(a.x, a.y))
        end

        table.remove(gameState.asteroids, j)

        -- Missile AOE: splash damage nearby asteroids
        if b.isMissile then
          M.triggerMissileExplosion(b.x, b.y)
        end

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

        -- UFOs always drop powerups
        table.insert(gameState.powerups, powerup.new(u.x, u.y))

        table.remove(gameState.ufos, j)

        -- Missile AOE: splash damage nearby
        if b.isMissile then
          M.triggerMissileExplosion(b.x, b.y)
        end

        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  if not gameState.ship.invulnerable and not gameState.ship.dead and not gameState.ship.exploding then
    for j = #gameState.asteroids, 1, -1 do
      local a = gameState.asteroids[j]
      local dist = math.sqrt((gameState.ship.x - a.x)^2 + (gameState.ship.y - a.y)^2)

      if dist < asteroid.getRadius(a) + gameState.ship.size then
        if gameState.ship.shieldActive then
          -- Shield absorbs the hit, drain energy instead
          gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - 25
          if gameState.ship.shieldEnergy <= 0 then
            gameState.ship.shieldEnergy = 0
            gameState.ship.shieldActive = false
          end
        else
          -- Take 25 damage but don't die
          gameState.health = gameState.health - 25
          gameState.damageTimer = 3
        end

        -- Break the asteroid apart
        local splits, score = asteroid.split(a)
        gameState.score = gameState.score + score
        for _, split in ipairs(splits) do
          table.insert(gameState.asteroids, split)
        end
        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        table.remove(gameState.asteroids, j)

        -- Bounce ship away from asteroid
        local bx = gameState.ship.x - a.x
        local by = gameState.ship.y - a.y
        local blen = math.sqrt(bx * bx + by * by)
        if blen > 0 then
          gameState.ship.vx = gameState.ship.vx + (bx / blen) * 100
          gameState.ship.vy = gameState.ship.vy + (by / blen) * 100
        end

        -- Give brief invulnerability
        gameState.ship.shieldTimer = 0.5
        gameState.ship.invulnerable = true

        -- Check if health depleted - trigger explosion
        if not gameState.ship.shieldActive and gameState.health <= 0 then
          ship.die(gameState.ship)
        end
        break
      end
    end

    for i = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[i]

      if b.owner == "ufo" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)

        if dist < gameState.ship.size then
          if gameState.ship.shieldActive then
            gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - 15
            if gameState.ship.shieldEnergy <= 0 then
              gameState.ship.shieldEnergy = 0
              gameState.ship.shieldActive = false
            end
          else
            gameState.health = gameState.health - 15
            gameState.damageTimer = 3
          end
          table.remove(gameState.bullets, i)

          -- Check if health depleted
          if not gameState.ship.shieldActive and gameState.health <= 0 then
            ship.die(gameState.ship)
          end
        end
      end
    end
  end

  for i = #gameState.powerups, 1, -1 do
    local p = gameState.powerups[i]
    local dist = math.sqrt((gameState.ship.x - p.x)^2 + (gameState.ship.y - p.y)^2)

    if dist < gameState.ship.size + p.size then
      local result = powerup.apply(p, gameState.ship)
      if result then
        if result.health then
          gameState.health = math.min(gameState.maxHealth, gameState.health + result.health)
        end
        if result.score then
          gameState.score = gameState.score + result.score
        end
        if result.timeslow then
          timeSlowState.active = true
          timeSlowState.timer = result.timeslow
          timeSlowState.duration = result.timeslow
        end
      end
      -- Show pickup message
      local pType = powerup.TYPES[p.type]
      if pType then
        table.insert(pickupMessages, {
          text = pType.desc or p.type,
          x = p.x,
          y = p.y,
          timer = 1.5,
          color = pType.color,
        })
      end
      table.remove(gameState.powerups, i)
    end
  end

  -- Player bullets vs patrol robots
  for i = #gameState.bullets, 1, -1 do
    local b = gameState.bullets[i]
    if b.owner == "player" then
      for j = #wanted.patrols, 1, -1 do
        local p = wanted.patrols[j]
        if not p.dead and p.state ~= "warping_in" then
          local dist = math.sqrt((b.x - p.x)^2 + (b.y - p.y)^2)
          if dist < p.size then
            wanted.onPatrolHit(p, gameState.width, gameState.height)
            local destroyed = patrol.damage(p, 1)
            if destroyed then
              gameState.score = gameState.score + p.score
              wanted.onPatrolDestroyed(p, gameState.width, gameState.height)
            end
            table.remove(gameState.bullets, i)
            break
          end
        end
      end
    end
  end

  -- Patrol bullets vs player
  if not gameState.ship.invulnerable and not gameState.ship.dead and not gameState.ship.exploding then
    for i = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[i]
      if b.owner == "patrol" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)
        if dist < gameState.ship.size then
          if gameState.ship.shieldActive then
            -- Shield absorbs patrol bullets
            local dmg = (b.patrolDamage and b.patrolDamage > 0) and b.patrolDamage or 10
            gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - dmg
            if gameState.ship.shieldEnergy <= 0 then
              gameState.ship.shieldEnergy = 0
              gameState.ship.shieldActive = false
            end
            -- Slow still applies through shield
            if b.slowEffect and b.slowEffect > 0 then
              ship.applySlow(gameState.ship, b.slowEffect * 0.5, (b.slowDuration or 2.0) * 0.5)
            end
          else
            -- Apply slow effect
            if b.slowEffect and b.slowEffect > 0 then
              ship.applySlow(gameState.ship, b.slowEffect, b.slowDuration or 2.0)
            end
            -- Apply damage if agent bullet
            if b.patrolDamage and b.patrolDamage > 0 then
              gameState.health = gameState.health - b.patrolDamage
              gameState.damageTimer = 3
              if gameState.health <= 0 then
                ship.die(gameState.ship)
                -- If agent killed the player
                if wanted.agentActive then
                  wanted.onAgentDestroyedPlayer(nil)
                end
              end
            end
          end
          table.remove(gameState.bullets, i)
        end
      end
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

  -- Draw Mega Antenna acquisition overlay (on top of everything)
  if antennaOverlay.phase ~= "none" and antennaOverlay.phase ~= "done" then
    M.drawAntennaOverlay()
  end

  -- Draw Power Amplifier acquisition overlay (on top of everything)
  if amplifierOverlay.phase ~= "none" and amplifierOverlay.phase ~= "done" then
    M.drawAmplifierOverlay()
  end
end

function M.drawStarfoxShip(s)
  local shipDef = starfoxShips.getDef(s.shipType)
  local color = shipDef and shipDef.color or {0.3, 0.5, 1.0}
  local accent = shipDef and shipDef.accentColor or {0.5, 0.7, 1.0}
  local shipType = shipDef and shipDef.type or "Balanced"
  local t = love.timer.getTime()
  local sz = s.size

  love.graphics.push()
  love.graphics.translate(s.x, s.y)
  love.graphics.rotate(s.angle + math.pi / 2)

  -- Shield effect
  if s.invulnerable then
    love.graphics.setColor(0.3, 0.5, 1.0, 0.3 + math.sin(t * 10) * 0.2)
    love.graphics.circle("line", 0, 0, sz * 1.5)
  end

  ------------------------------------------------------------------
  -- TYPE-SPECIFIC SILHOUETTES
  ------------------------------------------------------------------
  if shipType == "Interceptor" then
    -- Sleek needle nose, swept-back delta wings, twin tail fins
    -- Fuselage – long & narrow
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill",
      0, -sz * 1.25,                   -- sharp nose tip
      -sz * 0.22, -sz * 0.2,
      -sz * 0.28, sz * 0.55,
      0, sz * 0.4,
      sz * 0.28, sz * 0.55,
      sz * 0.22, -sz * 0.2
    )
    -- Delta wings – thin, swept far back
    love.graphics.setColor(accent[1], accent[2], accent[3])
    love.graphics.polygon("fill",
      -sz * 0.22, 0,
      -sz * 1.05, sz * 0.65,
      -sz * 0.9, sz * 0.45,
      -sz * 0.28, sz * 0.15
    )
    love.graphics.polygon("fill",
      sz * 0.22, 0,
      sz * 1.05, sz * 0.65,
      sz * 0.9, sz * 0.45,
      sz * 0.28, sz * 0.15
    )
    -- Wing-tip blades (accent)
    love.graphics.setColor(accent[1] * 1.3, accent[2] * 1.3, accent[3] * 1.3, 0.9)
    love.graphics.polygon("fill",
      -sz * 0.95, sz * 0.5,
      -sz * 1.1, sz * 0.7,
      -sz * 0.85, sz * 0.65
    )
    love.graphics.polygon("fill",
      sz * 0.95, sz * 0.5,
      sz * 1.1, sz * 0.7,
      sz * 0.85, sz * 0.65
    )
    -- Twin vertical stabilizers
    love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7)
    love.graphics.polygon("fill", -sz * 0.18, sz * 0.25, -sz * 0.30, sz * 0.6, -sz * 0.12, sz * 0.55)
    love.graphics.polygon("fill",  sz * 0.18, sz * 0.25,  sz * 0.30, sz * 0.6,  sz * 0.12, sz * 0.55)
    -- Cockpit canopy – narrow slit
    love.graphics.setColor(0.4, 0.9, 1.0, 0.85)
    love.graphics.polygon("fill", 0, -sz * 0.9, -sz * 0.08, -sz * 0.3, sz * 0.08, -sz * 0.3)
    -- Accent racing stripes
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(-sz * 0.12, -sz * 0.8, -sz * 0.18, sz * 0.45)
    love.graphics.line( sz * 0.12, -sz * 0.8,  sz * 0.18, sz * 0.45)
    love.graphics.setLineWidth(1)

  elseif shipType == "Heavy" then
    -- Bulky wedge hull, massive box wings with armor plates, gun pods
    -- Wide armored hull
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill",
      0, -sz * 0.85,
      -sz * 0.45, -sz * 0.15,
      -sz * 0.5, sz * 0.6,
      -sz * 0.15, sz * 0.7,
      sz * 0.15, sz * 0.7,
      sz * 0.5, sz * 0.6,
      sz * 0.45, -sz * 0.15
    )
    -- Heavy box wings
    love.graphics.setColor(accent[1] * 0.8, accent[2] * 0.8, accent[3] * 0.8)
    love.graphics.polygon("fill",
      -sz * 0.42, -sz * 0.05,
      -sz * 1.15, sz * 0.25,
      -sz * 1.15, sz * 0.55,
      -sz * 0.48, sz * 0.55
    )
    love.graphics.polygon("fill",
      sz * 0.42, -sz * 0.05,
      sz * 1.15, sz * 0.25,
      sz * 1.15, sz * 0.55,
      sz * 0.48, sz * 0.55
    )
    -- Armor plating detail
    love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.6)
    love.graphics.polygon("fill",
      -sz * 0.32, -sz * 0.1,
      -sz * 0.42, sz * 0.35,
      -sz * 0.22, sz * 0.4
    )
    love.graphics.polygon("fill",
      sz * 0.32, -sz * 0.1,
      sz * 0.42, sz * 0.35,
      sz * 0.22, sz * 0.4
    )
    -- Wing-mounted gun pods
    love.graphics.setColor(0.55, 0.55, 0.6)
    love.graphics.rectangle("fill", -sz * 1.1, sz * 0.15, sz * 0.18, sz * 0.45)
    love.graphics.rectangle("fill",  sz * 0.92, sz * 0.15, sz * 0.18, sz * 0.45)
    love.graphics.setColor(1, 0.7, 0.2, 0.5 + math.sin(t * 8) * 0.3)
    love.graphics.circle("fill", -sz * 1.01, sz * 0.15, 2.5)
    love.graphics.circle("fill",  sz * 1.01, sz * 0.15, 2.5)
    -- Cockpit – wide visor
    love.graphics.setColor(0.3, 0.85, 1.0, 0.8)
    love.graphics.polygon("fill",
      0, -sz * 0.55,
      -sz * 0.2, -sz * 0.15,
      sz * 0.2, -sz * 0.15
    )
    -- Hull edge highlight
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
      0, -sz * 0.85,
      -sz * 0.45, -sz * 0.15,
      -sz * 0.5, sz * 0.6,
      -sz * 0.15, sz * 0.7,
      sz * 0.15, sz * 0.7,
      sz * 0.5, sz * 0.6,
      sz * 0.45, -sz * 0.15
    )
    love.graphics.setLineWidth(1)

  elseif shipType == "Experimental" then
    -- Angular stealth-fighter shape, faceted panels, glowing vents
    -- Faceted fuselage
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill",
      0, -sz * 1.15,
      -sz * 0.35, -sz * 0.25,
      -sz * 0.4, sz * 0.35,
      0, sz * 0.55,
      sz * 0.4, sz * 0.35,
      sz * 0.35, -sz * 0.25
    )
    -- Cranked-arrow wings
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.polygon("fill",
      -sz * 0.35, -sz * 0.15,
      -sz * 1.0, sz * 0.35,
      -sz * 0.7, sz * 0.55,
      -sz * 0.38, sz * 0.25
    )
    love.graphics.polygon("fill",
      sz * 0.35, -sz * 0.15,
      sz * 1.0, sz * 0.35,
      sz * 0.7, sz * 0.55,
      sz * 0.38, sz * 0.25
    )
    -- Glowing cyber-vents along spine
    local ventGlow = math.sin(t * 6) * 0.3 + 0.7
    love.graphics.setColor(accent[1], accent[2], accent[3], ventGlow * 0.8)
    for v = 0, 3 do
      local vy = -sz * 0.5 + v * sz * 0.25
      love.graphics.rectangle("fill", -sz * 0.06, vy, sz * 0.12, sz * 0.08)
    end
    -- Vent bloom halo
    love.graphics.setColor(accent[1], accent[2], accent[3], ventGlow * 0.12)
    love.graphics.circle("fill", 0, 0, sz * 0.7)
    -- Cockpit – angular slit
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.polygon("fill", 0, -sz * 0.85, -sz * 0.1, -sz * 0.3, sz * 0.1, -sz * 0.3)
    -- Edge wireframe accent
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line",
      0, -sz * 1.15,
      -sz * 0.35, -sz * 0.25,
      -sz * 0.4, sz * 0.35,
      0, sz * 0.55,
      sz * 0.4, sz * 0.35,
      sz * 0.35, -sz * 0.25
    )

  else  -- "Balanced" / default (Starwing)
    -- Classic arrowhead with moderate wings
    -- Fuselage
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill",
      0, -sz,
      -sz * 0.3, -sz * 0.1,
      -sz * 0.35, sz * 0.6,
      0, sz * 0.35,
      sz * 0.35, sz * 0.6,
      sz * 0.3, -sz * 0.1
    )
    -- Wings – moderate sweep
    love.graphics.setColor(accent[1], accent[2], accent[3])
    love.graphics.polygon("fill",
      -sz * 0.28, 0,
      -sz * 0.9, sz * 0.5,
      -sz * 0.75, sz * 0.35,
      -sz * 0.32, sz * 0.15
    )
    love.graphics.polygon("fill",
      sz * 0.28, 0,
      sz * 0.9, sz * 0.5,
      sz * 0.75, sz * 0.35,
      sz * 0.32, sz * 0.15
    )
    -- Cockpit
    love.graphics.setColor(0.3, 0.85, 1.0, 0.8)
    love.graphics.polygon("fill", 0, -sz * 0.7, -sz * 0.1, -sz * 0.15, sz * 0.1, -sz * 0.15)
    -- Accent stripe
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, -sz * 0.85, 0, sz * 0.3)
    love.graphics.setLineWidth(1)
  end

  ------------------------------------------------------------------
  -- ENGINE BOOST — bloom thrust flame
  ------------------------------------------------------------------
  if love.keyboard.isDown("up") then
    local flicker = math.random() * 0.3
    local pulse = math.sin(t * 18) * 0.15 + 0.85
    -- Bloom halo (large, soft)
    love.graphics.setColor(1, 0.55, 0.1, 0.12 * pulse)
    love.graphics.circle("fill", 0, sz * 0.7, sz * 1.1)
    love.graphics.setColor(1, 0.35, 0.05, 0.08 * pulse)
    love.graphics.circle("fill", 0, sz * 0.7, sz * 1.5)
    -- Outer flame cone (orange-red)
    love.graphics.setColor(1, 0.4, 0.05, 0.75 * pulse)
    love.graphics.polygon("fill",
      -sz * 0.25, sz * 0.5,
      0, sz * (1.15 + flicker),
      sz * 0.25, sz * 0.5
    )
    -- Mid flame (yellow-orange)
    love.graphics.setColor(1, 0.7, 0.15, 0.85 * pulse)
    love.graphics.polygon("fill",
      -sz * 0.15, sz * 0.5,
      0, sz * (0.95 + flicker * 0.7),
      sz * 0.15, sz * 0.5
    )
    -- Inner core (white-hot)
    love.graphics.setColor(1, 0.95, 0.7, 0.95 * pulse)
    love.graphics.polygon("fill",
      -sz * 0.07, sz * 0.48,
      0, sz * (0.75 + flicker * 0.4),
      sz * 0.07, sz * 0.48
    )
    -- Sparks / ember particles (simple random dots)
    love.graphics.setColor(1, 0.8, 0.2, 0.6)
    for sp = 1, 4 do
      local sx = (math.random() - 0.5) * sz * 0.4
      local sy = sz * (0.7 + math.random() * 0.5)
      love.graphics.circle("fill", sx, sy, 1 + math.random())
    end
  end

  ------------------------------------------------------------------
  -- RETRO-THRUSTERS — bloom brake jets
  ------------------------------------------------------------------
  if love.keyboard.isDown("down") then
    local rFlicker = math.random() * 0.2
    local rPulse = math.sin(t * 14) * 0.12 + 0.88
    -- Bloom halos on sides
    love.graphics.setColor(0.3, 0.55, 1.0, 0.10 * rPulse)
    love.graphics.circle("fill", -sz * 0.6, -sz * 0.25, sz * 0.7)
    love.graphics.circle("fill",  sz * 0.6, -sz * 0.25, sz * 0.7)
    -- Left retro jet – layered
    love.graphics.setColor(0.3, 0.55, 1.0, 0.7 * rPulse)
    love.graphics.polygon("fill",
      -sz * 0.45, -sz * 0.05,
      -sz * (0.75 + rFlicker), -sz * 0.3,
      -sz * 0.45, -sz * 0.45
    )
    love.graphics.setColor(0.6, 0.85, 1.0, 0.9 * rPulse)
    love.graphics.polygon("fill",
      -sz * 0.45, -sz * 0.12,
      -sz * (0.62 + rFlicker * 0.6), -sz * 0.28,
      -sz * 0.45, -sz * 0.38
    )
    -- Right retro jet – layered
    love.graphics.setColor(0.3, 0.55, 1.0, 0.7 * rPulse)
    love.graphics.polygon("fill",
      sz * 0.45, -sz * 0.05,
      sz * (0.75 + rFlicker), -sz * 0.3,
      sz * 0.45, -sz * 0.45
    )
    love.graphics.setColor(0.6, 0.85, 1.0, 0.9 * rPulse)
    love.graphics.polygon("fill",
      sz * 0.45, -sz * 0.12,
      sz * (0.62 + rFlicker * 0.6), -sz * 0.28,
      sz * 0.45, -sz * 0.38
    )
    -- Center nose retro
    love.graphics.setColor(0.45, 0.75, 1.0, 0.55 * rPulse)
    love.graphics.polygon("fill",
      -sz * 0.08, -sz * 0.7,
      0, -sz * (0.92 + rFlicker * 0.5),
      sz * 0.08, -sz * 0.7
    )
    -- Core glow
    love.graphics.setColor(0.7, 0.9, 1.0, 0.95 * rPulse)
    love.graphics.polygon("fill",
      -sz * 0.04, -sz * 0.72,
      0, -sz * (0.82 + rFlicker * 0.3),
      sz * 0.04, -sz * 0.72
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
  -- Set base HUD font (cached, not setNewFont)
  love.graphics.setFont(ui.getFont("hud"))

  -- Health bar
  local healthPercent = math.max(0, gameState.health / gameState.maxHealth)
  love.graphics.setColor(0.2, 0.2, 0.2)
  love.graphics.rectangle("fill", 10, 10, 200, 20)
  if healthPercent > 0.5 then
    love.graphics.setColor(0.2, 0.8, 0.3)
  elseif healthPercent > 0.25 then
    love.graphics.setColor(0.9, 0.7, 0.1)
  else
    love.graphics.setColor(0.9, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", 10, 10, 200 * healthPercent, 20)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", 10, 10, 200, 20)

  -- Lives display (small ship icons)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Lives:", 10, 35)
  for i = 1, (gameState.ship.lives or 0) do
    local lx = 60 + (i - 1) * 20
    local ly = 42
    love.graphics.setColor(0.3, 0.5, 1.0)
    love.graphics.polygon("fill",
      lx, ly - 6,
      lx - 5, ly + 4,
      lx, ly + 2,
      lx + 5, ly + 4
    )
  end

  -- Score
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Score: " .. gameState.score, 10, 55)

  -- Tile coordinates
  love.graphics.setColor(0.7, 0.7, 0.8)
  local tile = worldmap.getCurrentTile()
  local coords = "(" .. worldmap.tileX .. ", " .. worldmap.tileY .. ")"
  local constellationName = worldmap.getConstellationName()
  love.graphics.print(constellationName .. " " .. coords, 10, 75)

  -- Shield energy bar
  local shieldPct = gameState.ship.shieldEnergy / gameState.ship.shieldMaxEnergy
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", 10, 95, 150, 14)
  if gameState.ship.shieldActive then
    love.graphics.setColor(0.3, 0.6, 1, 0.9)
  else
    love.graphics.setColor(0.2, 0.4, 0.7, 0.7)
  end
  love.graphics.rectangle("fill", 10, 95, 150 * shieldPct, 14)
  love.graphics.setColor(0.4, 0.6, 0.9)
  love.graphics.rectangle("line", 10, 95, 150, 14)
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.print("SHIELD [S]", 12, 96)

  -- Missile count
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(1, 0.35, 0.1)
  love.graphics.print("MISSILES: ", 10, 114)
  if gameState.ship.maxMissiles > 0 then
    for i = 1, gameState.ship.maxMissiles do
      local mx = 85 + (i - 1) * 14
      if i <= gameState.ship.missiles then
        -- Filled missile icon
        love.graphics.setColor(1, 0.3, 0.1)
        love.graphics.polygon("fill", mx, 117, mx - 3, 126, mx + 3, 126)
        love.graphics.setColor(1, 0.6, 0.3)
        love.graphics.polygon("line", mx, 117, mx - 3, 126, mx + 3, 126)
      else
        -- Empty missile slot
        love.graphics.setColor(0.4, 0.2, 0.1, 0.5)
        love.graphics.polygon("line", mx, 117, mx - 3, 126, mx + 3, 126)
      end
    end
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("--", 85, 114)
  end

  -- Bomb count
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(1, 0.7, 0.2)
  love.graphics.print("BOMBS [B]: ", 10, 132)
  for i = 1, gameState.ship.bombs do
    local bx = 100 + (i - 1) * 16
    love.graphics.setColor(1, 0.5, 0.1)
    love.graphics.circle("fill", bx, 139, 5)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.circle("line", bx, 139, 5)
  end
  if gameState.ship.bombs == 0 then
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("NONE", 100, 132)
  end

  -- Active powerup indicators
  local activeY = 154
  love.graphics.setFont(ui.getFont("hudSmall"))
  if ship.hasMultishot(gameState.ship) then
    love.graphics.setColor(1, 0.2, 0.8, 0.9)
    love.graphics.print("● MULTI-SHOT " .. math.ceil(gameState.ship.multishotTimer) .. "s", 10, activeY)
    activeY = activeY + 16
  end
  if ship.hasSpeedBoost(gameState.ship) then
    love.graphics.setColor(0.2, 1, 1, 0.9)
    love.graphics.print("● SPEED BOOST " .. math.ceil(gameState.ship.speedBoostTimer) .. "s", 10, activeY)
    activeY = activeY + 16
  end
  if ship.hasMagnet(gameState.ship) then
    love.graphics.setColor(1, 1, 0.2, 0.9)
    love.graphics.print("● MAGNET " .. math.ceil(gameState.ship.magnetTimer) .. "s", 10, activeY)
    activeY = activeY + 16
  end
  if gameState.ship.rapidFireTimer > 0 then
    love.graphics.setColor(1, 0.5, 0, 0.9)
    love.graphics.print("● RAPID FIRE " .. math.ceil(gameState.ship.rapidFireTimer) .. "s", 10, activeY)
    activeY = activeY + 16
  end
  if timeSlowState.active then
    love.graphics.setColor(0.6, 0.3, 1, 0.9)
    love.graphics.print("● TIME WARP " .. math.ceil(timeSlowState.timer) .. "s", 10, activeY)
    activeY = activeY + 16
  end

  -- Combo display
  if comboState.displayTimer > 0 and comboState.count >= 5 then
    love.graphics.setFont(ui.getFont("medium"))
    local comboAlpha = math.min(1, comboState.displayTimer)
    love.graphics.setColor(1, 0.8, 0, comboAlpha)
    love.graphics.printf(comboState.count .. "x COMBO! (×" .. string.format("%.1f", comboState.multiplier) .. ")", 
      0, gameState.height - 80, gameState.width, "center")
  end

  -- Pickup message popups
  love.graphics.setFont(ui.getFont("hudLabel"))
  for _, msg in ipairs(pickupMessages) do
    local alpha = math.min(1, msg.timer)
    love.graphics.setColor(msg.color[1], msg.color[2], msg.color[3], alpha)
    love.graphics.print(msg.text, msg.x - 30, msg.y)
  end

  -- Space event message
  if spaceEventState.messageTimer > 0 then
    love.graphics.setFont(ui.getFont("medium"))
    local alpha = math.min(1, spaceEventState.messageTimer / 0.5)
    love.graphics.setColor(spaceEventState.messageColor[1], spaceEventState.messageColor[2], spaceEventState.messageColor[3], alpha)
    love.graphics.printf(spaceEventState.message, 0, gameState.height / 2 - 100, gameState.width, "center")
  end

  -- Minimap
  M.drawMinimap()

  -- Reset font to default after HUD drawing
  love.graphics.setFont(ui.getFont("hud"))
end

function M.drawMinimap()
  local mapX = gameState.width - 120
  local mapY = 10

  -- Determine view range based on current tier
  local tier = constellation.getTier()
  local viewRadius -- tiles around player to show
  local cellSize

  if tier == constellation.TIER_NEBULA then
    viewRadius = 3
    cellSize = 14
  elseif tier == constellation.TIER_INNER_SPACE then
    viewRadius = 7 -- Show a 15x15 window centered on player
    cellSize = 6
  else
    viewRadius = 10 -- 21x21 window for outer space
    cellSize = 4
  end

  local viewSize = (viewRadius * 2 + 1)
  local mapSize = viewSize * cellSize
  mapX = gameState.width - mapSize - 10

  -- Background
  love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
  love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize)

  -- Grid cells (centered on player position)
  local playerTX = worldmap.tileX
  local playerTY = worldmap.tileY

  for dx = -viewRadius, viewRadius do
    for dy = -viewRadius, viewRadius do
      local x = playerTX + dx
      local y = playerTY + dy

      -- Check if in bounds
      if x >= worldmap.GRID_MIN and x <= worldmap.GRID_MAX and
         y >= worldmap.GRID_MIN and y <= worldmap.GRID_MAX then

        local tile = worldmap.getTile(x, y)
        local drawX = mapX + (dx + viewRadius) * cellSize
        local drawY = mapY + (viewRadius - dy) * cellSize -- Flip Y for display

        if tile.type == worldmap.TILE_STATION then
          love.graphics.setColor(0.4, 0.6, 0.9, 0.8)
        elseif tile.type == worldmap.TILE_PORTAL then
          love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 0.8)
        else
          -- Color by constellation
          local cId = constellation.getConstellationId(x, y)
          local cData = constellation.CONSTELLATIONS[cId]
          if cData then
            local bg = cData.bgColor
            love.graphics.setColor(bg[1] * 5 + 0.15, bg[2] * 5 + 0.15, bg[3] * 5 + 0.15, 0.5)
          else
            love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
          end
        end

        love.graphics.rectangle("fill", drawX + 1, drawY + 1, cellSize - 2, cellSize - 2)

        -- Draw constellation boundaries
        local cx1, cy1 = constellation.getConstellationCoords(x, y)
        local cx2, _ = constellation.getConstellationCoords(x + 1, y)
        local _, cy2 = constellation.getConstellationCoords(x, y + 1)
        if tier >= constellation.TIER_INNER_SPACE then
          love.graphics.setColor(0.4, 0.4, 0.5, 0.3)
          if cx1 ~= cx2 then
            love.graphics.line(drawX + cellSize, drawY, drawX + cellSize, drawY + cellSize)
          end
          if cy1 ~= cy2 then
            love.graphics.line(drawX, drawY, drawX + cellSize, drawY)
          end
        end
      end
    end
  end

  -- Current position marker
  local markerX = mapX + viewRadius * cellSize + cellSize / 2
  local markerY = mapY + viewRadius * cellSize + cellSize / 2

  love.graphics.setColor(1, 1, 0)
  love.graphics.circle("fill", markerX, markerY, math.max(2, cellSize * 0.3))

  -- Border
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.rectangle("line", mapX, mapY, mapSize, mapSize)

  -- Constellation label below minimap
  love.graphics.setFont(ui.getFont("hudSmall"))
  love.graphics.setColor(0.6, 0.7, 0.8)
  local cName = worldmap.getConstellationName()
  love.graphics.printf(cName, mapX, mapY + mapSize + 2, mapSize, "center")
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
  -- Set default font for this frame
  love.graphics.setFont(ui.getFont("hud"))

  -- Draw nebula background
  nebula.draw(gameState.width, gameState.height)

  -- Draw tile-specific content
  if worldmap.isAtStation() then
    M.drawStation()
  elseif worldmap.isAtPortal() then
    M.drawPortal()
  end

  local color = gameState.level.color

  -- Override asteroid color based on constellation
  local asteroidVisuals = constellation.getAsteroidVisuals(worldmap.tileX, worldmap.tileY)
  local asteroidColor = asteroidVisuals.color

  if gameState.ship.exploding then
    ship.drawExplosion(gameState.ship)
  elseif not gameState.ship.dead then
    M.drawStarfoxShip(gameState.ship)
    M.drawShield()
  end

  for _, a in ipairs(gameState.asteroids) do
    ui.drawAsteroid(a, asteroidColor)

    -- Draw constellation-specific asteroid effects
    if asteroidVisuals.glow then
      local r = asteroid.getRadius(a)
      love.graphics.setColor(asteroidVisuals.glow[1], asteroidVisuals.glow[2], asteroidVisuals.glow[3], asteroidVisuals.glow[4])
      love.graphics.circle("fill", a.x, a.y, r * 1.3)
    end
    if asteroidVisuals.crystal then
      -- Crystalline sparkle
      local sparkle = math.sin(love.timer.getTime() * 3 + a.x * 0.1) * 0.3 + 0.7
      love.graphics.setColor(0.7, 0.85, 1.0, sparkle * 0.4)
      love.graphics.circle("fill", a.x + 3, a.y - 3, 3)
    end
    if asteroidVisuals.icy then
      -- Dark ice sheen
      local r = asteroid.getRadius(a)
      love.graphics.setColor(0, 0.3, 0.5, 0.15)
      love.graphics.circle("fill", a.x, a.y, r * 0.8)
    end
  end

  for _, b in ipairs(gameState.bullets) do
    -- Color patrol bullets differently
    if b.owner == "patrol" then
      love.graphics.setColor(1, 0.3, 0.3)
      love.graphics.circle("fill", b.x, b.y, 3)
      love.graphics.setColor(1, 0.5, 0.5, 0.4)
      love.graphics.circle("fill", b.x, b.y, 6)
    else
      ui.drawBullet(b)
    end
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

  -- Draw patrol robots
  for _, p in ipairs(wanted.patrols) do
    patrol.draw(p)
  end

  -- Draw smart bomb effect
  M.drawSmartBomb()

  -- Draw missile AOE explosions
  M.drawMissileExplosions()

  -- Draw HUD with tile info
  M.drawHUD()

  -- Draw hazard warning icons
  M.drawHazardWarnings()

  -- Draw Vela countdown clock (SSB style)
  M.drawVelaClock()

  -- Draw puzzle elements (spinning locks, bosses, mazes, etc.)
  puzzle.drawPuzzle(
    worldmap.tileX, worldmap.tileY,
    gameState.width, gameState.height,
    gameState.ship.x, gameState.ship.y
  )

  -- Draw comets (Oort Cloud)
  constellation.drawComets()

  -- Draw wanted stars
  M.drawWantedStars()

  -- Draw slow effect indicator
  if gameState.ship.slowTimer and gameState.ship.slowTimer > 0 then
    love.graphics.setColor(1, 0.3, 0.3, 0.5 + math.sin(love.timer.getTime() * 8) * 0.3)
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.printf("SLOWED", 0, gameState.height - 40, gameState.width, "center")
  end

  -- Draw time slow visual effect
  if timeSlowState.active then
    local progress = timeSlowState.timer / timeSlowState.duration
    love.graphics.setColor(0.4, 0.2, 0.8, 0.08 + math.sin(love.timer.getTime() * 3) * 0.04)
    love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)
  end

  -- Draw speed boost visual (thruster trail)
  if ship.hasSpeedBoost(gameState.ship) and not gameState.ship.dead and not gameState.ship.exploding then
    local time = love.timer.getTime()
    for i = 1, 5 do
      local trailAngle = gameState.ship.angle + math.pi
      local dist = 15 + i * 8
      local tx = gameState.ship.x + math.cos(trailAngle) * dist + (math.random() - 0.5) * 6
      local ty = gameState.ship.y + math.sin(trailAngle) * dist + (math.random() - 0.5) * 6
      local alpha = (6 - i) / 6 * 0.6
      love.graphics.setColor(0.2, 1, 1, alpha)
      love.graphics.circle("fill", tx, ty, 4 - i * 0.5)
    end
  end

  -- Draw magnet field visual
  if ship.hasMagnet(gameState.ship) and not gameState.ship.dead and not gameState.ship.exploding then
    local time = love.timer.getTime()
    local magnetPulse = math.sin(time * 3) * 0.15
    love.graphics.setColor(1, 1, 0.2, 0.06 + magnetPulse * 0.03)
    love.graphics.circle("fill", gameState.ship.x, gameState.ship.y, 300)
    love.graphics.setColor(1, 1, 0.3, 0.15 + magnetPulse)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", gameState.ship.x, gameState.ship.y, 300 + math.sin(time * 5) * 10)
  end

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

  -- Draw busted overlay (only for 3+ star busts, not warning catches)
  if wanted.bustedState and not wanted.warningCatch then
    M.drawBustedOverlay()
  end

  -- Draw dialogue
  if wanted.dialogueActive then
    if wanted.warningCatch then
      M.drawWarningDialogue()
    else
      M.drawPoliceDialogue()
    end
  end

  -- Draw sentence countdown
  if wanted.sentenceActive then
    M.drawSentenceCountdown()
  end

  -- Draw agent sayonara
  if wanted.agentSayonara then
    M.drawAgentSayonara()
  end
end

function M.drawPauseMenu()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)

  -- Title
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.setFont(ui.getFont("title"))
  love.graphics.printf("PAUSED", 0, 250, gameState.width, "center")

  -- Menu options
  love.graphics.setFont(ui.getFont("small"))
  local options = {"Resume", "Restart Level", "Options", "Exit to Station"}
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
  love.graphics.setFont(ui.getFont("hudLabel"))
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

-- ===================== CONSTELLATION HAZARD SYSTEM =====================

function M.updateConstellationHazards(dt)
  if gameState.ship.dead or gameState.ship.exploding then return end

  local tx, ty = worldmap.tileX, worldmap.tileY
  local cId = constellation.getConstellationId(tx, ty)
  local cData = constellation.CONSTELLATIONS[cId]

  -- Reset hazard state
  hazardState.coldActive = false
  hazardState.hotActive = false
  hazardState.gravityActive = false
  hazardState.pulsarWarning = false
  hazardState.pulsarBurst = false

  if not cData or not cData.hazard then
    -- Still update pulsar timer even when not in Vela (it keeps ticking)
    constellation.updateVelaPulsar(dt, tx, ty)
    -- Update comets
    constellation.updateComets(dt, tx, ty, gameState.width, gameState.height)
    return
  end

  -- COLD (Oort Cloud) - continuous cold damage
  if cData.hazard == "cold" then
    hazardState.coldActive = true
    if not gameState.ship.shieldActive then
      gameState.health = gameState.health - cData.coldDamage * dt
      if gameState.health <= 0 then
        ship.die(gameState.ship)
      end
    end
  end

  -- HOT SECTORS (Pandora) - some tiles deal heat damage
  if cData.hazard == "hot_sectors" then
    if constellation.isHotSector(tx, ty) then
      hazardState.hotActive = true
      if not gameState.ship.shieldActive then
        gameState.health = gameState.health - cData.hotDamage * dt
        if gameState.health <= 0 then
          ship.die(gameState.ship)
        end
      end
    end
  end

  -- GRAVITY (Gargantua) - pull toward center
  if cData.hazard == "gravity" then
    local gx, gy = constellation.getGravityPull(
      tx, ty, gameState.ship.x, gameState.ship.y,
      gameState.width, gameState.height
    )
    if math.abs(gx) > 0.1 or math.abs(gy) > 0.1 then
      hazardState.gravityActive = true
      hazardState.gravityDX = gx
      hazardState.gravityDY = gy
      -- Apply gravity to ship velocity
      gameState.ship.vx = gameState.ship.vx + gx * dt
      gameState.ship.vy = gameState.ship.vy + gy * dt
    end
  end

  -- PULSAR (Vela) - periodic energy burst
  if cData.hazard == "pulsar" then
    constellation.updateVelaPulsar(dt, tx, ty)
    local state = constellation.getVelaPulsarState(tx, ty)
    if state then
      hazardState.pulsarTimeLeft = state.timeUntilBurst
      hazardState.pulsarWarning = state.isWarning
      hazardState.pulsarBurst = state.burstActive
      hazardState.pulsarBurstProgress = state.burstProgress

      -- Apply continuous burst damage over the full 3-second burst
      -- Shield must be held throughout or the player takes heavy damage
      if state.burstActive then
        if not gameState.ship.shieldActive then
          -- Unshielded: massive DPS (kills in ~0.3s)
          local burstDPS = cData.pulsarDamage / 0.3
          gameState.health = gameState.health - burstDPS * dt
          if gameState.health <= 0 then
            gameState.health = 0
            ship.die(gameState.ship)
          end
        else
          -- Shield absorbs but drains steadily over the 3s burst
          -- Full burst costs ~90 shield energy, so shield must be nearly full
          local shieldDrain = 30 * dt  -- 30 energy/sec = 90 over 3s
          gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - shieldDrain
          if gameState.ship.shieldEnergy <= 0 then
            gameState.ship.shieldEnergy = 0
            gameState.ship.shieldActive = false
          end
        end
      end
    end
  else
    constellation.updateVelaPulsar(dt, tx, ty)
  end

  -- Update comets (Oort Cloud)
  constellation.updateComets(dt, tx, ty, gameState.width, gameState.height)
end

-- ═══════════════════════════════════════════════════════
-- VELA COUNTDOWN CLOCK (Super Smash Bros style)
-- ═══════════════════════════════════════════════════════
function M.drawVelaClock()
  local cId = constellation.getConstellationId(worldmap.tileX, worldmap.tileY)
  if cId ~= "vela" then return end

  local state = constellation.getVelaPulsarState(worldmap.tileX, worldmap.tileY)
  if not state then return end

  local timeLeft = math.max(0, state.timeUntilBurst)
  local minutes = math.floor(timeLeft / 60)
  local seconds = math.floor(timeLeft % 60)
  local fraction = math.floor((timeLeft % 1) * 100)
  local timeStr = string.format("%d:%02d", minutes, seconds)
  local fracStr = string.format("%02d", fraction)

  local screenW = gameState.width
  local cx = screenW / 2
  local t = love.timer.getTime()

  -- === Clock dimensions ===
  local clockW = 180
  local clockH = 58
  local clockX = cx - clockW / 2
  local clockY = 6

  -- === Urgency state ===
  local isUrgent = timeLeft <= 30
  local isCritical = timeLeft <= 10
  local isBurst = state.burstActive

  -- === Background panel (dark with colored border) ===
  -- Outer glow when urgent
  if isUrgent and not isBurst then
    local pulse = math.sin(t * (isCritical and 12 or 6)) * 0.3 + 0.5
    love.graphics.setColor(1, 0.2, 0.1, pulse * 0.4)
    love.graphics.rectangle("fill", clockX - 4, clockY - 4, clockW + 8, clockH + 8, 10, 10)
  end

  -- Main panel background
  love.graphics.setColor(0.05, 0.03, 0.08, 0.92)
  love.graphics.rectangle("fill", clockX, clockY, clockW, clockH, 7, 7)

  -- Border color shifts with urgency
  if isBurst then
    local flash = math.sin(t * 20) * 0.5 + 0.5
    love.graphics.setColor(1, 0.1, 0.1, flash)
  elseif isCritical then
    local flash = math.sin(t * 8) * 0.4 + 0.6
    love.graphics.setColor(1, 0.15 + flash * 0.2, 0.1, 1)
  elseif isUrgent then
    love.graphics.setColor(1, 0.7, 0.2, 0.9)
  else
    love.graphics.setColor(0.5, 0.35, 0.8, 0.8)
  end
  love.graphics.setLineWidth(2.5)
  love.graphics.rectangle("line", clockX, clockY, clockW, clockH, 7, 7)

  -- === Top label: "PULSAR" ===
  love.graphics.setFont(ui.getFont("hudSmall"))
  if isBurst then
    local flash = math.sin(t * 15) * 0.5 + 0.5
    love.graphics.setColor(1, 0.2, 0.1, flash)
    love.graphics.printf("⚡ PULSAR BURST ⚡", clockX, clockY + 3, clockW, "center")
  elseif isCritical then
    local flash = math.sin(t * 10) * 0.4 + 0.6
    love.graphics.setColor(1, 0.3, 0.15, flash)
    love.graphics.printf("⚡ PULSAR ⚡", clockX, clockY + 3, clockW, "center")
  else
    love.graphics.setColor(0.7, 0.6, 0.9, 0.9)
    love.graphics.printf("PULSAR", clockX, clockY + 3, clockW, "center")
  end

  -- === Main time digits (large, SSB style) ===
  if isBurst then
    -- "BURST!" during the active burst
    love.graphics.setFont(ui.getFont("subtitle"))
    local flash = math.sin(t * 18) * 0.5 + 0.5
    love.graphics.setColor(1, 0.15 + flash * 0.3, 0.1, 1)
    love.graphics.printf("BURST!", clockX, clockY + 17, clockW, "center")
  else
    -- Main digits: M:SS
    love.graphics.setFont(ui.getFont("subtitle"))
    local digitColor
    if isCritical then
      local flash = math.sin(t * 10) * 0.3 + 0.7
      digitColor = {1, 0.2 + flash * 0.15, 0.1, 1}
    elseif isUrgent then
      local flash = math.sin(t * 5) * 0.15 + 0.85
      digitColor = {1, 0.75, 0.15, flash}
    else
      digitColor = {1, 1, 1, 1}
    end

    -- Shadow for depth
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.printf(timeStr, clockX + 2, clockY + 19, clockW - 30, "center")
    -- Main digits
    love.graphics.setColor(unpack(digitColor))
    love.graphics.printf(timeStr, clockX, clockY + 17, clockW - 30, "center")

    -- Fractional seconds (smaller, dimmer)
    love.graphics.setFont(ui.getFont("hudLabel"))
    local fracX = cx + 32
    love.graphics.setColor(digitColor[1], digitColor[2], digitColor[3], digitColor[4] * 0.5)
    love.graphics.print(fracStr, fracX, clockY + 28)
  end

  -- === Progress bar at bottom of clock ===
  local data = constellation.CONSTELLATIONS.vela
  local progress = 1 - (timeLeft / data.pulsarInterval)
  local barPad = 8
  local barW = clockW - barPad * 2
  local barH = 4
  local barY = clockY + clockH - barH - 5

  -- Bar background
  love.graphics.setColor(0.15, 0.1, 0.2, 0.8)
  love.graphics.rectangle("fill", clockX + barPad, barY, barW, barH, 2, 2)

  -- Bar fill
  if isBurst then
    love.graphics.setColor(1, 0.1, 0.1, 1)
  elseif isCritical then
    love.graphics.setColor(1, 0.2, 0.1, 1)
  elseif isUrgent then
    love.graphics.setColor(1, 0.7, 0.2, 1)
  else
    love.graphics.setColor(0.5, 0.35, 0.85, 0.9)
  end
  love.graphics.rectangle("fill", clockX + barPad, barY, barW * progress, barH, 2, 2)

  love.graphics.setLineWidth(1)
end

function M.drawHazardWarnings()
  local barX = 215 -- Right of health bar
  local barY = 10

  -- Cold warning (blue snowflake icon)
  if hazardState.coldActive then
    local pulse = math.sin(love.timer.getTime() * 4) * 0.2 + 0.8
    -- Blue warning background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX, barY, 28, 22, 3, 3)
    -- Snowflake/cold icon
    love.graphics.setColor(0.3, 0.7, 1.0, pulse)
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.print("❄", barX + 5, barY + 3)
    -- "COLD" label
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.5, 0.8, 1.0, pulse)
    love.graphics.print("COLD", barX + 2, barY + 23)
    barX = barX + 32
  end

  -- Hot warning (red fire icon)
  if hazardState.hotActive then
    local pulse = math.sin(love.timer.getTime() * 5) * 0.2 + 0.8
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX, barY, 28, 22, 3, 3)
    love.graphics.setColor(1.0, 0.3, 0.1, pulse)
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.print("🔥", barX + 5, barY + 3)
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1.0, 0.4, 0.2, pulse)
    love.graphics.print("HOT", barX + 4, barY + 23)
    barX = barX + 32
  end

  -- Gravity warning
  if hazardState.gravityActive then
    local pull = math.sqrt(hazardState.gravityDX^2 + hazardState.gravityDY^2)
    local intensity = math.min(1, pull / 150)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX, barY, 28, 22, 3, 3)
    love.graphics.setColor(0.9, 0.6, 0.2, 0.6 + intensity * 0.4)
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.print("◉", barX + 6, barY + 2)
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.9, 0.6, 0.2)
    love.graphics.print("GRAV", barX + 1, barY + 23)
    barX = barX + 32
  end

  -- Pulsar warning / countdown
  if hazardState.pulsarWarning or hazardState.pulsarBurst then
    local flash = math.sin(love.timer.getTime() * 8) * 0.5 + 0.5
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX, barY, 55, 22, 3, 3)

    if hazardState.pulsarBurst then
      -- BURST ACTIVE - red flash
      love.graphics.setColor(1, 0.1, 0.1, flash)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.print("BURST!", barX + 4, barY + 4)
    else
      -- Warning countdown
      love.graphics.setColor(1, 0.8, 0.2, flash)
      love.graphics.setFont(ui.getFont("hudSmall"))
      local secs = math.floor(hazardState.pulsarTimeLeft)
      love.graphics.print("⚡" .. secs .. "s", barX + 4, barY + 5)
    end
    barX = barX + 59
  end

  -- Vela pulsar burst screen effect: blue radio wave beams
  if hazardState.pulsarBurst then
    local progress = hazardState.pulsarBurstProgress
    local t = love.timer.getTime()
    local w = gameState.width
    local h = gameState.height

    -- Pulsar source point (top-right corner, like a distant neutron star)
    local srcX = w * 0.85
    local srcY = -30

    -- Initial white core flash
    if progress < 0.15 then
      local coreAlpha = (1 - progress / 0.15) * 0.7
      love.graphics.setColor(0.6, 0.8, 1.0, coreAlpha)
      love.graphics.rectangle("fill", 0, 0, w, h)
    end

    -- Sweeping radio wave beams from the pulsar source
    local numBeams = 14
    local beamAlpha = (1 - progress) * 0.65
    for i = 1, numBeams do
      -- Each beam rotates at a different speed, creating sweeping lighthouse effect
      local baseAngle = (i / numBeams) * math.pi * 2
      local sweep = t * (2.5 + i * 0.3) + i * 1.7
      local angle = baseAngle + math.sin(sweep) * 0.4 + progress * math.pi * 0.5

      -- Beam length extends well past screen
      local beamLen = math.max(w, h) * 1.8
      local endX = srcX + math.cos(angle) * beamLen
      local endY = srcY + math.sin(angle) * beamLen

      -- Beam width oscillates (radio wave pulsing)
      local pulse = math.sin(t * 12 + i * 2.1) * 0.5 + 0.5
      local beamWidth = 3 + pulse * 8 + (1 - progress) * 6

      -- Blue-cyan color with variation per beam
      local hueShift = math.sin(i * 0.9 + t * 3) * 0.15
      local r = 0.15 + hueShift
      local g = 0.45 + hueShift + math.sin(i * 1.3) * 0.15
      local b = 0.95 + math.sin(i * 0.7) * 0.05

      love.graphics.setColor(r, g, b, beamAlpha * (0.6 + pulse * 0.4))
      love.graphics.setLineWidth(beamWidth)
      love.graphics.line(srcX, srcY, endX, endY)

      -- Bright core line inside each beam
      love.graphics.setColor(0.7, 0.9, 1.0, beamAlpha * pulse * 0.8)
      love.graphics.setLineWidth(math.max(1, beamWidth * 0.3))
      love.graphics.line(srcX, srcY, endX, endY)
    end

    -- Concentric radio wave rings expanding from the source
    local numRings = 8
    for i = 1, numRings do
      local ringPhase = (t * 1.5 + i * 0.4) % 2.0
      local ringRadius = ringPhase * math.max(w, h) * 0.9
      local ringAlpha = (1 - ringPhase / 2.0) * beamAlpha * 0.5
      if ringAlpha > 0.01 then
        local ringPulse = math.sin(t * 8 + i) * 0.3 + 0.7
        love.graphics.setColor(0.3, 0.6, 1.0, ringAlpha * ringPulse)
        love.graphics.setLineWidth(1.5 + (1 - progress) * 2)
        love.graphics.circle("line", srcX, srcY, ringRadius)
      end
    end

    -- Bright pulsar point glow
    local glowSize = 20 + math.sin(t * 15) * 10 + (1 - progress) * 15
    for layer = 3, 1, -1 do
      local layerAlpha = beamAlpha * (0.15 / layer)
      love.graphics.setColor(0.5, 0.8, 1.0, layerAlpha)
      love.graphics.circle("fill", srcX, srcY, glowSize * layer)
    end
    love.graphics.setColor(0.8, 0.95, 1.0, beamAlpha)
    love.graphics.circle("fill", srcX, srcY, glowSize * 0.3)

    -- Subtle blue tint overlay on the whole screen
    love.graphics.setColor(0.05, 0.1, 0.3, beamAlpha * 0.25)
    love.graphics.rectangle("fill", 0, 0, w, h)

    love.graphics.setLineWidth(1)
  end
end

-- ===================== MEGA ANTENNA ACQUISITION =====================

function M.updateAntennaOverlay(dt)
  antennaOverlay.timer = antennaOverlay.timer + dt

  if antennaOverlay.phase == "acquisition" then
    -- Fade in the overlay
    antennaOverlay.fadeAlpha = math.min(1, antennaOverlay.fadeAlpha + dt * 2)
    -- Grow antenna glow
    antennaOverlay.antennaGlow = math.min(1, antennaOverlay.antennaGlow + dt * 1.5)

  elseif antennaOverlay.phase == "transmission" then
    -- Typewriter-style reveal of transmission lines
    local lineDelay = 0.6
    local targetLine = math.floor(antennaOverlay.timer / lineDelay) + 1
    if targetLine > #antennaOverlay.transmissionLines then
      targetLine = #antennaOverlay.transmissionLines
    end
    antennaOverlay.transmissionLine = targetLine
  end
end

function M.drawAntennaOverlay()
  local w = gameState.width
  local h = gameState.height
  local time = love.timer.getTime()
  local cx, cy = w / 2, h / 2

  if antennaOverlay.phase == "acquisition" then
    local alpha = antennaOverlay.fadeAlpha

    -- Dark background
    love.graphics.setColor(0, 0, 0, 0.92 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Radial golden glow behind antenna
    local glowPulse = 0.25 + 0.1 * math.sin(time * 2)
    love.graphics.setColor(1, 0.8, 0.2, glowPulse * alpha * antennaOverlay.antennaGlow)
    love.graphics.circle("fill", cx, cy - 40, 160)
    love.graphics.setColor(1, 0.6, 0.1, glowPulse * 0.4 * alpha * antennaOverlay.antennaGlow)
    love.graphics.circle("fill", cx, cy - 40, 240)

    -- Sparkle particles
    for i = 1, 20 do
      local seed = i * 97.3
      local px = cx + math.sin(seed + time * 0.7) * (80 + i * 6)
      local py = cy - 40 + math.cos(seed * 1.3 + time * 0.5) * (60 + i * 4)
      local flicker = math.sin(time * 4 + seed) * 0.4 + 0.6
      local sz = 1 + math.sin(seed + time) * 0.8
      love.graphics.setColor(1, 0.9, 0.4, flicker * alpha * antennaOverlay.antennaGlow)
      love.graphics.circle("fill", px, py, sz)
    end

    -- Draw the Mega Antenna (procedural)
    local scale = 3.5 * antennaOverlay.antennaGlow
    love.graphics.push()
    love.graphics.translate(cx, cy - 40)
    love.graphics.scale(scale, scale)
    local wobble = math.sin(time * 0.8) * 0.05
    love.graphics.rotate(wobble)

    -- Main antenna mast
    love.graphics.setColor(0.7, 0.7, 0.75, alpha)
    love.graphics.setLineWidth(3 / scale)
    love.graphics.line(0, 30, 0, -25)

    -- Dish base
    love.graphics.setColor(0.5, 0.5, 0.55, alpha)
    love.graphics.rectangle("fill", -8, 25, 16, 8, 2, 2)

    -- Satellite dish (parabolic shape)
    love.graphics.setColor(0.8, 0.8, 0.85, alpha)
    love.graphics.arc("fill", 0, -10, 20, -math.pi * 0.85, -math.pi * 0.15)

    -- Dish inner surface
    love.graphics.setColor(0.6, 0.65, 0.7, alpha)
    love.graphics.arc("fill", 0, -10, 15, -math.pi * 0.8, -math.pi * 0.2)

    -- Feed horn (the small antenna pointing at dish)
    love.graphics.setColor(0.75, 0.75, 0.8, alpha)
    love.graphics.setLineWidth(2 / scale)
    love.graphics.line(0, -10, 0, -28)
    -- Signal tip
    local tipGlow = math.sin(time * 5) * 0.3 + 0.7
    love.graphics.setColor(0.2, 1, 0.5, tipGlow * alpha)
    love.graphics.circle("fill", 0, -28, 3)
    -- Signal rings emanating from tip
    for ring = 1, 3 do
      local ringPhase = math.fmod(time * 2 + ring * 0.5, 2)
      local ringRadius = ringPhase * 8
      local ringAlpha = (1 - ringPhase / 2) * 0.5 * tipGlow
      love.graphics.setColor(0.2, 1, 0.5, ringAlpha * alpha)
      love.graphics.setLineWidth(1 / scale)
      love.graphics.arc("line", 0, -28, ringRadius, -math.pi * 0.75, -math.pi * 0.25)
    end

    -- Support struts
    love.graphics.setColor(0.6, 0.6, 0.65, alpha)
    love.graphics.setLineWidth(1.5 / scale)
    love.graphics.line(-6, 25, -12, 12)
    love.graphics.line(6, 25, 12, 12)

    -- "MEGA" label on base
    love.graphics.setColor(1, 0.8, 0.2, alpha)

    love.graphics.pop()

    -- "You got the Mega Antenna!" title with golden shimmer
    love.graphics.setFont(ui.getFont("subtitle"))
    local titleShimmer = math.sin(time * 2) * 0.1
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.8 * alpha)
    love.graphics.printf("You got the Mega Antenna!", 2, h * 0.62 + 2, w, "center")
    -- Gold text
    love.graphics.setColor(1, 0.85 + titleShimmer, 0.2, alpha)
    love.graphics.printf("You got the Mega Antenna!", 0, h * 0.62, w, "center")

    -- Subtitle
    love.graphics.setFont(ui.getFont("hud"))
    love.graphics.setColor(0.7, 0.9, 1, 0.8 * alpha)
    love.graphics.printf("A powerful deep-space communication array.", 0, h * 0.70, w, "center")

    -- Continue prompt
    if alpha >= 0.9 then
      local pulse = 0.4 + 0.4 * math.sin(time * 3)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(0.6, 0.6, 0.7, pulse * alpha)
      love.graphics.printf("Press ENTER to continue", 0, h * 0.88, w, "center")
    end

  elseif antennaOverlay.phase == "transmission" then
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Transmission border frame (green-tinted comm screen)
    local borderPulse = math.sin(time * 3) * 0.1 + 0.4
    love.graphics.setColor(0.1, 0.6, 0.3, borderPulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", w * 0.1, h * 0.1, w * 0.8, h * 0.8, 8, 8)
    love.graphics.rectangle("line", w * 0.1 + 4, h * 0.1 + 4, w * 0.8 - 8, h * 0.8 - 8, 6, 6)

    -- Scan lines effect
    for i = 0, math.floor(h * 0.8 / 3) do
      local lineY = h * 0.1 + i * 3
      local scanAlpha = 0.03 + math.sin(time * 10 + i * 0.5) * 0.02
      love.graphics.setColor(0.1, 0.8, 0.4, scanAlpha)
      love.graphics.line(w * 0.1, lineY, w * 0.9, lineY)
    end

    -- "INCOMING TRANSMISSION" header with flashing
    local headerFlash = math.sin(time * 4) > 0
    if antennaOverlay.transmissionLine >= 1 and headerFlash then
      love.graphics.setFont(ui.getFont("small"))
      love.graphics.setColor(0.2, 1, 0.4, 0.9)
      love.graphics.printf("▸ INCOMING TRANSMISSION ◂", 0, h * 0.15, w, "center")
    end

    -- Signal bars in corner
    for i = 1, 4 do
      local barH = 5 + i * 4
      local barAlpha = 0.4 + math.sin(time * 2 + i) * 0.3
      love.graphics.setColor(0.2, 1, 0.4, barAlpha)
      love.graphics.rectangle("fill", w * 0.82 + (i - 1) * 10, h * 0.14 + (20 - barH), 6, barH)
    end

    -- Director portrait area (simple silhouette)
    local portraitX, portraitY = w * 0.2, h * 0.3
    love.graphics.setColor(0.05, 0.15, 0.08, 0.8)
    love.graphics.rectangle("fill", portraitX - 35, portraitY - 35, 70, 80, 5, 5)
    love.graphics.setColor(0.15, 0.5, 0.25, 0.6)
    love.graphics.rectangle("line", portraitX - 35, portraitY - 35, 70, 80, 5, 5)
    -- Silhouette head
    love.graphics.setColor(0.1, 0.35, 0.15, 0.9)
    love.graphics.circle("fill", portraitX, portraitY - 10, 18)
    -- Silhouette shoulders
    love.graphics.rectangle("fill", portraitX - 25, portraitY + 10, 50, 25, 6, 6)
    -- Name tag
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.2, 0.9, 0.4, 0.9)
    love.graphics.printf("THE DIRECTOR", portraitX - 40, portraitY + 50, 80, "center")

    -- Transmission text (typewriter reveal)
    love.graphics.setFont(ui.getFont("small"))
    local textX = w * 0.32
    local textStartY = h * 0.32
    local lineSpacing = 30

    for i = 1, math.min(antennaOverlay.transmissionLine, #antennaOverlay.transmissionLines) do
      local line = antennaOverlay.transmissionLines[i]
      if i == 1 then
        -- Skip the "INCOMING TRANSMISSION" line, it's the header
        goto continue
      end

      -- Check if it's a quote line (Director speaking)
      local isQuote = line:sub(1, 1) == '"'
      local isSignature = line:sub(1, 1) == '—'

      if isQuote then
        love.graphics.setColor(0.9, 0.95, 0.9, 0.95)
      elseif isSignature then
        love.graphics.setColor(0.3, 0.8, 0.5, 0.7)
        love.graphics.setFont(ui.getFont("hudLabel"))
      else
        love.graphics.setColor(0.5, 0.8, 0.6, 0.7)
      end

      -- Cursor blink on current line
      local displayLine = line
      if i == antennaOverlay.transmissionLine and math.sin(time * 6) > 0 then
        displayLine = displayLine .. "▌"
      end

      love.graphics.printf(displayLine, textX, textStartY + (i - 2) * lineSpacing, w * 0.55, "left")
      love.graphics.setFont(ui.getFont("small"))

      ::continue::
    end

    -- Continue prompt (show when all lines revealed)
    if antennaOverlay.transmissionLine >= #antennaOverlay.transmissionLines then
      local pulse = 0.4 + 0.4 * math.sin(time * 3)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(0.2, 0.8, 0.4, pulse)
      love.graphics.printf("Press ENTER to continue", 0, h * 0.85, w, "center")
    end

    love.graphics.setLineWidth(1)
  end
end

function M.updateAmplifierOverlay(dt)
  amplifierOverlay.timer = amplifierOverlay.timer + dt

  if amplifierOverlay.phase == "acquisition" then
    -- Fade in the overlay
    amplifierOverlay.fadeAlpha = math.min(1, amplifierOverlay.fadeAlpha + dt * 2)
    -- Grow amplifier glow
    amplifierOverlay.amplifierGlow = math.min(1, amplifierOverlay.amplifierGlow + dt * 1.5)

  elseif amplifierOverlay.phase == "transmission" then
    -- Typewriter-style reveal of transmission lines
    local lineDelay = 0.6
    local targetLine = math.floor(amplifierOverlay.timer / lineDelay) + 1
    if targetLine > #amplifierOverlay.transmissionLines then
      targetLine = #amplifierOverlay.transmissionLines
    end
    amplifierOverlay.transmissionLine = targetLine
  end
end

function M.drawAmplifierOverlay()
  local w = gameState.width
  local h = gameState.height
  local time = love.timer.getTime()
  local cx, cy = w / 2, h / 2

  if amplifierOverlay.phase == "acquisition" then
    local alpha = amplifierOverlay.fadeAlpha

    -- Dark background
    love.graphics.setColor(0, 0, 0, 0.92 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Radial electric blue glow behind amplifier
    local glowPulse = 0.25 + 0.12 * math.sin(time * 2.5)
    love.graphics.setColor(0.2, 0.5, 1, glowPulse * alpha * amplifierOverlay.amplifierGlow)
    love.graphics.circle("fill", cx, cy - 40, 160)
    love.graphics.setColor(0.1, 0.3, 0.8, glowPulse * 0.4 * alpha * amplifierOverlay.amplifierGlow)
    love.graphics.circle("fill", cx, cy - 40, 240)

    -- Electric spark particles
    for i = 1, 25 do
      local seed = i * 97.3
      local px = cx + math.sin(seed + time * 0.8) * (80 + i * 6)
      local py = cy - 40 + math.cos(seed * 1.3 + time * 0.6) * (60 + i * 4)
      local flicker = math.sin(time * 5 + seed) * 0.4 + 0.6
      local sz = 1 + math.sin(seed + time) * 0.8
      if i % 3 == 0 then
        love.graphics.setColor(0.4, 0.7, 1, flicker * alpha * amplifierOverlay.amplifierGlow)
      elseif i % 3 == 1 then
        love.graphics.setColor(0.3, 0.5, 1, flicker * alpha * amplifierOverlay.amplifierGlow)
      else
        love.graphics.setColor(0.6, 0.4, 1, flicker * alpha * amplifierOverlay.amplifierGlow)
      end
      love.graphics.circle("fill", px, py, sz)
    end

    -- Draw the Power Amplifier (procedural tech device)
    local scale = 3.5 * amplifierOverlay.amplifierGlow
    love.graphics.push()
    love.graphics.translate(cx, cy - 40)
    love.graphics.scale(scale, scale)
    local wobble = math.sin(time * 1.0) * 0.04
    love.graphics.rotate(wobble)

    -- Main housing (hexagonal tech module)
    love.graphics.setColor(0.4, 0.5, 0.65, alpha)
    love.graphics.polygon("fill",
      -15, -20, 15, -20,
      22, 0,
      15, 20, -15, 20,
      -22, 0)

    -- Inner core ring
    love.graphics.setColor(0.2, 0.3, 0.5, alpha)
    love.graphics.polygon("fill",
      -10, -14, 10, -14,
      16, 0,
      10, 14, -10, 14,
      -16, 0)

    -- Central power crystal
    local crystalGlow = math.sin(time * 4) * 0.3 + 0.7
    love.graphics.setColor(0.3 * crystalGlow, 0.7 * crystalGlow, 1 * crystalGlow, alpha)
    love.graphics.polygon("fill",
      0, -10, 8, 0, 0, 10, -8, 0)

    -- Energy conduits (top and bottom)
    love.graphics.setColor(0.5, 0.6, 0.75, alpha)
    love.graphics.setLineWidth(2.5 / scale)
    love.graphics.line(0, -20, 0, -32)
    love.graphics.line(0, 20, 0, 32)
    love.graphics.line(-22, 0, -30, 0)
    love.graphics.line(22, 0, 30, 0)

    -- Conduit tips with electric glow
    local tipGlow = math.sin(time * 6) * 0.3 + 0.7
    love.graphics.setColor(0.3, 0.7, 1, tipGlow * alpha)
    love.graphics.circle("fill", 0, -32, 3)
    love.graphics.circle("fill", 0, 32, 3)
    love.graphics.circle("fill", -30, 0, 2.5)
    love.graphics.circle("fill", 30, 0, 2.5)

    -- Electric arcs between conduit tips
    love.graphics.setColor(0.4, 0.8, 1, tipGlow * 0.5 * alpha)
    love.graphics.setLineWidth(1 / scale)
    for arc = 1, 3 do
      local arcPhase = math.fmod(time * 3 + arc * 0.8, 2)
      local arcRadius = arcPhase * 6
      local arcAlpha = (1 - arcPhase / 2) * 0.5 * tipGlow
      love.graphics.setColor(0.3, 0.7, 1, arcAlpha * alpha)
      love.graphics.circle("line", 0, -32, arcRadius)
    end

    -- Power level indicator bars on sides
    love.graphics.setColor(0.3, 0.6, 0.9, alpha * 0.7)
    for bar = 1, 4 do
      local barGlow = math.sin(time * 3 + bar * 0.8) * 0.3 + 0.7
      love.graphics.setColor(0.2, 0.5 * barGlow, 1 * barGlow, alpha * 0.8)
      love.graphics.rectangle("fill", -26, -12 + (bar - 1) * 7, 3, 5)
      love.graphics.rectangle("fill", 23, -12 + (bar - 1) * 7, 3, 5)
    end

    love.graphics.pop()

    -- "You got the Power Amplifier!" title with electric shimmer
    love.graphics.setFont(ui.getFont("subtitle"))
    local titleShimmer = math.sin(time * 2.5) * 0.1
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.8 * alpha)
    love.graphics.printf("You got the Power Amplifier!", 2, h * 0.62 + 2, w, "center")
    -- Electric blue text
    love.graphics.setColor(0.4, 0.8 + titleShimmer, 1, alpha)
    love.graphics.printf("You got the Power Amplifier!", 0, h * 0.62, w, "center")

    -- Subtitle
    love.graphics.setFont(ui.getFont("hud"))
    love.graphics.setColor(0.6, 0.8, 1, 0.8 * alpha)
    love.graphics.printf("A high-energy signal booster for the comms array.", 0, h * 0.70, w, "center")

    -- Continue prompt
    if alpha >= 0.9 then
      local pulse = 0.4 + 0.4 * math.sin(time * 3)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(0.4, 0.6, 0.8, pulse * alpha)
      love.graphics.printf("Press ENTER to continue", 0, h * 0.88, w, "center")
    end

  elseif amplifierOverlay.phase == "transmission" then
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Transmission border frame (cyan-tinted comm screen)
    local borderPulse = math.sin(time * 3) * 0.1 + 0.4
    love.graphics.setColor(0.1, 0.4, 0.7, borderPulse)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", w * 0.1, h * 0.1, w * 0.8, h * 0.8, 8, 8)
    love.graphics.rectangle("line", w * 0.1 + 4, h * 0.1 + 4, w * 0.8 - 8, h * 0.8 - 8, 6, 6)

    -- Scan lines effect
    for i = 0, math.floor(h * 0.8 / 3) do
      local lineY = h * 0.1 + i * 3
      local scanAlpha = 0.03 + math.sin(time * 10 + i * 0.5) * 0.02
      love.graphics.setColor(0.1, 0.5, 0.9, scanAlpha)
      love.graphics.line(w * 0.1, lineY, w * 0.9, lineY)
    end

    -- "INCOMING TRANSMISSION" header with flashing
    local headerFlash = math.sin(time * 4) > 0
    if amplifierOverlay.transmissionLine >= 1 and headerFlash then
      love.graphics.setFont(ui.getFont("small"))
      love.graphics.setColor(0.3, 0.7, 1, 0.9)
      love.graphics.printf("▸ INCOMING TRANSMISSION ◂", 0, h * 0.15, w, "center")
    end

    -- Signal bars in corner
    for i = 1, 4 do
      local barH = 5 + i * 4
      local barAlpha = 0.4 + math.sin(time * 2 + i) * 0.3
      love.graphics.setColor(0.3, 0.7, 1, barAlpha)
      love.graphics.rectangle("fill", w * 0.82 + (i - 1) * 10, h * 0.14 + (20 - barH), 6, barH)
    end

    -- Director portrait area (simple silhouette)
    local portraitX, portraitY = w * 0.2, h * 0.3
    love.graphics.setColor(0.05, 0.08, 0.18, 0.8)
    love.graphics.rectangle("fill", portraitX - 35, portraitY - 35, 70, 80, 5, 5)
    love.graphics.setColor(0.15, 0.35, 0.6, 0.6)
    love.graphics.rectangle("line", portraitX - 35, portraitY - 35, 70, 80, 5, 5)
    -- Silhouette head
    love.graphics.setColor(0.1, 0.2, 0.4, 0.9)
    love.graphics.circle("fill", portraitX, portraitY - 10, 18)
    -- Silhouette shoulders
    love.graphics.rectangle("fill", portraitX - 25, portraitY + 10, 50, 25, 6, 6)
    -- Name tag
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(0.3, 0.7, 1, 0.9)
    love.graphics.printf("THE DIRECTOR", portraitX - 40, portraitY + 50, 80, "center")

    -- Transmission text (typewriter reveal)
    love.graphics.setFont(ui.getFont("small"))
    local textX = w * 0.32
    local textStartY = h * 0.32
    local lineSpacing = 30

    for i = 1, math.min(amplifierOverlay.transmissionLine, #amplifierOverlay.transmissionLines) do
      local line = amplifierOverlay.transmissionLines[i]
      if i == 1 then
        -- Skip the "INCOMING TRANSMISSION" line, it's the header
        goto continue
      end

      -- Check if it's a quote line (Director speaking)
      local isQuote = line:sub(1, 1) == '"'
      local isSignature = line:sub(1, 1) == '—'

      if isQuote then
        love.graphics.setColor(0.85, 0.92, 1, 0.95)
      elseif isSignature then
        love.graphics.setColor(0.3, 0.6, 0.9, 0.7)
        love.graphics.setFont(ui.getFont("hudLabel"))
      else
        love.graphics.setColor(0.5, 0.7, 0.9, 0.7)
      end

      -- Cursor blink on current line
      local displayLine = line
      if i == amplifierOverlay.transmissionLine and math.sin(time * 6) > 0 then
        displayLine = displayLine .. "▌"
      end

      love.graphics.printf(displayLine, textX, textStartY + (i - 2) * lineSpacing, w * 0.55, "left")
      love.graphics.setFont(ui.getFont("small"))

      ::continue::
    end

    -- Continue prompt (show when all lines revealed)
    if amplifierOverlay.transmissionLine >= #amplifierOverlay.transmissionLines then
      local pulse = 0.4 + 0.4 * math.sin(time * 3)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.setColor(0.3, 0.6, 1, pulse)
      love.graphics.printf("Press ENTER to continue", 0, h * 0.85, w, "center")
    end

    love.graphics.setLineWidth(1)
  end
end

function M.keypressed(key)
  -- Handle antenna overlay input
  if antennaOverlay.phase == "acquisition" then
    if (key == "return" or key == "space") and antennaOverlay.fadeAlpha >= 0.9 then
      -- Advance to transmission
      antennaOverlay.phase = "transmission"
      antennaOverlay.timer = 0
      antennaOverlay.transmissionLine = 0
    end
    return
  elseif antennaOverlay.phase == "transmission" then
    if (key == "return" or key == "space") and antennaOverlay.transmissionLine >= #antennaOverlay.transmissionLines then
      -- Dismiss transmission
      antennaOverlay.phase = "done"
    end
    return
  end

  -- Handle amplifier overlay input
  if amplifierOverlay.phase == "acquisition" then
    if (key == "return" or key == "space") and amplifierOverlay.fadeAlpha >= 0.9 then
      -- Advance to transmission
      amplifierOverlay.phase = "transmission"
      amplifierOverlay.timer = 0
      amplifierOverlay.transmissionLine = 0
    end
    return
  elseif amplifierOverlay.phase == "transmission" then
    if (key == "return" or key == "space") and amplifierOverlay.transmissionLine >= #amplifierOverlay.transmissionLines then
      -- Dismiss transmission
      amplifierOverlay.phase = "done"
    end
    return
  end

  if gameState.state == "paused" then
    if key == "escape" then
      gameState.state = "playing"
    elseif key == "up" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex - 1
      if gameState.pauseMenuIndex < 1 then
        gameState.pauseMenuIndex = 4
      end
    elseif key == "down" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex + 1
      if gameState.pauseMenuIndex > 4 then
        gameState.pauseMenuIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.pauseMenuIndex == 1 then
        -- Resume
        gameState.state = "playing"
      elseif gameState.pauseMenuIndex == 2 then
        -- Restart Level: restore missiles to entry count and restart
        gameState.ship.missiles = gameState.ship.missileEntryCount
        M.startGame()
      elseif gameState.pauseMenuIndex == 3 then
        -- Options (placeholder)
        gameState.state = "playing"  -- For now, just resume
      elseif gameState.pauseMenuIndex == 4 then
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
    -- Handle police dialogue input
    if wanted.dialogueActive then
      if wanted.dialogueChoices then
        if key == "up" then
          wanted.dialogueChoiceIndex = wanted.dialogueChoiceIndex - 1
          if wanted.dialogueChoiceIndex < 1 then
            wanted.dialogueChoiceIndex = #wanted.dialogueChoices
          end
        elseif key == "down" then
          wanted.dialogueChoiceIndex = wanted.dialogueChoiceIndex + 1
          if wanted.dialogueChoiceIndex > #wanted.dialogueChoices then
            wanted.dialogueChoiceIndex = 1
          end
        elseif key == "return" or key == "space" then
          gameState.notes = wanted.advanceDialogue(gameState.width, gameState.height, gameState.notes)
        end
      elseif key == "return" or key == "space" then
        gameState.notes = wanted.advanceDialogue(gameState.width, gameState.height, gameState.notes)
      end
      return
    end

    -- Skip other input during busted state
    if wanted.bustedState then return end
    if wanted.sentenceActive then return end

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

        -- Fire missile if available, otherwise normal laser
        local useMissile = gameState.ship.missiles > 0
        if useMissile then
          gameState.ship.missiles = gameState.ship.missiles - 1
        end

        table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle, "player", useMissile))

        -- Multishot: fire two extra angled bullets (same type)
        if ship.hasMultishot(gameState.ship) then
          local spread = 0.2  -- radians (~11 degrees)
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle - spread, "player", useMissile))
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle + spread, "player", useMissile))
        end
      end
    elseif key == "x" and not gameState.ship.dead then
      local damaged = ship.hyperspace(gameState.ship, gameState.width, gameState.height)
      if damaged then
        gameState.health = gameState.health - 50
      end
    elseif key == "b" and not gameState.ship.dead and not gameState.ship.exploding then
      -- Smart bomb: two-press system
      if bombState.launched then
        -- Press #2: Detonate the bomb in flight
        M.triggerSmartBomb()
      elseif not bombState.active then
        -- Press #1: Launch a bomb projectile
        if ship.useBomb(gameState.ship) then
          M.launchBomb()
        end
      end
    elseif key == "s" and not gameState.ship.dead and not gameState.ship.exploding then
      -- S key press always toggles shield
      -- When Scan is unlocked, holding S also activates scanner (in updatePlaying)
      ship.toggleShield(gameState.ship)
    end
  end
end

-- ===================== POLICE SYSTEM DRAWING =====================

function M.drawWantedStars()
  if wanted.stars <= 0 then return end

  local startX = gameState.width / 2 - wanted.stars * 15
  local y = 15

  -- Background
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", startX - 10, y - 5, wanted.stars * 30 + 20, 25, 5, 5)

  -- Stars
  for i = 1, wanted.stars do
    local x = startX + (i - 1) * 30 + 10
    local flash = math.sin(love.timer.getTime() * 4 + i) * 0.2
    love.graphics.setColor(1, 0.8 + flash, 0)

    -- 5-pointed star shape
    local points = {}
    for j = 0, 4 do
      local outerAngle = (j * 2 * math.pi / 5) - math.pi / 2
      local innerAngle = outerAngle + math.pi / 5
      table.insert(points, x + math.cos(outerAngle) * 10)
      table.insert(points, y + 7 + math.sin(outerAngle) * 10)
      table.insert(points, x + math.cos(innerAngle) * 4)
      table.insert(points, y + 7 + math.sin(innerAngle) * 4)
    end
    love.graphics.polygon("fill", points)
  end
end

function M.drawBustedOverlay()
  local w, h = gameState.width, gameState.height

  if wanted.bustedState == "busted_msg" then
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- "BUSTED!" text
    local scale = 1.0 + math.sin(wanted.bustedTimer * 3) * 0.05
    love.graphics.push()
    love.graphics.translate(w / 2, h / 2)
    love.graphics.scale(scale, scale)
    love.graphics.setFont(ui.getFont("huge"))
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.printf("BUSTED!", -300, -40, 600, "center")
    love.graphics.pop()

    -- Red/blue flash at edges
    local flash = math.sin(wanted.bustedTimer * 12)
    if flash > 0 then
      love.graphics.setColor(1, 0, 0, 0.15)
    else
      love.graphics.setColor(0, 0, 1, 0.15)
    end
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif wanted.bustedState == "fade_white" then
    local alpha = wanted.bustedTimer / 1.0
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

  elseif wanted.bustedState == "fade_from_white" then
    local alpha = 1.0 - (wanted.bustedTimer / 1.0)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Police HQ background fading in
    love.graphics.setColor(0.1, 0.1, 0.15, 1.0 - alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

function M.drawPoliceDialogue()
  local w, h = gameState.width, gameState.height

  -- Dark background (Police HQ)
  love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Room details
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", w * 0.1, h * 0.05, w * 0.8, h * 0.5)
  love.graphics.setColor(0.2, 0.2, 0.3)
  love.graphics.rectangle("line", w * 0.1, h * 0.05, w * 0.8, h * 0.5)

  -- "POLICE HQ - MIXIA LEVEL 4" header
  love.graphics.setFont(ui.getFont("hud"))
  love.graphics.setColor(0.4, 0.5, 0.8)
  love.graphics.printf("POLICE HQ - MIXIA LEVEL 4", 0, h * 0.07, w, "center")

  -- NPC robot officer
  local npcX, npcY = w * 0.3, h * 0.25
  -- Body
  love.graphics.setColor(0.3, 0.4, 0.55)
  love.graphics.rectangle("fill", npcX - 30, npcY - 40, 60, 80, 8, 8)
  -- Badge
  love.graphics.setColor(0.8, 0.7, 0.2)
  love.graphics.circle("fill", npcX, npcY - 15, 8)
  -- Eye
  love.graphics.setColor(0.9, 0.3, 0.3)
  love.graphics.circle("fill", npcX, npcY - 30, 6)
  love.graphics.setColor(1, 0.5, 0.5, 0.5)
  love.graphics.circle("fill", npcX, npcY - 30, 4)

  -- Dialogue box
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle("fill", w * 0.1, h * 0.6, w * 0.8, h * 0.35, 10, 10)
  love.graphics.setColor(0.4, 0.5, 0.8)
  love.graphics.rectangle("line", w * 0.1, h * 0.6, w * 0.8, h * 0.35, 10, 10)

  -- Speaker name
  love.graphics.setFont(ui.getFont("small"))
  love.graphics.setColor(0.6, 0.8, 1)
  love.graphics.print(wanted.dialogueSpeaker, w * 0.13, h * 0.62)

  -- Dialogue text
  love.graphics.setFont(ui.getFont("hud"))
  love.graphics.setColor(1, 1, 1)
  if wanted.dialogueIndex <= #wanted.dialogueLines then
    love.graphics.printf(wanted.dialogueLines[wanted.dialogueIndex], w * 0.13, h * 0.68, w * 0.74, "left")
  end

  -- Choices
  if wanted.dialogueChoices then
    local choiceY = h * 0.78
    love.graphics.setFont(ui.getFont("hud"))
    for i, choice in ipairs(wanted.dialogueChoices) do
      if i == wanted.dialogueChoiceIndex then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> " .. choice.text, w * 0.15, choiceY + (i - 1) * 30, w * 0.7, "left")
      else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("  " .. choice.text, w * 0.15, choiceY + (i - 1) * 30, w * 0.7, "left")
      end
    end
  else
    -- "Press ENTER" prompt
    love.graphics.setFont(ui.getFont("hudLabel"))
    local promptAlpha = 0.5 + math.sin(love.timer.getTime() * 3) * 0.3
    love.graphics.setColor(0.6, 0.6, 0.8, promptAlpha)
    love.graphics.printf("Press ENTER to continue", w * 0.1, h * 0.9, w * 0.8, "right")
  end

  -- Fine animation popups
  if wanted.fineAnimation then
    love.graphics.setFont(ui.getFont("small"))
    for _, pop in ipairs(wanted.fineAnimation.popups) do
      local alpha = 1.0 - (pop.timer / pop.maxTimer)
      love.graphics.setColor(1, 0.2, 0.2, alpha)
      love.graphics.printf("-" .. pop.amount, w * 0.5, h * 0.55 + pop.y, 200, "center")
    end

    -- Notes display
    love.graphics.setFont(ui.getFont("hud"))
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.printf("Notes: " .. (gameState.notes or 0), 0, h * 0.57, w, "center")
  end
end

function M.drawWarningDialogue()
  local w, h = gameState.width, gameState.height

  -- Semi-transparent overlay to dim the game
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Red/blue flash at edges (police lights)
  local flash = math.sin(love.timer.getTime() * 8)
  if flash > 0 then
    love.graphics.setColor(1, 0, 0, 0.08)
  else
    love.graphics.setColor(0, 0, 1, 0.08)
  end
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Draw the patrol robot that caught the player at the top-center
  local robotX, robotY = w / 2, h * 0.2
  if wanted.bustedBy and not wanted.bustedBy.dead then
    robotX = wanted.bustedBy.x
    robotY = wanted.bustedBy.y
  end

  -- Dialogue box at bottom of screen
  local boxX = w * 0.08
  local boxY = h * 0.6
  local boxW = w * 0.84
  local boxH = h * 0.35

  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 10, 10)

  -- Border with police colors
  local borderFlash = math.sin(love.timer.getTime() * 6)
  if borderFlash > 0 then
    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
  else
    love.graphics.setColor(0.2, 0.2, 0.8, 0.8)
  end
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 10, 10)
  love.graphics.setLineWidth(1)

  -- Speaker name
  love.graphics.setFont(ui.getFont("small"))
  love.graphics.setColor(0.6, 0.8, 1)
  love.graphics.print(wanted.dialogueSpeaker, boxX + 15, boxY + 12)

  -- Dialogue text
  love.graphics.setFont(ui.getFont("hud"))
  love.graphics.setColor(1, 1, 1)
  if wanted.dialogueIndex <= #wanted.dialogueLines then
    love.graphics.printf(wanted.dialogueLines[wanted.dialogueIndex], boxX + 15, boxY + 45, boxW - 30, "left")
  end

  -- Choices
  if wanted.dialogueChoices then
    local choiceY = boxY + boxH * 0.45
    love.graphics.setFont(ui.getFont("hud"))
    for i, choice in ipairs(wanted.dialogueChoices) do
      if i == wanted.dialogueChoiceIndex then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> " .. choice.text, boxX + 30, choiceY + (i - 1) * 30, boxW - 60, "left")
      else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("  " .. choice.text, boxX + 30, choiceY + (i - 1) * 30, boxW - 60, "left")
      end
    end
  else
    -- "Press ENTER" prompt
    love.graphics.setFont(ui.getFont("hudLabel"))
    local promptAlpha = 0.5 + math.sin(love.timer.getTime() * 3) * 0.3
    love.graphics.setColor(0.6, 0.6, 0.8, promptAlpha)
    love.graphics.printf("Press ENTER to continue", boxX, boxY + boxH - 25, boxW - 10, "right")
  end
end

function M.drawSentenceCountdown()
  if not wanted.sentenceActive then return end

  local minutes = math.floor(wanted.sentenceTimer / 60)
  local seconds = math.floor(wanted.sentenceTimer % 60)
  local timeStr = string.format("%d:%02d", minutes, seconds)

  love.graphics.setFont(ui.getFont("huge"))
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(timeStr, 0, gameState.height / 2 - 30, gameState.width, "center")
end

function M.drawAgentSayonara()
  local w, h = gameState.width, gameState.height

  if wanted.agentSayonaraTimer <= 2.0 then
    -- "Sayonara!!" text from the agent
    love.graphics.setFont(ui.getFont("huge"))
    local flash = math.sin(wanted.agentSayonaraTimer * 8)
    if flash > 0 then
      love.graphics.setColor(1, 0.3, 0.3)
    else
      love.graphics.setColor(0.3, 0.3, 1)
    end
    love.graphics.printf("Sayonara!!", 0, h / 2 - 30, w, "center")
  else
    -- Agent warping out - draw warp effect at agent position
    for _, p in ipairs(wanted.patrols) do
      if p.patrolType == patrol.TYPE_AGENT and not p.dead then
        local progress = wanted.agentWarpTimer / 1.5
        local flashSize = p.size * (1 + progress * 3)
        local flashAlpha = 1.0 - progress

        love.graphics.setColor(0.3, 0.5, 1, flashAlpha)
        love.graphics.circle("line", p.x, p.y, flashSize)
        love.graphics.setColor(1, 1, 1, flashAlpha * 0.6)
        love.graphics.circle("fill", p.x, p.y, p.size * (1.0 - progress))

        for i = 1, 8 do
          local angle = (i / 8) * math.pi * 2 + love.timer.getTime() * 4
          local dist = flashSize * progress
          local px = p.x + math.cos(angle) * dist
          local py = p.y + math.sin(angle) * dist
          love.graphics.setColor(0.5, 0.7, 1, flashAlpha)
          love.graphics.circle("fill", px, py, 3)
        end
      end
    end
  end
end

return M
