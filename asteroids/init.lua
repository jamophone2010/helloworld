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
local dungeon = require("asteroids.dungeon")
local encounter = require("asteroids.encounter")
local kraken = require("asteroids.kraken")
local orionDungeon = require("asteroids.orion_dungeon")
local messierDungeon = require("asteroids.messier_dungeon")
local outerDungeon = require("asteroids.outer_dungeon")
local velaDungeon = require("asteroids.vela_dungeon")
local muses = require("kalapatthar.muses")

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
  callback = nil,
  color = {0, 0, 0}  -- Default to black
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

-- Orion dungeon: Spread Beam acquisition banner timer
local spreadBeamBannerTimer = 0
local hyperBeamBannerTimer = 0
local seekerMissileBannerTimer = 0

-- ===== ENCOUNTER SYSTEM STATE =====
local encounterState = {
  enemies = {},             -- active encounter enemies
  spawnTimer = 0,
  spawnInterval = 12,       -- seconds between spawn checks
  encounterActive = false,
  encounterMessage = "",
  encounterMessageTimer = 0,
  encounterMessageColor = {1, 0.6, 0.2},
  damageImmune = 0,         -- brief immunity after enemy hit
}

-- ===== KRAKEN BOSS STATE =====
local krakenState = nil        -- kraken instance (lazy init)
local krakenDefeated = false   -- persists across tiles
local hasTrident = false       -- permanent item flag
local tridentBannerTimer = 0   -- acquisition banner display

-- Combo score tracking
local comboState = {
  count = 0,
  timer = 0,
  maxTimer = 2.5,  -- seconds to keep combo alive
  multiplier = 1,
  displayTimer = 0,
}
-- Shield deflection flash timer
local shieldDeflectTimer = 0

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

-- Muse power B-hold tracking (hold B = Muse power, tap B = smart bomb)
local museBHoldTimer = 0
local MUSE_B_HOLD_THRESHOLD = 0.3  -- seconds before B counts as "held"
local museBHeld = false

-- Chain lightning visual effects (Djolt power)
local chainLightningArcs = {}

-- Missile AOE explosion state (visual effects queue)
local missileExplosions = {}
local MISSILE_AOE_RADIUS = 120
local MISSILE_DAMAGE_MULT = 2.0  -- Missiles deal 2x damage to asteroids (instant split)

-- ===================== PER-TILE STATE CACHE =====================
-- Preserves drops, asteroids, ufos, etc. when moving between sectors
local tileStateCache = {}

-- ===================== CHAIN LIGHTNING (Djolt Muse Power) =====================
-- When a bullet hits something, arc lightning to nearby enemies/asteroids
local function triggerChainLightning(hitX, hitY, skipIndex, targetType)
  if not muses.hasChainLightning() then return end

  local arcRange = 200
  local maxArcs = 3
  local arcDamage = 25
  local arcsUsed = 0

  -- Arc to nearby asteroids
  for i = #gameState.asteroids, 1, -1 do
    if arcsUsed >= maxArcs then break end
    local a = gameState.asteroids[i]
    if not (targetType == "asteroid" and i == skipIndex) then
      local dist = math.sqrt((hitX - a.x)^2 + (hitY - a.y)^2)
      if dist < arcRange then
        -- Visual arc
        table.insert(chainLightningArcs, {
          x1 = hitX, y1 = hitY, x2 = a.x, y2 = a.y,
          timer = 0.3,
          color = muses.MUSES.djolt.color,
        })
        -- Damage the asteroid (split it)
        local splits, score = asteroid.split(a)
        gameState.score = gameState.score + score
        for _, split in ipairs(splits) do
          table.insert(gameState.asteroids, split)
        end
        for _, p in ipairs(particle.new(a.x, a.y)) do
          table.insert(gameState.particles, p)
        end
        table.remove(gameState.asteroids, i)
        arcsUsed = arcsUsed + 1
      end
    end
  end

  -- Arc to nearby UFOs
  for i = #gameState.ufos, 1, -1 do
    if arcsUsed >= maxArcs then break end
    local u = gameState.ufos[i]
    if not (targetType == "ufo" and i == skipIndex) then
      local dist = math.sqrt((hitX - u.x)^2 + (hitY - u.y)^2)
      if dist < arcRange then
        table.insert(chainLightningArcs, {
          x1 = hitX, y1 = hitY, x2 = u.x, y2 = u.y,
          timer = 0.3,
          color = muses.MUSES.djolt.color,
        })
        gameState.score = gameState.score + u.score
        for _, p in ipairs(particle.new(u.x, u.y)) do
          table.insert(gameState.particles, p)
        end
        table.insert(gameState.powerups, powerup.new(u.x, u.y))
        table.remove(gameState.ufos, i)
        arcsUsed = arcsUsed + 1
      end
    end
  end
end

local function getTileCacheKey(x, y)
  return x .. "," .. y
end

-- Save current tile state before leaving
local function saveTileState(tileX, tileY)
  local key = getTileCacheKey(tileX, tileY)
  tileStateCache[key] = {
    asteroids = gameState.asteroids,
    ufos = gameState.ufos,
    powerups = gameState.powerups,
  }
end

-- Try to restore tile state when entering. Returns true if restored.
local function restoreTileState(tileX, tileY)
  local key = getTileCacheKey(tileX, tileY)
  local cached = tileStateCache[key]
  if not cached then return false end
  gameState.asteroids = cached.asteroids or {}
  gameState.ufos = cached.ufos or {}
  gameState.powerups = cached.powerups or {}
  tileStateCache[key] = nil  -- consume the cache entry
  return true
end

-- ===================== PUZZLE SECTOR BOUNDARY SYSTEM =====================
-- When entering a puzzle / miniboss sector, energy walls seal the sector
-- so the player bounces off edges. A lever near a corner can be shot to
-- deactivate the walls and allow the player to leave.
local sectorBoundary = {
  active = false,
  animTimer = 0,          -- activation animation progress
  animDuration = 1.5,     -- seconds for seal-in animation
  wallAlpha = 0,
  lever = nil,            -- {x, y, hit, flash}
  deactivating = false,
  deactTimer = 0,
  deactDuration = 1.0,
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
  gameState.pauseSubMenu = nil
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
function M.setProgression(antennaInstalled, sentinelDefeated, hasTrident)
  worldmap.setProgression(antennaInstalled, sentinelDefeated, hasTrident)
end

-- Get current ship state for cross-game sync (e.g. Spread Beam → StarFox)
function M.getShipData()
  return gameState.ship
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

  -- Clear tile state cache on fresh game start
  tileStateCache = {}
  sectorBoundary.active = false
  sectorBoundary.wallAlpha = 0

  -- Reset Muse combat state for new session
  muses.resetCombatState()
  museBHeld = false
  museBHoldTimer = 0
  chainLightningArcs = {}

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

  -- Reset encounter system
  encounterState.enemies = {}
  encounterState.spawnTimer = 0
  encounterState.encounterMessageTimer = 0
  encounterState.damageImmune = 0
  krakenState = nil

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

  -- Try to restore cached state (preserves drops, boss health, asteroids)
  local restored = restoreTileState(worldmap.tileX, worldmap.tileY)

  if not restored then
    -- Fresh spawn — no cached state
    if tile.type == worldmap.TILE_STATION then
      gameState.asteroids = {}
    elseif tile.type == worldmap.TILE_PORTAL then
      local count = worldmap.getAsteroidCount(baseCount)
      gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count, isOort)
    else
      local count = worldmap.getAsteroidCount(baseCount)
      gameState.asteroids = level.spawnAsteroids(gameState.level, gameState.width, gameState.height, count, isOort)
    end

    gameState.ufos = {}
    gameState.powerups = {}
  end

  -- Always clear bullets on transition (projectiles don't persist)
  gameState.bullets = {}

  -- Reset landing state
  landingState.hovering = false
  landingState.selectedPad = nil
  landingState.landingProgress = 0

  -- Reset portal state
  portalState.nearPortal = false
  portalState.portalInfo = nil

  -- Try to spawn patrol robots (1/10 chance, only if no existing patrols)
  if tile.type ~= worldmap.TILE_STATION and not restored then
    wanted.trySpawnOnTileLoad(gameState.width, gameState.height)
  end

  -- Activate puzzle if this tile has one (will preserve existing state)
  if not restored then
    puzzle.rewardDrop = nil  -- Clear any previous reward
  end
  puzzle.activatePuzzle(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)

  -- Activate boundary walls for puzzle / miniboss sectors
  local puzzleInfo = puzzle.getPuzzleAt(worldmap.tileX, worldmap.tileY)
  if puzzleInfo and not puzzle.isCompleted(worldmap.tileX, worldmap.tileY) then
    M.activateSectorBoundary()
  else
    sectorBoundary.active = false
    sectorBoundary.wallAlpha = 0
  end

  -- Initialize dungeon (maze walls, enemies, decorations) for dungeon tiles
  dungeon.init(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)

  -- Initialize Orion boss dungeon (places Spread Beam powerup on boss tile)
  local orionPowerup = orionDungeon.initTile(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)
  if orionPowerup then
    table.insert(gameState.powerups, orionPowerup)
  end
  local messierPowerup = messierDungeon.initTile(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)
  if messierPowerup then
    table.insert(gameState.powerups, messierPowerup)
  end
  local outerPowerup = outerDungeon.initTile(worldmap.tileX, worldmap.tileY, gameState.width, gameState.height)
  if outerPowerup then
    table.insert(gameState.powerups, outerPowerup)
  end

  -- Check if this is the Vela dungeon entrance tile
  if velaDungeon.isVelaDungeonTile(worldmap.tileX, worldmap.tileY) and not velaDungeon.isActive() then
    velaDungeon.enter(gameState.width, gameState.height)
  end

  -- ===== ENCOUNTER SYSTEM: roll for enemy spawns on tile entry =====
  if tile.type ~= worldmap.TILE_STATION and not restored then
    M.rollEncounterOnTileEntry()
  end
end

function M.transitionToTile(newX, newY, shipWrapX, shipWrapY)
  -- Save current tile state before leaving (preserves drops, boss HP, etc.)
  saveTileState(worldmap.tileX, worldmap.tileY)

  -- Clear encounter enemies (don't follow between tiles)
  encounterState.enemies = {}
  encounterState.spawnTimer = 0

  -- Deactivate Kraken if leaving tile (boss despawns)
  if krakenState and krakenState.active and not krakenState.dying then
    krakenState.active = false
  end

  worldmap.setPosition(newX, newY)
  -- Mark the new tile as discovered
  worldmap.markDiscovered(newX, newY)
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

-- ===================== SECTOR BOUNDARY SYSTEM =====================

function M.activateSectorBoundary()
  sectorBoundary.active = true
  sectorBoundary.animTimer = 0
  sectorBoundary.wallAlpha = 0
  sectorBoundary.deactivating = false
  sectorBoundary.deactTimer = 0
  -- Place lever in a corner (bottom-right, offset slightly inward)
  sectorBoundary.lever = {
    x = gameState.width - 50,
    y = gameState.height - 50,
    radius = 14,
    hit = false,
    flash = 0,
    glowTimer = 0,
  }
end

function M.updateSectorBoundary(dt)
  if not sectorBoundary.active then return end

  -- Seal-in animation
  if sectorBoundary.animTimer < sectorBoundary.animDuration then
    sectorBoundary.animTimer = sectorBoundary.animTimer + dt
    local t = math.min(1, sectorBoundary.animTimer / sectorBoundary.animDuration)
    sectorBoundary.wallAlpha = t
  else
    sectorBoundary.wallAlpha = 1
  end

  -- Deactivation animation
  if sectorBoundary.deactivating then
    sectorBoundary.deactTimer = sectorBoundary.deactTimer + dt
    local t = math.min(1, sectorBoundary.deactTimer / sectorBoundary.deactDuration)
    sectorBoundary.wallAlpha = 1 - t
    if t >= 1 then
      sectorBoundary.active = false
      sectorBoundary.wallAlpha = 0
    end
  end

  -- Update lever glow
  local lever = sectorBoundary.lever
  if lever and not lever.hit then
    lever.glowTimer = lever.glowTimer + dt
  end
  if lever and lever.flash > 0 then
    lever.flash = lever.flash - dt * 3
  end

  -- Check bullet collisions with the lever
  if lever and not lever.hit and not sectorBoundary.deactivating then
    for i = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[i]
      local dx = b.x - lever.x
      local dy = b.y - lever.y
      if dx * dx + dy * dy < (lever.radius + 6) * (lever.radius + 6) then
        lever.hit = true
        lever.flash = 1.0
        sectorBoundary.deactivating = true
        sectorBoundary.deactTimer = 0
        table.remove(gameState.bullets, i)
        break
      end
    end
  end

  -- Bounce player off walls when boundary is sealed (alpha > 0.5)
  if sectorBoundary.wallAlpha > 0.5 and not sectorBoundary.deactivating then
    local s = gameState.ship
    local margin = 8
    if s.x < margin then
      s.x = margin
      s.vx = math.abs(s.vx or 0) * 0.5
    end
    if s.x > gameState.width - margin then
      s.x = gameState.width - margin
      s.vx = -math.abs(s.vx or 0) * 0.5
    end
    if s.y < margin then
      s.y = margin
      s.vy = math.abs(s.vy or 0) * 0.5
    end
    if s.y > gameState.height - margin then
      s.y = gameState.height - margin
      s.vy = -math.abs(s.vy or 0) * 0.5
    end
  end
end

function M.drawSectorBoundary()
  if not sectorBoundary.active or sectorBoundary.wallAlpha <= 0 then return end
  local w = gameState.width
  local h = gameState.height
  local alpha = sectorBoundary.wallAlpha
  local t = love.timer.getTime()

  -- Energy wall lines along all four edges
  love.graphics.setLineWidth(3)
  -- Pulsing neon cyan/magenta
  local pulse = math.sin(t * 4) * 0.15
  local r, g, b = 0.2, 0.8, 1.0

  -- During seal-in animation, draw walls sweeping from corners
  local progress = math.min(1, sectorBoundary.animTimer / sectorBoundary.animDuration)
  if sectorBoundary.deactivating then
    progress = 1  -- walls fully visible during deact (just fading alpha)
  end

  -- Draw energy walls
  for layer = 1, 3 do
    local offset = layer * 2
    local a = alpha * (0.6 - layer * 0.15 + pulse)
    love.graphics.setColor(r, g, b, a)
    -- Top
    love.graphics.line(w * (0.5 - 0.5 * progress), offset, w * (0.5 + 0.5 * progress), offset)
    -- Bottom
    love.graphics.line(w * (0.5 - 0.5 * progress), h - offset, w * (0.5 + 0.5 * progress), h - offset)
    -- Left
    love.graphics.line(offset, h * (0.5 - 0.5 * progress), offset, h * (0.5 + 0.5 * progress))
    -- Right
    love.graphics.line(w - offset, h * (0.5 - 0.5 * progress), w - offset, h * (0.5 + 0.5 * progress))
  end

  -- Corner energy nodes (bright glowing corners)
  local cornerSize = 10 * alpha
  local corners = {{4, 4}, {w - 4, 4}, {4, h - 4}, {w - 4, h - 4}}
  for _, c in ipairs(corners) do
    love.graphics.setColor(0.4, 0.9, 1.0, alpha * (0.7 + pulse))
    love.graphics.circle("fill", c[1], c[2], cornerSize)
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    love.graphics.circle("fill", c[1], c[2], cornerSize * 0.4)
  end

  -- Scanning particle effect along walls
  if progress >= 1 and not sectorBoundary.deactivating then
    local scanPos = (t * 200) % (w * 2 + h * 2)
    local sx, sy
    if scanPos < w then
      sx, sy = scanPos, 2
    elseif scanPos < w + h then
      sx, sy = w - 2, scanPos - w
    elseif scanPos < w * 2 + h then
      sx, sy = w - (scanPos - w - h), h - 2
    else
      sx, sy = 2, h - (scanPos - w * 2 - h)
    end
    love.graphics.setColor(1, 1, 1, alpha * 0.9)
    love.graphics.circle("fill", sx, sy, 4)
    love.graphics.setColor(0.3, 0.9, 1.0, alpha * 0.4)
    love.graphics.circle("fill", sx, sy, 12)
  end

  -- Draw the lever
  local lever = sectorBoundary.lever
  if lever and not lever.hit then
    local glow = math.sin(lever.glowTimer * 3) * 0.3 + 0.7
    -- Lever base (mechanical switch look)
    love.graphics.setColor(0.3, 0.3, 0.3, alpha)
    love.graphics.circle("fill", lever.x, lever.y, lever.radius + 4)
    -- Lever body (red = active lock)
    love.graphics.setColor(1.0, 0.3, 0.2, alpha * glow)
    love.graphics.circle("fill", lever.x, lever.y, lever.radius)
    -- Inner core
    love.graphics.setColor(1.0, 0.6, 0.3, alpha * glow * 0.8)
    love.graphics.circle("fill", lever.x, lever.y, lever.radius * 0.5)
    -- "SHOOT" hint near lever
    love.graphics.setColor(1, 0.5, 0.3, alpha * glow * 0.6)
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.printf("◄ RELEASE", lever.x - 80, lever.y - 6, 70, "right")
    -- Pulsing ring
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1.0, 0.4, 0.2, alpha * glow * 0.5)
    love.graphics.circle("line", lever.x, lever.y, lever.radius + 8 + math.sin(lever.glowTimer * 5) * 3)
  elseif lever and lever.hit and lever.flash > 0 then
    -- Hit flash (green burst)
    love.graphics.setColor(0.2, 1.0, 0.4, lever.flash)
    love.graphics.circle("fill", lever.x, lever.y, lever.radius * 2 * (1 + (1 - lever.flash) * 2))
    love.graphics.setColor(1, 1, 1, lever.flash * 0.8)
    love.graphics.circle("fill", lever.x, lever.y, lever.radius * 0.5)
  end

  love.graphics.setLineWidth(1)
end

function M.startFade(callback)
  fadeState.active = true
  fadeState.alpha = 0
  fadeState.fadeIn = false
  fadeState.callback = callback
  fadeState.color = {0, 0, 0}  -- Black fade
end

function M.setFadeInFromWhite()
  fadeState.active = true
  fadeState.alpha = 1.0
  fadeState.fadeIn = true
  fadeState.callback = nil
  fadeState.color = {1, 1, 1}  -- White fade
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
  -- Track ship state to detect respawn after boss fight death
  local shipWasDead = gameState.ship.dead

  ship.update(gameState.ship, dt)

  -- If ship just respawned while in the Orion boss fight, redirect to dungeon entrance
  if shipWasDead and not gameState.ship.dead and not gameState.ship.exploding then
    if orionDungeon.getState() == "boss_fight" then
      -- Lose the Spread Beam
      gameState.ship.hasSpreadBeam = false
      -- Reset dungeon state (back to powerup_present)
      orionDungeon.onPlayerDied()
      -- Teleport to dungeon entrance tile
      local ex, ey = orionDungeon.getEntranceTile()
      gameState.ship.spawnX = gameState.width / 2
      gameState.ship.spawnY = gameState.height / 2
      gameState.ship.x     = gameState.width  / 2
      gameState.ship.y     = gameState.height / 2
      M.transitionToTile(ex, ey, gameState.width / 2, gameState.height / 2)
    end
    if messierDungeon.getState() == "boss_fight" then
      gameState.ship.hasHyperBeam = false
      messierDungeon.onPlayerDied()
      local ex, ey = messierDungeon.getEntranceTile()
      gameState.ship.spawnX = gameState.width / 2
      gameState.ship.spawnY = gameState.height / 2
      gameState.ship.x = gameState.width / 2
      gameState.ship.y = gameState.height / 2
      M.transitionToTile(ex, ey, gameState.width / 2, gameState.height / 2)
    end
    if outerDungeon.getBossState() == "boss_fight" then
      gameState.ship.hasSeeker = false
      outerDungeon.onPlayerDied()
      local ex, ey = outerDungeon.getEntranceTile()
      gameState.ship.spawnX = gameState.width / 2
      gameState.ship.spawnY = gameState.height / 2
      gameState.ship.x = gameState.width / 2
      gameState.ship.y = gameState.height / 2
      M.transitionToTile(ex, ey, gameState.width / 2, gameState.height / 2)
    end
  end

  -- Check for tile transitions instead of simple wrap
  -- Tierra Muse power: screen wrap within tile instead of transitioning
  if muses.hasScreenWrap() then
    ship.wrap(gameState.ship, gameState.width, gameState.height)
  else
  local transitioned, newTileX, newTileY, wrapX, wrapY =
    worldmap.checkEdgeTransition(gameState.ship.x, gameState.ship.y, gameState.width, gameState.height)

  -- Block transitions when sector boundary walls are sealed
  if transitioned and sectorBoundary.active and sectorBoundary.wallAlpha > 0.5 and not sectorBoundary.deactivating then
    transitioned = false
    -- Clamp ship to screen instead of transitioning
    wrapX = math.max(8, math.min(gameState.width - 8, gameState.ship.x))
    wrapY = math.max(8, math.min(gameState.height - 8, gameState.ship.y))
  end

  -- Block transitions when Orion dungeon boss room is sealed
  if transitioned and orionDungeon.isLocked() then
    transitioned = false
    wrapX = math.max(8, math.min(gameState.width - 8, gameState.ship.x))
    wrapY = math.max(8, math.min(gameState.height - 8, gameState.ship.y))
  end
  if transitioned and messierDungeon.isLocked() then
    transitioned = false
    wrapX = math.max(8, math.min(gameState.width - 8, gameState.ship.x))
    wrapY = math.max(8, math.min(gameState.height - 8, gameState.ship.y))
  end
  if transitioned and outerDungeon.isCombatLocked() then
    transitioned = false
    wrapX = math.max(8, math.min(gameState.width - 8, gameState.ship.x))
    wrapY = math.max(8, math.min(gameState.height - 8, gameState.ship.y))
  end
  if transitioned then
    if not outerDungeon.checkTransition(worldmap.tileX, worldmap.tileY, newTileX, newTileY) then
      transitioned = false
      wrapX = math.max(8, math.min(gameState.width - 8, gameState.ship.x))
      wrapY = math.max(8, math.min(gameState.height - 8, gameState.ship.y))
    end
  end

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
  end -- end of Tierra screen wrap else block

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

  -- Shield deflection flash decay
  if shieldDeflectTimer > 0 then
    shieldDeflectTimer = shieldDeflectTimer - dt
  end

  -- ===== CONSTELLATION HAZARD UPDATES =====
  M.updateConstellationHazards(dt)

  -- ===== SECTOR BOUNDARY UPDATE (puzzle/miniboss walls + lever) =====
  M.updateSectorBoundary(dt)

  -- ===== ORION DUNGEON UPDATE (Spread Beam boss fight) =====
  if spreadBeamBannerTimer > 0 then
    spreadBeamBannerTimer = spreadBeamBannerTimer - dt
  end
  local orionResult = orionDungeon.update(dt, gameState.ship, gameState.bullets, gameState.width, gameState.height)
  if orionResult then
    -- Add boss bullets to game bullet list
    if orionResult.bossBullets then
      for _, bb in ipairs(orionResult.bossBullets) do
        table.insert(gameState.bullets, bb)
      end
    end
  end

  -- ===== MESSIER DUNGEON UPDATE (Hyper Beam boss fight) =====
  if hyperBeamBannerTimer > 0 then
    hyperBeamBannerTimer = hyperBeamBannerTimer - dt
  end
  local messierResult = messierDungeon.update(dt, gameState.ship, gameState.bullets, gameState.width, gameState.height)
  if messierResult then
    if messierResult.bossBullets then
      for _, bb in ipairs(messierResult.bossBullets) do
        table.insert(gameState.bullets, bb)
      end
    end
  end

  -- ===== OUTER SPACE DUNGEON UPDATE (Seeker Missiles boss fight) =====
  if seekerMissileBannerTimer > 0 then
    seekerMissileBannerTimer = seekerMissileBannerTimer - dt
  end
  local outerResult = outerDungeon.update(dt, gameState.ship, gameState.bullets, gameState.width, gameState.height)
  if outerResult then
    if outerResult.bossBullets then
      for _, bb in ipairs(outerResult.bossBullets) do
        table.insert(gameState.bullets, bb)
      end
    end
  end

  -- Deactivate boundary when puzzle is completed
  if sectorBoundary.active and not sectorBoundary.deactivating then
    local puzzleInfo = puzzle.getPuzzleAt(worldmap.tileX, worldmap.tileY)
    if puzzleInfo and puzzle.isCompleted(worldmap.tileX, worldmap.tileY) then
      sectorBoundary.deactivating = true
      sectorBoundary.deactTimer = 0
    end
  end

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

  -- ===== MUSE POWERS =====
  muses.updateCombat(dt)

  -- B-hold detection: if B is held, track duration
  if museBHeld then
    museBHoldTimer = museBHoldTimer + dt
    if museBHoldTimer >= MUSE_B_HOLD_THRESHOLD and not muses.powerActive then
      -- Held long enough — activate Muse power (cancel the bomb if not yet launched)
      if muses.canActivate() then
        muses.activate()
      end
    end
  end

  -- Melo: override time scale when Muse time slow is active
  if muses.isTimeSlowed() then
    dtEff = dt * muses.getTimeScale()
  end

  -- Tierra: screen wrap instead of tile transition
  if muses.hasScreenWrap() and not gameState.ship.dead and not gameState.ship.exploding then
    ship.wrap(gameState.ship, gameState.width, gameState.height)
  end

  -- Djolt: update chain lightning visual arcs
  for i = #chainLightningArcs, 1, -1 do
    chainLightningArcs[i].timer = chainLightningArcs[i].timer - dt
    if chainLightningArcs[i].timer <= 0 then
      table.remove(chainLightningArcs, i)
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

  -- ===== ENCOUNTER SYSTEM =====
  M.updateEncounters(dtEff)

  -- ===== KRAKEN BOSS =====
  M.updateKraken(dtEff)

  for i = #gameState.bullets, 1, -1 do
    bullet.update(gameState.bullets[i], dt)
    bullet.wrap(gameState.bullets[i], gameState.width, gameState.height)

    -- Seeker missile homing logic
    local b = gameState.bullets[i]
    if b.isSeeker then
      local dx2 = b.vx; local dy2 = b.vy
      b.distanceTraveled = (b.distanceTraveled or 0) + math.sqrt(dx2*dx2 + dy2*dy2) * dt
      if (b.seekerState or "traveling") == "traveling" and b.distanceTraveled >= 400 then
        -- Find nearest unlocked target
        local bestTarget, bestDist = nil, math.huge
        for _, a in ipairs(gameState.asteroids) do
          if not a.seekerLocked then
            local adx = b.x - a.x; local ady = b.y - a.y
            local d = math.sqrt(adx*adx + ady*ady)
            if d < bestDist then bestTarget = a; bestDist = d end
          end
        end
        for _, u in ipairs(gameState.ufos) do
          if not u.seekerLocked then
            local udx = b.x - u.x; local udy = b.y - u.y
            local d = math.sqrt(udx*udx + udy*udy)
            if d < bestDist then bestTarget = u; bestDist = d end
          end
        end
        for _, t in ipairs(outerDungeon.getTargetList()) do
          if not t.entity.seekerLocked then
            local tdx = b.x - t.x; local tdy = b.y - t.y
            local d = math.sqrt(tdx*tdx + tdy*tdy)
            if d < bestDist then bestTarget = t.entity; bestDist = d end
          end
        end
        if bestTarget then
          b.seekerTarget = bestTarget
          bestTarget.seekerLocked = true
          b.seekerState = "tracking"
        end
      end
      if (b.seekerState or "traveling") == "tracking" then
        local tgt = b.seekerTarget
        if not tgt or tgt.dead or (tgt.hp and tgt.hp <= 0) then
          if tgt then tgt.seekerLocked = false end
          b.seekerTarget = nil
          b.seekerState = "traveling"
        else
          local tdx = tgt.x - b.x; local tdy = tgt.y - b.y
          local tdist = math.sqrt(tdx*tdx + tdy*tdy)
          if tdist > 0 then
            local spd = math.sqrt(b.vx*b.vx + b.vy*b.vy)
            local steer = 600
            b.vx = b.vx + (tdx/tdist) * steer * dt
            b.vy = b.vy + (tdy/tdist) * steer * dt
            local newSpd = math.sqrt(b.vx*b.vx + b.vy*b.vy)
            if newSpd > 0 then
              local cap = math.max(spd, 1000)
              b.vx = b.vx / newSpd * cap
              b.vy = b.vy / newSpd * cap
            end
          end
        end
      end
    end

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

  -- ===== DUNGEON SYSTEM UPDATE =====
  if dungeon.isActive() then
    dungeon.update(dt, gameState.width, gameState.height, gameState.ship.x, gameState.ship.y)

    -- Wall collision for ship
    if not gameState.ship.dead and not gameState.ship.exploding then
      local newX, newY, wallHit = dungeon.resolveWallCollision(
        gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
      if wallHit then
        gameState.ship.x = newX
        gameState.ship.y = newY
        -- Kill velocity into wall
        gameState.ship.vx = gameState.ship.vx * 0.3
        gameState.ship.vy = gameState.ship.vy * 0.3
      end

      -- Hazard zone damage
      local hazardDmg = dungeon.getHazardDamage(gameState.ship.x, gameState.ship.y)
      if hazardDmg > 0 then
        if gameState.ship.shieldActive then
          gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - hazardDmg * dt
          if gameState.ship.shieldEnergy <= 0 then
            gameState.ship.shieldEnergy = 0
            gameState.ship.shieldActive = false
          end
        else
          gameState.health = gameState.health - hazardDmg * dt
          if gameState.health <= 0 then ship.die(gameState.ship) end
        end
      end

      -- Sentry contact damage
      local sentryDmg = dungeon.checkShipCollision(gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
      if sentryDmg > 0 then
        if gameState.ship.shieldActive then
          gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - sentryDmg
          if gameState.ship.shieldEnergy <= 0 then
            gameState.ship.shieldEnergy = 0
            gameState.ship.shieldActive = false
          end
        else
          gameState.health = gameState.health - sentryDmg
          gameState.damageTimer = 3
          if gameState.health <= 0 then ship.die(gameState.ship) end
        end
      end
    end

    -- Turret shots → add as enemy bullets
    local turretShots = dungeon.getTurretShots(gameState.ship.x, gameState.ship.y, dt)
    for _, shot in ipairs(turretShots) do
      table.insert(gameState.bullets, {
        x = shot.x, y = shot.y,
        vx = shot.vx, vy = shot.vy,
        lifetime = 3,
        owner = "dungeon",
        dungeonBullet = true,
        damage = shot.damage,
        size = 4,
      })
    end

    -- Player bullets vs dungeon enemies
    local destroyed = dungeon.checkBulletCollisions(gameState.bullets)
    for _, d in ipairs(destroyed) do
      -- Spawn particles at destroyed enemy
      for _, p in ipairs(particle.new(d.x, d.y)) do
        table.insert(gameState.particles, p)
      end
      gameState.score = gameState.score + 150
    end

    -- Dungeon bullets hitting the player
    if not gameState.ship.dead and not gameState.ship.exploding then
      for i = #gameState.bullets, 1, -1 do
        local b = gameState.bullets[i]
        if b.dungeonBullet then
          local dist = math.sqrt((b.x - gameState.ship.x)^2 + (b.y - gameState.ship.y)^2)
          if dist < (gameState.ship.size or 12) + 4 then
            if gameState.ship.shieldActive then
              deflectBullet(b, 3)
            else
              local dmg = b.damage or 10
              gameState.health = gameState.health - dmg
              gameState.damageTimer = 3
              if gameState.health <= 0 then ship.die(gameState.ship) end
              table.remove(gameState.bullets, i)
            end
          end
        end
      end
    end
  end

  -- ===== VELA DUNGEON SYSTEM UPDATE =====
  if velaDungeon.isActive() then
    velaDungeon.update(dt, gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)

    -- Wall collision for ship
    if not gameState.ship.dead and not gameState.ship.exploding then
      local newX, newY, wallHit = velaDungeon.resolveShipWallCollision(
        gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
      if wallHit then
        gameState.ship.x = newX
        gameState.ship.y = newY
        gameState.ship.vx = gameState.ship.vx * 0.3
        gameState.ship.vy = gameState.ship.vy * 0.3
      end

      -- Player bullets vs dungeon enemies
      local destroyed = velaDungeon.checkBulletCollisions(gameState.bullets)
      for _, d in ipairs(destroyed) do
        for _, p in ipairs(particle.new(d.x, d.y)) do
          table.insert(gameState.particles, p)
        end
        gameState.score = gameState.score + (d.isBoss and 500 or 200)
      end

      -- Dungeon bullets / boss hitting the player
      local hits = velaDungeon.getPlayerHits(gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
      for _, hit in ipairs(hits) do
        if not gameState.ship.invulnerable then
          if gameState.ship.shieldActive then
            gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - hit.damage
            if gameState.ship.shieldEnergy <= 0 then
              gameState.ship.shieldEnergy = 0
              gameState.ship.shieldActive = false
            end
          else
            gameState.health = gameState.health - hit.damage
            gameState.damageTimer = 3
            if gameState.health <= 0 then ship.die(gameState.ship) end
          end
        end
      end

      -- Treasure room pickup = heal
      if velaDungeon.hasTreasure() then
        -- Handled by velaDungeon update (player proximity)
      end

      -- Firebird reward collected
      if velaDungeon.isRewardCollected() then
        -- Award the Firebird ship
        velaDungeon.exit()
        -- Mark Firebird as purchased/acquired in shipyard
        if M.onFirebirdAcquired then
          M.onFirebirdAcquired()
        end
      end
    end
  end

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

-- ===================== SHIELD DEFLECTION =====================
-- Reflects an enemy bullet off the shield back outward.
-- Drains shield energy proportional to damage and reverses bullet ownership.
local function deflectBullet(b, shieldDrain)
  -- Reflect: reverse velocity away from ship + slight random spread
  local dx = b.x - gameState.ship.x
  local dy = b.y - gameState.ship.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then dist = 1 end
  local nx, ny = dx / dist, dy / dist

  local speed = math.sqrt((b.vx or 0)^2 + (b.vy or 0)^2)
  if speed < 100 then speed = 300 end  -- ensure a minimum bounce speed
  local spread = (math.random() - 0.5) * 0.4  -- ±0.2 rad spread
  local angle = math.atan2(ny, nx) + spread
  b.vx = math.cos(angle) * speed * 1.2
  b.vy = math.sin(angle) * speed * 1.2

  -- Push bullet outside shield radius so it doesn't re-collide
  local shieldR = (gameState.ship.size or 12) * 1.8 + 4
  b.x = gameState.ship.x + nx * shieldR
  b.y = gameState.ship.y + ny * shieldR

  -- Change ownership so it can hit enemies
  b.owner = "player"
  b.enemyBullet = false
  b.dungeonBullet = false
  b.deflected = true
  b.lifetime = 2.0  -- give it fresh lifetime

  -- Drain shield energy (reduced cost since deflecting, not absorbing)
  local drain = shieldDrain or 3
  gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - drain
  if gameState.ship.shieldEnergy <= 0 then
    gameState.ship.shieldEnergy = 0
    gameState.ship.shieldActive = false
  end

  -- Trigger deflection flash
  shieldDeflectTimer = 0.15
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

  -- Deflection flash (bright white/cyan burst when bullet is reflected)
  if shieldDeflectTimer > 0 then
    local flashAlpha = shieldDeflectTimer / 0.15
    love.graphics.setColor(0.7, 0.9, 1, flashAlpha * 0.6)
    love.graphics.circle("fill", sx, sy, radius * 1.3)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, flashAlpha * 0.8)
    love.graphics.circle("line", sx, sy, radius)
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

  -- Firebird burn DoT: tick burn damage on burning patrol ships
  for _, p in ipairs(wanted.patrols) do
    if p.burnTimer and p.burnTimer > 0 and not p.dead then
      p.burnTimer = p.burnTimer - dt
      p.burnTickTimer = (p.burnTickTimer or 0) + dt
      if p.burnTickTimer >= 1.0 then
        p.burnTickTimer = p.burnTickTimer - 1.0
        local destroyed = patrol.damage(p, p.burnDamage or 1)
        if destroyed then
          gameState.score = gameState.score + p.score
          wanted.onPatrolDestroyed(p, gameState.width, gameState.height)
        end
      end
      if p.burnTimer <= 0 then
        p.burnTimer = nil
        p.burnDamage = nil
        p.burnTickTimer = nil
      end
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

-- ===================== ENCOUNTER SYSTEM =====================
-- Zone-based enemy spawning with Starfox-style formations

function M.rollEncounterOnTileEntry()
  local chances = encounter.getSpawnChances(worldmap.tileX, worldmap.tileY)

  -- Roll for each difficulty tier independently
  local spawnedAny = false

  -- Easy enemies
  if math.random() < chances.easy then
    local enemies = encounter.spawnFormation(encounter.DIFFICULTY_EASY,
      gameState.width, gameState.height, gameState.ship.x, gameState.ship.y)
    for _, e in ipairs(enemies) do
      table.insert(encounterState.enemies, e)
    end
    if #enemies > 0 then spawnedAny = true end
  end

  -- Medium enemies (additional, on top of easy)
  if chances.medium > 0 and math.random() < chances.medium then
    local enemies = encounter.spawnFormation(encounter.DIFFICULTY_MEDIUM,
      gameState.width, gameState.height, gameState.ship.x, gameState.ship.y)
    for _, e in ipairs(enemies) do
      table.insert(encounterState.enemies, e)
    end
    if #enemies > 0 then spawnedAny = true end
  end

  -- Hard enemies (additional)
  if chances.hard > 0 and math.random() < chances.hard then
    local enemies = encounter.spawnFormation(encounter.DIFFICULTY_HARD,
      gameState.width, gameState.height, gameState.ship.x, gameState.ship.y)
    for _, e in ipairs(enemies) do
      table.insert(encounterState.enemies, e)
    end
    if #enemies > 0 then spawnedAny = true end
  end

  -- Kraken (1/50 chance in Outer Space rings 4-5, only if not defeated)
  if chances.kraken > 0 and not krakenDefeated and math.random() < chances.kraken then
    krakenState = kraken.new(gameState.width, gameState.height)
    kraken.spawn(krakenState)
    encounterState.encounterMessage = "⚠ THE KRAKEN AWAKENS! ⚠"
    encounterState.encounterMessageTimer = 4.0
    encounterState.encounterMessageColor = {1, 0.2, 0.3}
    return  -- Kraken overrides normal encounters
  end

  if spawnedAny then
    encounterState.encounterMessage = "⚠ HOSTILE CONTACTS DETECTED!"
    encounterState.encounterMessageTimer = 3.0
    encounterState.encounterMessageColor = {1, 0.6, 0.2}
  end
end

function M.updateEncounters(dt)
  -- Don't run at stations/portals
  if worldmap.isAtStation() or worldmap.isAtPortal() then return end

  -- Encounter message timer
  if encounterState.encounterMessageTimer > 0 then
    encounterState.encounterMessageTimer = encounterState.encounterMessageTimer - dt
  end

  -- Damage immunity timer
  if encounterState.damageImmune > 0 then
    encounterState.damageImmune = encounterState.damageImmune - dt
  end

  -- Periodic spawn timer (additional waves while exploring)
  encounterState.spawnTimer = encounterState.spawnTimer + dt
  if encounterState.spawnTimer >= encounterState.spawnInterval then
    encounterState.spawnTimer = 0
    encounterState.spawnInterval = 10 + math.random() * 15  -- 10-25s between checks
    -- Only roll if fewer than 6 enemies on screen
    if #encounterState.enemies < 6 then
      M.rollEncounterOnTileEntry()
    end
  end

  -- Update enemies
  for i = #encounterState.enemies, 1, -1 do
    local e = encounterState.enemies[i]
    encounter.updateEnemy(e, dt, gameState.ship.x, gameState.ship.y, gameState.width, gameState.height)

    -- Update mines for bombers
    if e.mines and #e.mines > 0 then
      encounter.updateMines(e, dt)
    end

    -- Shoot at player
    local shots = encounter.getShots(e, gameState.ship.x, gameState.ship.y)
    for _, shot in ipairs(shots) do
      table.insert(gameState.bullets, shot)
    end

    -- Remove expired enemies (off-screen or explosion done)
    if encounter.isExplosionDone(e) then
      table.remove(encounterState.enemies, i)
    elseif not e.dead and encounter.isOffScreen(e, gameState.width, gameState.height, 300) then
      table.remove(encounterState.enemies, i)
    end
  end

  -- Bullet vs encounter enemies
  if not gameState.ship.dead and not gameState.ship.exploding then
    for bi = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[bi]
      if b.owner == "player" then
        for ei = #encounterState.enemies, 1, -1 do
          local e = encounterState.enemies[ei]
          if not e.dead and not e.warpingIn then
            local dx = b.x - e.x
            local dy = b.y - e.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < e.size + (b.size or 4) then
              local killed = encounter.takeDamage(e, b.damage or 1)
              if killed then
                gameState.score = gameState.score + e.score
                -- Chance to drop powerup
                if math.random() < 0.2 then
                  table.insert(gameState.powerups, powerup.new(e.x, e.y))
                end
              end
              table.remove(gameState.bullets, bi)
              break
            end
          end
        end
      end
    end
  end

  -- Enemy bullets hitting the player
  if not gameState.ship.dead and not gameState.ship.exploding and encounterState.damageImmune <= 0 then
    for bi = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[bi]
      if b.enemyBullet then
        local dx = b.x - gameState.ship.x
        local dy = b.y - gameState.ship.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < (gameState.ship.size or 12) + (b.size or 4) then
          if gameState.ship.shieldActive then
            deflectBullet(b, 3)
          else
            local dmg = b.damage or 8
            gameState.health = gameState.health - dmg
            gameState.damageTimer = 3
            if gameState.health <= 0 then ship.die(gameState.ship) end
            table.remove(gameState.bullets, bi)
          end
          encounterState.damageImmune = 0.3  -- brief immunity
        end
      end
    end
  end

  -- Contact damage from enemies
  if not gameState.ship.dead and not gameState.ship.exploding and encounterState.damageImmune <= 0 then
    for _, e in ipairs(encounterState.enemies) do
      if not e.dead and not e.warpingIn then
        local dx = gameState.ship.x - e.x
        local dy = gameState.ship.y - e.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < (gameState.ship.size or 12) + e.size then
          local dmg = 10
          if gameState.ship.shieldActive then
            gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - dmg
            if gameState.ship.shieldEnergy <= 0 then
              gameState.ship.shieldEnergy = 0
              gameState.ship.shieldActive = false
            end
          else
            gameState.health = gameState.health - dmg
            gameState.damageTimer = 3
            if gameState.health <= 0 then ship.die(gameState.ship) end
          end
          encounterState.damageImmune = 0.5
        end

        -- Mine collision
        if e.mines then
          local mineDmg = encounter.checkMineCollision(e, gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
          if mineDmg > 0 then
            if gameState.ship.shieldActive then
              gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - mineDmg
              if gameState.ship.shieldEnergy <= 0 then
                gameState.ship.shieldEnergy = 0
                gameState.ship.shieldActive = false
              end
            else
              gameState.health = gameState.health - mineDmg
              gameState.damageTimer = 3
              if gameState.health <= 0 then ship.die(gameState.ship) end
            end
          end
        end
      end
    end
  end
end

-- ===================== KRAKEN BOSS UPDATE =====================

function M.updateKraken(dt)
  if not krakenState or not krakenState.active then
    -- Check for Trident drop pickup
    if krakenState and kraken.hasTridentDrop(krakenState) then
      local collected = kraken.updateTridentDrop(krakenState, dt,
        gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
      if collected then
        hasTrident = true
        krakenDefeated = true
        constellation.hasTrident = true
        tridentBannerTimer = 5.0
        encounterState.encounterMessage = "🔱 THE TRIDENT ACQUIRED!"
        encounterState.encounterMessageTimer = 4.0
        encounterState.encounterMessageColor = {0.4, 0.8, 1.0}
      end
    end
    return
  end

  kraken.update(krakenState, dt, gameState.ship.x, gameState.ship.y)

  -- Vortex pull on player
  if krakenState.vortexActive and not gameState.ship.dead and not gameState.ship.exploding then
    local pullX, pullY = kraken.getVortexPull(krakenState, gameState.ship.x, gameState.ship.y)
    gameState.ship.vx = gameState.ship.vx + pullX * dt
    gameState.ship.vy = gameState.ship.vy + pullY * dt
  end

  -- Player bullets vs Kraken
  if not gameState.ship.dead and not gameState.ship.exploding then
    for bi = #gameState.bullets, 1, -1 do
      local b = gameState.bullets[bi]
      if b.owner == "player" then
        if kraken.checkBulletHit(krakenState, b.x, b.y, b.size or 4) then
          local defeated = kraken.takeDamage(krakenState, b.damage or 1)
          if defeated then
            gameState.score = gameState.score + 5000
          end
          table.remove(gameState.bullets, bi)
        end
      end
    end
  end

  -- Kraken damage to player
  if not gameState.ship.dead and not gameState.ship.exploding and encounterState.damageImmune <= 0 then
    -- Tentacle / body contact damage
    local contactDmg = kraken.checkTentacleDamage(krakenState,
      gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
    if contactDmg > 0 then
      if gameState.ship.shieldActive then
        gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - contactDmg
        if gameState.ship.shieldEnergy <= 0 then
          gameState.ship.shieldEnergy = 0
          gameState.ship.shieldActive = false
        end
      else
        gameState.health = gameState.health - contactDmg
        gameState.damageTimer = 3
        if gameState.health <= 0 then ship.die(gameState.ship) end
      end
      encounterState.damageImmune = 0.5
    end

    -- Ink damage
    local inkDmg = kraken.checkInkDamage(krakenState,
      gameState.ship.x, gameState.ship.y, gameState.ship.size or 12)
    if inkDmg > 0 and encounterState.damageImmune <= 0 then
      if gameState.ship.shieldActive then
        gameState.ship.shieldEnergy = gameState.ship.shieldEnergy - inkDmg
        if gameState.ship.shieldEnergy <= 0 then
          gameState.ship.shieldEnergy = 0
          gameState.ship.shieldActive = false
        end
      else
        gameState.health = gameState.health - inkDmg
        gameState.damageTimer = 3
        if gameState.health <= 0 then ship.die(gameState.ship) end
      end
      encounterState.damageImmune = 0.3
    end
  end

  -- Trident banner timer
  if tridentBannerTimer > 0 then
    tridentBannerTimer = tridentBannerTimer - dt
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
        -- Firebird meltsIce: icy asteroids shatter completely (no splits)
        local inIcy = constellation.getAsteroidVisuals(worldmap.tileX, worldmap.tileY).icy
        local melt = inIcy and b.meltsIce
        local splits, score
        if melt then
          splits = {}  -- No child asteroids when melting ice
          score = asteroid.SIZES[a.size] and asteroid.SIZES[a.size].score or 100
          -- Bonus score for melting
          score = math.floor(score * 1.5)
        else
          splits, score = asteroid.split(a)
        end

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

        -- Extra steam particles when melting icy asteroids
        if melt then
          for k = 1, 8 do
            local angle = (k / 8) * math.pi * 2
            local speed = 30 + math.random() * 50
            table.insert(gameState.particles, {
              x = a.x, y = a.y,
              vx = math.cos(angle) * speed,
              vy = math.sin(angle) * speed,
              lifetime = 0.8 + math.random() * 0.5,
              maxLife = 1.3,
              size = 3 + math.random() * 3,
              color = {0.5, 0.8, 1.0},
              alpha = 0.7,
            })
          end
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

        -- Chain lightning: arc to nearby targets (Djolt Muse power)
        triggerChainLightning(a.x, a.y, j, "asteroid")

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

        -- Chain lightning: arc to nearby targets (Djolt Muse power)
        triggerChainLightning(u.x, u.y, j, "ufo")

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
            deflectBullet(b, 4)
          else
            gameState.health = gameState.health - 15
            gameState.damageTimer = 3
            table.remove(gameState.bullets, i)

            -- Check if health depleted
            if gameState.health <= 0 then
              ship.die(gameState.ship)
            end
          end
        end
      elseif b.owner == "boss" then
        -- Orion dungeon boss bullets damage the player
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)
        if dist < gameState.ship.size + (b.size or 5) then
          if gameState.ship.shieldActive then
            deflectBullet(b, 5)
          else
            local dmg = b.damage or 15
            gameState.health = gameState.health - dmg
            gameState.damageTimer = 3
            if gameState.health <= 0 then
              ship.die(gameState.ship)
            end
            table.remove(gameState.bullets, i)
          end
          gameState.ship.shieldTimer = 0.3
          gameState.ship.invulnerable = true
        end
      elseif b.owner == "boss_messier" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)
        if dist < gameState.ship.size + (b.size or 6) then
          if gameState.ship.shieldActive then
            deflectBullet(b, 5)
          else
            local dmg = b.damage or 15
            gameState.health = gameState.health - dmg
            gameState.damageTimer = 3
            if gameState.health <= 0 then ship.die(gameState.ship) end
            table.remove(gameState.bullets, i)
          end
          gameState.ship.shieldTimer = 0.3
          gameState.ship.invulnerable = true
        end
      elseif b.owner == "boss_outer" then
        local dist = math.sqrt((gameState.ship.x - b.x)^2 + (gameState.ship.y - b.y)^2)
        if dist < gameState.ship.size + (b.size or 5) then
          if gameState.ship.shieldActive then
            deflectBullet(b, 5)
          else
            local dmg = b.damage or 12
            gameState.health = gameState.health - dmg
            gameState.damageTimer = 3
            if gameState.health <= 0 then ship.die(gameState.ship) end
            table.remove(gameState.bullets, i)
          end
          gameState.ship.shieldTimer = 0.3
          gameState.ship.invulnerable = true
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
        if result.spreadbeam then
          -- Trigger boss fight: seal the tile and spawn the boss
          orionDungeon.onSpreadBeamCollected()
          spreadBeamBannerTimer = 3.0
        end
        if result.hyperbeam then
          messierDungeon.onHyperBeamCollected()
          hyperBeamBannerTimer = 3.0
        end
        if result.seeker then
          outerDungeon.onSeekerMissilesCollected()
          seekerMissileBannerTimer = 3.0
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
            -- Apply Firebird burn DoT on hit
            if not destroyed and b.burnDamage and b.burnDuration then
              p.burnDamage = b.burnDamage
              p.burnTimer = b.burnDuration
            end
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
            -- Shield deflects patrol bullets
            deflectBullet(b, 4)
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
            table.remove(gameState.bullets, i)
          end
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
    local color = fadeState.color or {0, 0, 0}
    love.graphics.setColor(color[1], color[2], color[3], fadeState.alpha)
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

  elseif shipType == "Muscle" then
    -- 1969 Pontiac GTO-inspired: wide, aggressive, muscular lines
    -- Hood scoop and split grille silhouette — viewed top-down as a spaceship

    -- Main body — wide, flat, aggressive GTO-style proportions
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.polygon("fill",
      0, -sz * 1.1,                    -- nose tip
      -sz * 0.25, -sz * 0.7,          -- fender line start
      -sz * 0.55, -sz * 0.15,         -- wide shoulder (GTO fender bulge)
      -sz * 0.55, sz * 0.5,           -- rear quarter panel
      -sz * 0.35, sz * 0.65,          -- rear taper
      0, sz * 0.55,                    -- rear center
      sz * 0.35, sz * 0.65,
      sz * 0.55, sz * 0.5,
      sz * 0.55, -sz * 0.15,
      sz * 0.25, -sz * 0.7
    )

    -- Hood scoop (raised center ridge — the GTO's signature)
    love.graphics.setColor(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6)
    love.graphics.polygon("fill",
      0, -sz * 0.9,
      -sz * 0.08, -sz * 0.5,
      -sz * 0.10, -sz * 0.1,
      sz * 0.10, -sz * 0.1,
      sz * 0.08, -sz * 0.5
    )

    -- Fender flares — wide muscular wings
    love.graphics.setColor(accent[1] * 0.8, accent[2] * 0.8, accent[3] * 0.8, 0.85)
    love.graphics.polygon("fill",
      -sz * 0.5, -sz * 0.1,
      -sz * 1.0, sz * 0.2,
      -sz * 0.95, sz * 0.45,
      -sz * 0.52, sz * 0.45
    )
    love.graphics.polygon("fill",
      sz * 0.5, -sz * 0.1,
      sz * 1.0, sz * 0.2,
      sz * 0.95, sz * 0.45,
      sz * 0.52, sz * 0.45
    )

    -- Rear spoiler ridge
    love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5)
    love.graphics.rectangle("fill", -sz * 0.45, sz * 0.52, sz * 0.9, sz * 0.08)

    -- Split grille detail (twin nostril look)
    love.graphics.setColor(0.15, 0.05, 0.05, 0.8)
    love.graphics.rectangle("fill", -sz * 0.18, -sz * 0.75, sz * 0.12, sz * 0.12)
    love.graphics.rectangle("fill",  sz * 0.06, -sz * 0.75, sz * 0.12, sz * 0.12)

    -- Headlight accents (hidden headlights popped up)
    love.graphics.setColor(1, 0.85, 0.5, 0.6 + math.sin(t * 4) * 0.2)
    love.graphics.circle("fill", -sz * 0.3, -sz * 0.55, 3)
    love.graphics.circle("fill",  sz * 0.3, -sz * 0.55, 3)

    -- Cockpit (tinted T-top style)
    love.graphics.setColor(0.3, 0.15, 0.1, 0.8)
    love.graphics.polygon("fill",
      0, -sz * 0.4,
      -sz * 0.15, -sz * 0.1,
      -sz * 0.15, sz * 0.15,
      sz * 0.15, sz * 0.15,
      sz * 0.15, -sz * 0.1
    )

    -- Gentle red fire effect — subtle heat shimmer emanating from the ship
    local fireGlow = math.sin(t * 3) * 0.15 + 0.35
    -- Soft outer aura
    love.graphics.setColor(0.9, 0.15, 0.05, fireGlow * 0.08)
    love.graphics.circle("fill", 0, 0, sz * 1.4)
    -- Warm inner glow
    love.graphics.setColor(1, 0.3, 0.08, fireGlow * 0.12)
    love.graphics.circle("fill", 0, 0, sz * 0.8)
    -- Flickering ember wisps around the hull
    for fi = 1, 6 do
      local fAngle = t * 1.5 + fi * 1.047  -- evenly spaced
      local fDist = sz * (0.6 + math.sin(t * 4 + fi * 2) * 0.15)
      local fx = math.cos(fAngle) * fDist
      local fy = math.sin(fAngle) * fDist
      local fAlpha = 0.15 + math.sin(t * 6 + fi * 3) * 0.1
      love.graphics.setColor(1, 0.35 + math.sin(t * 5 + fi) * 0.15, 0.05, fAlpha)
      love.graphics.circle("fill", fx, fy, 2 + math.sin(t * 7 + fi) * 0.8)
    end

    -- Racing stripe down center (GTO aesthetic)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, -sz * 1.0, 0, sz * 0.5)
    love.graphics.setLineWidth(1)

    -- Hull outline highlight
    love.graphics.setColor(1, 0.4, 0.15, 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
      0, -sz * 1.1,
      -sz * 0.25, -sz * 0.7,
      -sz * 0.55, -sz * 0.15,
      -sz * 0.55, sz * 0.5,
      -sz * 0.35, sz * 0.65,
      0, sz * 0.55,
      sz * 0.35, sz * 0.65,
      sz * 0.55, sz * 0.5,
      sz * 0.55, -sz * 0.15,
      sz * 0.25, -sz * 0.7
    )
    love.graphics.setLineWidth(1)

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
  local hx = 10  -- HUD left margin
  local hy = 8   -- HUD top margin
  local panelW = 320
  local barW = 300
  local barH = 44

  -- ─── Background panel ───
  love.graphics.setColor(0.05, 0.05, 0.1, 0.55)
  -- Calculate panel height dynamically
  local panelH = 220
  -- Count active powerups to extend panel
  local powerupCount = 0
  if ship.hasMultishot(gameState.ship) then powerupCount = powerupCount + 1 end
  if ship.hasSpeedBoost(gameState.ship) then powerupCount = powerupCount + 1 end
  if ship.hasMagnet(gameState.ship) then powerupCount = powerupCount + 1 end
  if gameState.ship.rapidFireTimer > 0 then powerupCount = powerupCount + 1 end
  if timeSlowState.active then powerupCount = powerupCount + 1 end
  if ship.hasSpreadBeam(gameState.ship) then powerupCount = powerupCount + 1 end
  if ship.hasHyperBeam(gameState.ship) then powerupCount = powerupCount + 1 end
  if ship.hasSeeker(gameState.ship) then powerupCount = powerupCount + 1 end
  if powerupCount > 0 then panelH = panelH + 6 + powerupCount * 18 end
  love.graphics.rectangle("fill", hx - 4, hy - 4, panelW, panelH, 6, 6)
  love.graphics.setColor(0.3, 0.4, 0.6, 0.25)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", hx - 4, hy - 4, panelW, panelH, 6, 6)

  -- ─── Health bar ───
  local healthPercent = math.max(0, gameState.health / gameState.maxHealth)
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", hx, hy, barW, barH, 4, 4)
  if healthPercent > 0.5 then
    love.graphics.setColor(0.2, 0.8, 0.3)
  elseif healthPercent > 0.25 then
    love.graphics.setColor(0.9, 0.7, 0.1)
  else
    love.graphics.setColor(0.9, 0.2, 0.2)
  end
  love.graphics.rectangle("fill", hx, hy, barW * healthPercent, barH, 4, 4)
  love.graphics.setColor(0.5, 0.5, 0.6, 0.6)
  love.graphics.rectangle("line", hx, hy, barW, barH, 4, 4)
  love.graphics.setFont(ui.getFont("hud"))
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.printf(math.floor(gameState.health) .. " / " .. gameState.maxHealth, hx, hy + 12, barW, "center")

  -- ─── Lives ───
  local livesY = hy + barH + 8
  love.graphics.setFont(ui.getFont("hud"))
  love.graphics.setColor(0.7, 0.7, 0.8, 0.7)
  love.graphics.print("LIVES", hx, livesY)
  for i = 1, (gameState.ship.lives or 0) do
    local lx = hx + 68 + (i - 1) * 32
    local ly = livesY + 10
    love.graphics.setColor(0.3, 0.5, 1.0, 0.9)
    love.graphics.polygon("fill",
      lx, ly - 12,
      lx - 10, ly + 8,
      lx, ly + 3,
      lx + 10, ly + 8
    )
  end

  -- ─── Divider ───
  local divY = livesY + 32
  love.graphics.setColor(0.3, 0.4, 0.5, 0.3)
  love.graphics.line(hx, divY, hx + barW, divY)

  -- ─── Shield bar ───
  local shieldY = divY + 5
  local shieldW = 260
  local shieldH = 32
  local shieldPct = gameState.ship.shieldEnergy / gameState.ship.shieldMaxEnergy
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", hx, shieldY, shieldW, shieldH, 3, 3)
  if gameState.ship.shieldActive then
    love.graphics.setColor(0.3, 0.6, 1, 0.9)
  else
    love.graphics.setColor(0.2, 0.4, 0.7, 0.6)
  end
  love.graphics.rectangle("fill", hx, shieldY, shieldW * shieldPct, shieldH, 3, 3)
  love.graphics.setColor(0.4, 0.6, 0.9, 0.5)
  love.graphics.rectangle("line", hx, shieldY, shieldW, shieldH, 3, 3)
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.8, 0.9, 1, 0.8)
  love.graphics.printf("SHIELD [S]", hx, shieldY + 8, shieldW, "center")

  -- ─── Missiles + Bombs ───
  local ammoY = shieldY + shieldH + 10
  love.graphics.setFont(ui.getFont("hud"))

  if gameState.ship.maxMissiles > 0 then
    love.graphics.setColor(1, 0.35, 0.1, 0.9)
    love.graphics.print("MISSILES x " .. gameState.ship.missiles, hx, ammoY)
    ammoY = ammoY + 22
  end

  local bombCount = gameState.ship.bombs or 0
  if bombCount > 0 then
    love.graphics.setColor(0.75, 0.75, 0.8, 0.9)
  else
    love.graphics.setColor(0.4, 0.4, 0.45, 0.5)
  end
  love.graphics.print("BOMB x " .. bombCount, hx, ammoY)

  -- ─── Active powerups ───
  local activeY = ammoY + 28
  if powerupCount > 0 then
    love.graphics.setColor(0.3, 0.4, 0.5, 0.3)
    love.graphics.line(hx, activeY - 2, hx + barW, activeY - 2)
    activeY = activeY + 3

    love.graphics.setFont(ui.getFont("hudLabel"))
    if ship.hasMultishot(gameState.ship) then
      love.graphics.setColor(1, 0.2, 0.8, 0.9)
      love.graphics.print("● MULTI-SHOT " .. math.ceil(gameState.ship.multishotTimer) .. "s", hx, activeY)
      activeY = activeY + 18
    end
    if ship.hasSpeedBoost(gameState.ship) then
      love.graphics.setColor(0.2, 1, 1, 0.9)
      love.graphics.print("● SPEED BOOST " .. math.ceil(gameState.ship.speedBoostTimer) .. "s", hx, activeY)
      activeY = activeY + 18
    end
    if ship.hasMagnet(gameState.ship) then
      love.graphics.setColor(1, 1, 0.2, 0.9)
      love.graphics.print("● MAGNET " .. math.ceil(gameState.ship.magnetTimer) .. "s", hx, activeY)
      activeY = activeY + 18
    end
    if gameState.ship.rapidFireTimer > 0 then
      love.graphics.setColor(1, 0.5, 0, 0.9)
      love.graphics.print("● RAPID FIRE " .. math.ceil(gameState.ship.rapidFireTimer) .. "s", hx, activeY)
      activeY = activeY + 18
    end
    if timeSlowState.active then
      love.graphics.setColor(0.6, 0.3, 1, 0.9)
      love.graphics.print("● TIME WARP " .. math.ceil(timeSlowState.timer) .. "s", hx, activeY)
      activeY = activeY + 18
    end
    if ship.hasSpreadBeam(gameState.ship) then
      love.graphics.setColor(0.2, 1.0, 0.5, 0.9)
      love.graphics.print("≋ SPREAD BEAM", hx, activeY)
      activeY = activeY + 18
    end
    if ship.hasHyperBeam(gameState.ship) then
      love.graphics.setColor(0.3, 0.9, 1.0, 0.9)
      love.graphics.print("◈ HYPER BEAM", hx, activeY)
      activeY = activeY + 18
    end
    if ship.hasSeeker(gameState.ship) then
      love.graphics.setColor(0.8, 0.2, 0.2, 0.9)
      love.graphics.print("⟳ SEEKER MISSILES", hx, activeY)
      activeY = activeY + 18
    end
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

  -- Encounter warning message
  if encounterState.encounterMessageTimer > 0 then
    love.graphics.setFont(ui.getFont("medium"))
    local alpha = math.min(1, encounterState.encounterMessageTimer / 0.5)
    love.graphics.setColor(encounterState.encounterMessageColor[1], encounterState.encounterMessageColor[2], encounterState.encounterMessageColor[3], alpha)
    love.graphics.printf(encounterState.encounterMessage, 0, gameState.height / 2 - 140, gameState.width, "center")
  end

  -- Trident acquisition banner
  if tridentBannerTimer > 0 then
    local alpha = math.min(1, tridentBannerTimer / 1.0)
    local glow = math.sin(love.timer.getTime() * 4) * 0.2 + 0.8

    -- Background
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", 0, gameState.height / 2 - 50, gameState.width, 100)

    -- Glow border
    love.graphics.setColor(0.3, 0.7, 1.0, alpha * glow * 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 20, gameState.height / 2 - 48, gameState.width - 40, 96)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setFont(ui.getFont("medium"))
    love.graphics.setColor(0.7, 0.9, 1.0, alpha * glow)
    love.graphics.printf("🔱 THE TRIDENT 🔱", 0, gameState.height / 2 - 40, gameState.width, "center")

    -- Description
    love.graphics.setFont(ui.getFont("hudLabel"))
    love.graphics.setColor(0.5, 0.8, 1.0, alpha * 0.9)
    love.graphics.printf("You can now teleport anywhere in Outer Space!", 0, gameState.height / 2 + 5, gameState.width, "center")
    love.graphics.printf("Open the World Map to fast travel.", 0, gameState.height / 2 + 25, gameState.width, "center")
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
    cellSize = 28
  elseif tier == constellation.TIER_INNER_SPACE then
    viewRadius = 5 -- Show a 11x11 window centered on player (named constellations ±10)
    cellSize = 16
  else
    viewRadius = 7 -- 15x15 window for full 63x63 world
    cellSize = 12
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

  -- Constellation label and coordinates below minimap
  love.graphics.setFont(ui.getFont("mapSector"))
  love.graphics.setColor(0.6, 0.7, 0.8)
  local cName = worldmap.getConstellationName()
  love.graphics.printf(cName, mapX - 30, mapY + mapSize + 4, mapSize + 60, "center")
  local coords = "(" .. worldmap.tileX .. ", " .. worldmap.tileY .. ")"
  love.graphics.setFont(ui.getFont("mapCoords"))
  love.graphics.setColor(0.5, 0.6, 0.7)
  love.graphics.printf(coords, mapX - 30, mapY + mapSize + 24, mapSize + 60, "center")
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

  -- Draw dungeon background decorations (behind everything)
  if dungeon.isActive() then
    dungeon.drawBackground(gameState.width, gameState.height)
    dungeon.drawHazardZones(gameState.width, gameState.height)
    dungeon.drawWalls(gameState.width, gameState.height)
  end

  -- Draw Orion boss dungeon background (nebula pillar, node connection lines)
  orionDungeon.drawBackground(gameState.width, gameState.height)
  messierDungeon.drawBackground(gameState.width, gameState.height)
  outerDungeon.drawBackground(gameState.width, gameState.height)

  -- Draw Vela dungeon (full room rendering with enemies, boss, minimap)
  if velaDungeon.isActive() then
    velaDungeon.draw()
  end

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

  -- Seeker missile lock-on indicators (red dots on targeted enemies)
  for _, a in ipairs(gameState.asteroids) do
    if a.seekerLocked then
      love.graphics.setColor(1, 0.1, 0.1, 0.9)
      love.graphics.circle("line", a.x, a.y, (a.size or 20) + 6)
      love.graphics.setColor(1, 0.2, 0.2, 0.7)
      love.graphics.circle("fill", a.x, a.y, 5)
    end
  end
  for _, u in ipairs(gameState.ufos) do
    if u.seekerLocked then
      love.graphics.setColor(1, 0.1, 0.1, 0.9)
      love.graphics.circle("line", u.x, u.y, (u.size or 20) + 6)
      love.graphics.setColor(1, 0.2, 0.2, 0.7)
      love.graphics.circle("fill", u.x, u.y, 5)
    end
  end

  for _, b in ipairs(gameState.bullets) do
    -- Color patrol bullets differently
    if b.owner == "patrol" then
      love.graphics.setColor(1, 0.3, 0.3)
      love.graphics.circle("fill", b.x, b.y, 3)
      love.graphics.setColor(1, 0.5, 0.5, 0.4)
      love.graphics.circle("fill", b.x, b.y, 6)
    elseif b.owner == "boss" then
      -- Orion boss bullets: rose/magenta
      love.graphics.setColor(1, 0.3, 0.7, 0.95)
      love.graphics.circle("fill", b.x, b.y, b.size or 5)
      love.graphics.setColor(1, 0.6, 0.9, 0.3)
      love.graphics.circle("fill", b.x, b.y, (b.size or 5) + 4)
    elseif b.owner == "boss_messier" then
      local lifeRatio = math.max(0, b.lifetime / 3.5)
      love.graphics.setColor(0.9, 0.7, 0.1, lifeRatio * 0.4)
      love.graphics.circle("fill", b.x, b.y, (b.size or 6) * 2.2)
      love.graphics.setColor(1.0, 0.9, 0.3, lifeRatio * 0.95)
      love.graphics.circle("fill", b.x, b.y, (b.size or 6))
    elseif b.owner == "boss_outer" then
      local lifeRatio = math.max(0, b.lifetime / 4.0)
      love.graphics.setColor(0.5, 0.1, 0.7, lifeRatio * 0.4)
      love.graphics.circle("fill", b.x, b.y, (b.size or 5) * 2.2)
      love.graphics.setColor(0.7, 0.3, 1.0, lifeRatio * 0.9)
      love.graphics.circle("fill", b.x, b.y, b.size or 5)
    elseif b.dungeonBullet then
      -- Dungeon turret bullets: themed color
      local dId = dungeon.getDungeonId()
      if dId == "megalith" then
        love.graphics.setColor(0.3, 0.5, 1)
      elseif dId == "dynamo" then
        love.graphics.setColor(1, 0.6, 0.1)
      elseif dId == "logician" then
        love.graphics.setColor(0.7, 0.3, 1)
      elseif dId == "synesthesia" then
        love.graphics.setColor(0, 1, 0.5)
      else
        love.graphics.setColor(1, 0.5, 0.5)
      end
      love.graphics.circle("fill", b.x, b.y, 4)
      love.graphics.setColor(1, 1, 1, 0.3)
      love.graphics.circle("fill", b.x, b.y, 7)
    else
      -- Firebird burn bullets: fire-colored with ember glow
      if b.burnDamage and b.owner == "player" then
        local flicker = 0.8 + 0.2 * math.sin((love.timer.getTime() + b.x * 0.01) * 12)
        -- Outer ember glow
        love.graphics.setColor(1, 0.3, 0.05, 0.25 * flicker)
        love.graphics.circle("fill", b.x, b.y, 8)
        -- Mid fire ring
        love.graphics.setColor(1, 0.5, 0.1, 0.5 * flicker)
        love.graphics.circle("fill", b.x, b.y, 5)
        -- Core bullet (bright orange-yellow)
        love.graphics.setColor(1, 0.7, 0.15, 0.95)
        love.graphics.circle("fill", b.x, b.y, 3)
        -- Hot white center
        love.graphics.setColor(1, 1, 0.8, 0.7)
        love.graphics.circle("fill", b.x, b.y, 1.5)
      else
        if b.isHyper then
          love.graphics.setColor(0.3, 0.9, 1.0, 0.3)
          love.graphics.circle("fill", b.x, b.y, (b.size or 6) * 2.5)
          love.graphics.setColor(0.6, 1.0, 1.0, 1.0)
          love.graphics.circle("fill", b.x, b.y, (b.size or 6))
        else
          ui.drawBullet(b)
        end
      end
    end
  end

  for _, u in ipairs(gameState.ufos) do
    ui.drawUFO(u)
  end

  -- Draw encounter enemies
  for _, e in ipairs(encounterState.enemies) do
    encounter.drawEnemy(e)
  end

  -- Draw Kraken boss
  if krakenState then
    kraken.draw(krakenState)
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
    -- Firebird burn aura on burning patrols
    if p.burnTimer and p.burnTimer > 0 and not p.dead then
      local bFlicker = 0.5 + 0.5 * math.sin(love.timer.getTime() * 10 + p.x)
      love.graphics.setColor(1, 0.4, 0.05, 0.2 * bFlicker)
      love.graphics.circle("fill", p.x, p.y, p.size + 10)
      love.graphics.setColor(1, 0.6, 0.1, 0.12 * bFlicker)
      love.graphics.circle("fill", p.x, p.y, p.size + 18)
    end
  end

  -- Draw dungeon enemies
  if dungeon.isActive() then
    dungeon.drawEnemies(gameState.width, gameState.height)
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

  -- Draw dungeon foreground decorations (psychedelic overlays)
  if dungeon.isActive() then
    dungeon.drawForeground(gameState.width, gameState.height)
  end

  -- Draw Orion boss dungeon foreground (boss body, nodes, barriers)
  orionDungeon.drawForeground(gameState.width, gameState.height)
  messierDungeon.drawForeground(gameState.width, gameState.height)
  outerDungeon.drawForeground(gameState.width, gameState.height)

  -- Draw Orion boss dungeon HUD (node HP bars, phase indicator)
  orionDungeon.drawHUD(gameState.width, gameState.height)
  messierDungeon.drawHUD(gameState.width, gameState.height)
  outerDungeon.drawHUD(gameState.width, gameState.height)

  -- Draw Spread Beam acquisition banner
  if spreadBeamBannerTimer > 0 then
    orionDungeon.drawAcquisitionBanner(spreadBeamBannerTimer)
  end
  if hyperBeamBannerTimer > 0 then
    messierDungeon.drawAcquisitionBanner(hyperBeamBannerTimer)
  end
  if seekerMissileBannerTimer > 0 then
    outerDungeon.drawAcquisitionBanner(seekerMissileBannerTimer)
  end

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

  -- Draw Muse power visual effects
  -- Melo: purple time-slow tint
  if muses.isTimeSlowed() then
    love.graphics.setColor(0.8, 0.3, 0.3, 0.06 + math.sin(love.timer.getTime() * 2) * 0.03)
    love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)
  end

  -- Djolt: chain lightning arcs
  for _, arc in ipairs(chainLightningArcs) do
    local segments = 6
    local prevX, prevY = arc.x1, arc.y1
    for s = 1, segments do
      local t = s / segments
      local nx = arc.x1 + (arc.x2 - arc.x1) * t + (math.random() - 0.5) * 20
      local ny = arc.y1 + (arc.y2 - arc.y1) * t + (math.random() - 0.5) * 20
      if s == segments then nx, ny = arc.x2, arc.y2 end
      -- Glow
      love.graphics.setColor(arc.color[1], arc.color[2], arc.color[3], arc.timer * 1.5)
      love.graphics.setLineWidth(3)
      love.graphics.line(prevX, prevY, nx, ny)
      -- Core
      love.graphics.setColor(1, 1, 1, arc.timer * 2)
      love.graphics.setLineWidth(1)
      love.graphics.line(prevX, prevY, nx, ny)
      prevX, prevY = nx, ny
    end
  end

  -- Tierra: screen wrap indicator (subtle border glow)
  if muses.hasScreenWrap() then
    love.graphics.setColor(0.3, 0.7, 0.25, 0.15 + math.sin(love.timer.getTime() * 3) * 0.08)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 2, 2, gameState.width - 4, gameState.height - 4)
  end

  -- Clarity: golden shimmer overlay
  if muses.hasClarity() then
    love.graphics.setColor(0.9, 0.85, 0.4, 0.04 + math.sin(love.timer.getTime() * 1.5) * 0.02)
    love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)
  end

  -- Muse power HUD
  muses.drawMuseHUD()

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

  -- Draw sector boundary walls + lever
  M.drawSectorBoundary()

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
  -- If world map sub-menu is active, delegate to it
  if gameState.pauseSubMenu == "world_map" then
    M.drawWorldMapOverlay()
    return
  end

  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)

  -- Title
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.setFont(ui.getFont("pauseTitle"))
  love.graphics.printf("PAUSED", 0, 250, gameState.width, "center")

  -- Menu options
  love.graphics.setFont(ui.getFont("pauseMenu"))
  local options = {"Resume", "World Map", "Options", "Exit to Station"}
  local startY = 340

  for i, option in ipairs(options) do
    if i == gameState.pauseMenuIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * 50, gameState.width, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(option, 0, startY + (i - 1) * 50, gameState.width, "center")
    end
  end

  -- Instructions
  love.graphics.setFont(ui.getFont("hudLabel"))
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 560, gameState.width, "center")
end

-- World Map overlay (full screen, shown from pause menu)
-- State for world map cursor
local worldMapState = {
  cursorX = 0,
  cursorY = 0,
  message = nil,
  messageTimer = 0,
}

function M.drawWorldMapOverlay()
  love.graphics.setColor(0, 0, 0, 0.92)
  love.graphics.rectangle("fill", 0, 0, gameState.width, gameState.height)

  local WORLD_MIN = -38
  local WORLD_MAX = 38
  local WORLD_SIZE = 77

  local screenW = gameState.width
  local screenH = gameState.height
  local headerHeight = 45
  local footerHeight = 55
  local mapPadding = 20

  local availW = screenW - mapPadding * 2
  local availH = screenH - headerHeight - footerHeight - mapPadding
  local cellSize = math.floor(math.min(availW / WORLD_SIZE, availH / WORLD_SIZE))
  cellSize = math.max(cellSize, 8)
  local mapSize = cellSize * WORLD_SIZE

  local mapX = math.floor((screenW - mapSize) / 2)
  local mapY = headerHeight + 5

  -- Title
  love.graphics.setFont(ui.getFont("title"))
  love.graphics.setColor(0.3, 0.7, 1)
  love.graphics.printf("WORLD MAP", 0, 8, screenW, "center")

  -- Background
  love.graphics.setColor(0.03, 0.03, 0.06, 0.95)
  love.graphics.rectangle("fill", mapX - 2, mapY - 2, mapSize + 4, mapSize + 4)

  local playerTX = worldmap.tileX
  local playerTY = worldmap.tileY

  -- Draw tiles
  for ty = WORLD_MAX, WORLD_MIN, -1 do
    for tx = WORLD_MIN, WORLD_MAX do
      local drawCellX = mapX + (tx - WORLD_MIN) * cellSize
      local drawCellY = mapY + (WORLD_MAX - ty) * cellSize

      local discovered = worldmap.isDiscovered(tx, ty)
      local tile = worldmap.getTile(tx, ty)
      local zone = constellation.getZone(tx, ty)

      if discovered then
        if tile.type == worldmap.TILE_STATION then
          love.graphics.setColor(0.3, 0.6, 0.9, 0.9)
        elseif tile.type == worldmap.TILE_PORTAL then
          love.graphics.setColor(tile.color[1] * 0.8, tile.color[2] * 0.8, tile.color[3] * 0.8, 0.9)
        else
          if zone == constellation.ZONE_NAMED then
            local cId = constellation.getConstellationId(tx, ty)
            local cData = constellation.CONSTELLATIONS[cId]
            if cData then
              local bg = cData.bgColor
              love.graphics.setColor(bg[1] * 6 + 0.15, bg[2] * 6 + 0.15, bg[3] * 6 + 0.15, 0.6)
            else
              love.graphics.setColor(0.2, 0.2, 0.3, 0.5)
            end
          elseif zone == constellation.ZONE_DEEP_SPACE then
            -- Check if this is a dungeon constellation (show themed color)
            local dsId = constellation.getConstellationId(tx, ty)
            local dsData = constellation.CONSTELLATIONS[dsId]
            if dsData and dsData.isDungeon then
              local bg = dsData.bgColor
              love.graphics.setColor(bg[1] * 6 + 0.15, bg[2] * 6 + 0.15, bg[3] * 6 + 0.15, 0.6)
            else
              love.graphics.setColor(0.12, 0.12, 0.18, 0.5)
            end
          else
            love.graphics.setColor(0.08, 0.08, 0.1, 0.4)
          end
        end
        love.graphics.rectangle("fill", drawCellX, drawCellY, cellSize - 1, cellSize - 1)
      else
        if zone == constellation.ZONE_NAMED then
          love.graphics.setColor(0.1, 0.1, 0.15, 0.25)
        elseif zone == constellation.ZONE_DEEP_SPACE then
          love.graphics.setColor(0.07, 0.07, 0.1, 0.2)
        else
          love.graphics.setColor(0.04, 0.04, 0.06, 0.15)
        end
        love.graphics.rectangle("fill", drawCellX, drawCellY, cellSize - 1, cellSize - 1)
      end
    end
  end

  -- Constellation boundary lines (7x7 blocks)
  love.graphics.setColor(0.25, 0.25, 0.35, 0.35)
  for i = 0, 11 do
    local lineX = mapX + i * 7 * cellSize
    love.graphics.line(lineX, mapY, lineX, mapY + mapSize)
    local lineY = mapY + i * 7 * cellSize
    love.graphics.line(mapX, lineY, mapX + mapSize, lineY)
  end

  -- Zone boundaries
  -- Named zone outline (tiles -10..10)
  love.graphics.setColor(0.4, 0.6, 0.8, 0.5)
  local namedOff = ((-10) - WORLD_MIN) * cellSize
  local namedSz = 21 * cellSize
  love.graphics.rectangle("line", mapX + namedOff, mapY + (WORLD_MAX - 10) * cellSize, namedSz, namedSz)

  -- Deep space outline (tiles -24..24)
  love.graphics.setColor(0.5, 0.4, 0.3, 0.4)
  local deepOff = ((-24) - WORLD_MIN) * cellSize
  local deepSz = 49 * cellSize
  love.graphics.rectangle("line", mapX + deepOff, mapY + (WORLD_MAX - 24) * cellSize, deepSz, deepSz)

  -- Constellation labels
  love.graphics.setFont(ui.getFont("hudLabel"))
  local labels = {
    {name = "The Nebula",  cx = 0,  cy = 0},
    {name = "Gargantua",   cx = 1,  cy = 0},
    {name = "Pleiades",    cx = -1, cy = 0},
    {name = "Oort Cloud",  cx = 0,  cy = 1},
    {name = "Messier",     cx = 0,  cy = -1},
    {name = "Vela",        cx = 1,  cy = 1},
    {name = "Pandora",     cx = -1, cy = 1},
    {name = "Orion",       cx = -1, cy = -1},
    {name = "Andromeda",   cx = 1,  cy = -1},
    -- Deep Space dungeon constellations
    {name = "Synesthesia", cx = -3, cy = 3},
    {name = "Megalith",    cx = 3,  cy = 3},
    {name = "Dynamo",      cx = -3, cy = -3},
    {name = "Logician",    cx = 3,  cy = -3},
  }
  for _, c in ipairs(labels) do
    local centerTileX = c.cx * 7
    local centerTileY = c.cy * 7
    local labelX = mapX + (centerTileX - WORLD_MIN) * cellSize
    local labelY = mapY + (WORLD_MAX - centerTileY) * cellSize
    love.graphics.setColor(0.5, 0.6, 0.8, 0.6)
    love.graphics.printf(c.name, labelX - 3.5 * cellSize, labelY - cellSize * 0.3, 7 * cellSize, "center")
  end

  -- Zone labels
  love.graphics.setColor(0.35, 0.35, 0.45, 0.45)
  local deepLabelY = mapY + (WORLD_MAX - 18) * cellSize
  love.graphics.printf("DEEP SPACE", mapX, deepLabelY, mapSize, "center")
  local outerLabelY = mapY + (WORLD_MAX - 32) * cellSize
  love.graphics.printf("OUTER SPACE", mapX, outerLabelY, mapSize, "center")

  -- Special tile icons (discovered only)
  local specialTiles = worldmap.getAllSpecialTiles()
  for key, tile in pairs(specialTiles) do
    local tx, ty = key:match("^(-?%d+),(-?%d+)$")
    tx = tonumber(tx)
    ty = tonumber(ty)
    if tx and ty and worldmap.isDiscovered(tx, ty) then
      local iconX = mapX + (tx - WORLD_MIN) * cellSize + cellSize / 2
      local iconY = mapY + (WORLD_MAX - ty) * cellSize + cellSize / 2
      local iconR = math.max(2, cellSize * 0.35)
      if tile.type == worldmap.TILE_STATION then
        love.graphics.setColor(0.3, 0.8, 1, 1)
        love.graphics.rectangle("fill", iconX - iconR, iconY - iconR, iconR * 2, iconR * 2)
      elseif tile.type == worldmap.TILE_PORTAL then
        love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 1)
        love.graphics.polygon("fill",
          iconX, iconY - iconR,
          iconX + iconR, iconY,
          iconX, iconY + iconR,
          iconX - iconR, iconY)
      end
    end
  end

  -- Cursor
  local curX = mapX + (worldMapState.cursorX - WORLD_MIN) * cellSize
  local curY = mapY + (WORLD_MAX - worldMapState.cursorY) * cellSize
  local pulse = math.sin(love.timer.getTime() * 4) * 0.3 + 0.7
  love.graphics.setColor(1, 1, 0, pulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", curX - 1, curY - 1, cellSize + 1, cellSize + 1)
  love.graphics.setLineWidth(1)

  -- Player marker
  local plX = mapX + (playerTX - WORLD_MIN) * cellSize + cellSize / 2
  local plY = mapY + (WORLD_MAX - playerTY) * cellSize + cellSize / 2
  love.graphics.setColor(0, 1, 0, 0.9)
  love.graphics.circle("fill", plX, plY, math.max(2, cellSize * 0.3))

  -- Info footer
  local infoY = mapY + mapSize + 4
  love.graphics.setFont(ui.getFont("hudLabel"))

  -- Tile info
  local cursorTile = worldmap.getTile(worldMapState.cursorX, worldMapState.cursorY)
  local cursorZone = constellation.getZone(worldMapState.cursorX, worldMapState.cursorY)
  local zoneName = worldmap.getZoneName(worldMapState.cursorX, worldMapState.cursorY)
  local discovered = worldmap.isDiscovered(worldMapState.cursorX, worldMapState.cursorY)
  local inRange = worldmap.canFastTravel(worldMapState.cursorX, worldMapState.cursorY)

  love.graphics.setColor(0.8, 0.8, 0.9)
  local tileLabel = "(" .. worldMapState.cursorX .. ", " .. worldMapState.cursorY .. ") " .. zoneName
  if discovered and cursorTile.type ~= worldmap.TILE_EMPTY then
    tileLabel = tileLabel .. " — " .. (cursorTile.name or "")
  elseif not discovered then
    tileLabel = tileLabel .. " (Unexplored)"
  end
  love.graphics.print(tileLabel, mapX, infoY)

  -- Radio range status
  if inRange then
    love.graphics.setColor(0.3, 1, 0.4)
    love.graphics.printf("● IN RANGE — ENTER to Fast Travel", 0, infoY, screenW - mapX, "right")
  else
    love.graphics.setColor(0.7, 0.3, 0.3)
    love.graphics.printf("○ OUT OF RANGE", 0, infoY, screenW - mapX, "right")
  end

  -- Status message
  if worldMapState.message then
    love.graphics.setFont(ui.getFont("hudSmall"))
    love.graphics.setColor(1, 0.4, 0.3, 0.9)
    love.graphics.printf(worldMapState.message, 0, infoY + 15, screenW, "center")
  end

  -- Legend row
  love.graphics.setFont(ui.getFont("hudSmall"))
  local legY = infoY + 14
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.print("Legend:", mapX, legY)
  love.graphics.setColor(0.3, 0.8, 1)
  love.graphics.rectangle("fill", mapX + 48, legY + 2, 7, 7)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("Station", mapX + 58, legY)
  love.graphics.setColor(0.8, 0.5, 0.3)
  love.graphics.polygon("fill", mapX + 120, legY + 1, mapX + 124, legY + 5, mapX + 120, legY + 9, mapX + 116, legY + 5)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("Portal", mapX + 128, legY)
  love.graphics.setColor(0, 1, 0)
  love.graphics.circle("fill", mapX + 186, legY + 5, 3)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("You", mapX + 192, legY)

  -- Controls
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Move | ENTER: Fast Travel | P: Center on Player | ESC: Back", 0, screenH - 18, screenW, "center")
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

  -- Clarity Muse power: neutralize all environmental hazards
  if muses.hasClarity() then
    hazardState.coldActive = false
    hazardState.hotActive = false
    hazardState.gravityActive = false
    hazardState.pulsarWarning = false
    hazardState.pulsarBurst = false
    return
  end

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
    -- Firebird is immune to cold damage
    local shipDef = starfoxShips and starfoxShips.getSelectedDef and starfoxShips.getSelectedDef()
    local coldImmune = shipDef and shipDef.coldImmune
    if not coldImmune and not gameState.ship.shieldActive then
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
    local shipDef = starfoxShips and starfoxShips.getSelectedDef and starfoxShips.getSelectedDef()
    local immune = shipDef and shipDef.coldImmune
    local pulse = math.sin(love.timer.getTime() * 4) * 0.2 + 0.8
    -- Blue warning background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX, barY, 28, 22, 3, 3)
    if immune then
      -- Orange/fire color for immunity
      love.graphics.setColor(1.0, 0.5, 0.15, pulse)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.print("❄", barX + 5, barY + 3)
      love.graphics.setFont(ui.getFont("hudSmall"))
      love.graphics.setColor(1.0, 0.6, 0.2, pulse)
      love.graphics.print("SAFE", barX + 2, barY + 23)
    else
      -- Snowflake/cold icon
      love.graphics.setColor(0.3, 0.7, 1.0, pulse)
      love.graphics.setFont(ui.getFont("hudLabel"))
      love.graphics.print("❄", barX + 5, barY + 3)
      -- "COLD" label
      love.graphics.setFont(ui.getFont("hudSmall"))
      love.graphics.setColor(0.5, 0.8, 1.0, pulse)
      love.graphics.print("COLD", barX + 2, barY + 23)
    end
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
    -- World map sub-menu input
    if gameState.pauseSubMenu == "world_map" then
      if key == "escape" then
        gameState.pauseSubMenu = nil
        worldMapState.message = nil
      elseif key == "up" then
        worldMapState.cursorY = math.min(38, worldMapState.cursorY + 1)
      elseif key == "down" then
        worldMapState.cursorY = math.max(-38, worldMapState.cursorY - 1)
      elseif key == "left" then
        worldMapState.cursorX = math.max(-38, worldMapState.cursorX - 1)
      elseif key == "right" then
        worldMapState.cursorX = math.min(38, worldMapState.cursorX + 1)
      elseif key == "p" then
        worldMapState.cursorX = worldmap.tileX
        worldMapState.cursorY = worldmap.tileY
      elseif key == "return" or key == "space" then
        -- Attempt fast travel
        if worldMapState.cursorX == worldmap.tileX and worldMapState.cursorY == worldmap.tileY then
          worldMapState.message = "You are already here!"
          worldMapState.messageTimer = 2
        elseif not worldmap.canFastTravel(worldMapState.cursorX, worldMapState.cursorY) then
          local zone = constellation.getZone(worldMapState.cursorX, worldMapState.cursorY)
          if zone == constellation.ZONE_OUTER_SPACE then
            worldMapState.message = "Cannot fast travel: need The Trident for Outer Space"
          elseif zone == constellation.ZONE_DEEP_SPACE then
            worldMapState.message = "Cannot fast travel: need Power Amplifier for Deep Space"
          else
            worldMapState.message = "Cannot fast travel: need Mega Antenna for radio comms"
          end
          worldMapState.messageTimer = 3
        elseif worldMapState.cursorX < worldmap.GRID_MIN or worldMapState.cursorX > worldmap.GRID_MAX or
               worldMapState.cursorY < worldmap.GRID_MIN or worldMapState.cursorY > worldmap.GRID_MAX then
          worldMapState.message = "Cannot fast travel: sector not yet accessible"
          worldMapState.messageTimer = 2
        else
          -- Fast travel via tile transition
          local targetX = worldMapState.cursorX
          local targetY = worldMapState.cursorY
          gameState.pauseSubMenu = nil
          worldMapState.message = nil
          gameState.state = "playing"
          M.startFade(function()
            M.transitionToTile(targetX, targetY, gameState.width / 2, gameState.height / 2)
          end)
        end
      end
      -- Update message timer
      if worldMapState.messageTimer > 0 then
        worldMapState.messageTimer = worldMapState.messageTimer - 0.016 -- approx dt
        if worldMapState.messageTimer <= 0 then
          worldMapState.message = nil
        end
      end
      return
    end

    if key == "escape" then
      gameState.state = "playing"
    elseif key == "up" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex - 1
      if gameState.pauseMenuIndex < 1 then
        gameState.pauseMenuIndex = 5
      end
    elseif key == "down" then
      gameState.pauseMenuIndex = gameState.pauseMenuIndex + 1
      if gameState.pauseMenuIndex > 5 then
        gameState.pauseMenuIndex = 1
      end
    elseif key == "return" or key == "space" then
      if gameState.pauseMenuIndex == 1 then
        -- Resume
        gameState.state = "playing"
      elseif gameState.pauseMenuIndex == 2 then
        -- World Map
        gameState.pauseSubMenu = "world_map"
        worldMapState.cursorX = worldmap.tileX
        worldMapState.cursorY = worldmap.tileY
        worldMapState.message = nil
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
      gameState.pauseSubMenu = nil
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

        -- Firebird burn effect: tag all player bullets with burn properties
        local shipDef = starfoxShips.getSelectedDef()
        if shipDef and shipDef.burnDamage then
          local lastBullet = gameState.bullets[#gameState.bullets]
          lastBullet.burnDamage = shipDef.burnDamage
          lastBullet.burnDuration = shipDef.burnDuration or 3
          lastBullet.meltsIce = shipDef.meltsIce or false
        end

        -- Multishot: fire two extra angled bullets (same type)
        if ship.hasMultishot(gameState.ship) then
          local spread = 0.2  -- radians (~11 degrees)
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle - spread, "player", useMissile))
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle + spread, "player", useMissile))
          -- Apply burn to multishot bullets too
          if shipDef and shipDef.burnDamage then
            gameState.bullets[#gameState.bullets].burnDamage = shipDef.burnDamage
            gameState.bullets[#gameState.bullets].burnDuration = shipDef.burnDuration or 3
            gameState.bullets[#gameState.bullets].meltsIce = shipDef.meltsIce or false
            gameState.bullets[#gameState.bullets - 1].burnDamage = shipDef.burnDamage
            gameState.bullets[#gameState.bullets - 1].burnDuration = shipDef.burnDuration or 3
            gameState.bullets[#gameState.bullets - 1].meltsIce = shipDef.meltsIce or false
          end
        end

        -- Spread Beam: fire two extra ±15° bullets (permanent upgrade, stacks with multishot)
        if ship.hasSpreadBeam(gameState.ship) then
          local spread = math.pi / 12  -- 15 degrees
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle - spread, "player"))
          table.insert(gameState.bullets, bullet.new(bx, by, gameState.ship.angle + spread, "player"))
          -- Apply burn to spread beam bullets too
          if shipDef and shipDef.burnDamage then
            gameState.bullets[#gameState.bullets].burnDamage = shipDef.burnDamage
            gameState.bullets[#gameState.bullets].burnDuration = shipDef.burnDuration or 3
            gameState.bullets[#gameState.bullets].meltsIce = shipDef.meltsIce or false
            gameState.bullets[#gameState.bullets - 1].burnDamage = shipDef.burnDamage
            gameState.bullets[#gameState.bullets - 1].burnDuration = shipDef.burnDuration or 3
            gameState.bullets[#gameState.bullets - 1].meltsIce = shipDef.meltsIce or false
          end
        end
        -- Hyper Beam: replace normal bullet with larger hyper bullet (already fired above as normal)
        -- Mark the most recently inserted player bullet as hyper if ship has hyper beam
        if ship.hasHyperBeam(gameState.ship) then
          local lastIdx = #gameState.bullets
          if lastIdx > 0 and gameState.bullets[lastIdx].owner == "player" then
            gameState.bullets[lastIdx].isHyper = true
            gameState.bullets[lastIdx].size = 6
            gameState.bullets[lastIdx].damage = 2
          end
        end
        -- Seeker Missiles: when hasSeeker, mark the most recently fired player bullet as a seeker
        if ship.hasSeeker(gameState.ship) then
          local lastIdx = #gameState.bullets
          if lastIdx > 0 and gameState.bullets[lastIdx].owner == "player" then
            local sb = gameState.bullets[lastIdx]
            sb.isSeeker = true
            sb.seekerState = "traveling"
            sb.distanceTraveled = 0
            sb.seekerTarget = nil
            -- Double the speed
            local curSpd = math.sqrt(sb.vx*sb.vx + sb.vy*sb.vy)
            if curSpd > 0 then
              sb.vx = sb.vx / curSpd * 1000
              sb.vy = sb.vy / curSpd * 1000
            end
            sb.size = sb.size + 2  -- slightly larger
          end
        end
      end
    elseif key == "x" and not gameState.ship.dead then
      local damaged = ship.hyperspace(gameState.ship, gameState.width, gameState.height)
      if damaged then
        gameState.health = gameState.health - 50
      end
    elseif key == "b" and not gameState.ship.dead and not gameState.ship.exploding then
      -- Smart bomb OR Muse power (hold B = Muse, tap B = bomb)
      if bombState.launched then
        -- Press #2: Detonate the bomb in flight (always immediate)
        M.triggerSmartBomb()
      elseif muses.activePower and muses.canActivate() then
        -- Start B-hold tracking for Muse power
        museBHeld = true
        museBHoldTimer = 0
      elseif not bombState.active then
        -- No Muse power available, use bomb immediately
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

function M.keyreleased(key)
  if gameState.state == "playing" then
    if key == "b" then
      if museBHeld then
        if museBHoldTimer < MUSE_B_HOLD_THRESHOLD then
          -- Quick tap — use smart bomb instead
          if not bombState.active and not bombState.launched then
            if ship.useBomb(gameState.ship) then
              M.launchBomb()
            end
          end
        elseif muses.powerActive then
          -- Release hold — deactivate toggle powers (Melo, Tierra)
          if muses.activePower == "melo" or muses.activePower == "tierra" then
            muses.deactivate()
          end
        end
        museBHeld = false
        museBHoldTimer = 0
      end
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
