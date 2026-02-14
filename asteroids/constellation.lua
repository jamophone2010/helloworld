-- asteroids/constellation.lua
-- Constellation system for the expanded worldmap
-- The 49x49 Inner Space is divided into a 7x7 grid of constellations, each 7x7 tiles.
-- The 343x343 Outer Space extends this further (7x7 grid of 49x49 super-blocks).

local M = {}

-- ===================== MAP EXPANSION TIERS =====================
-- Tier 1: 7x7 (default, "The Nebula" only)
-- Tier 2: 49x49 (after Warden defeated + Antenna installed at Studio)
-- Tier 3: 343x343 (after Sentinel defeated)

M.TIER_NEBULA = 1      -- 7x7 (-3 to 3)
M.TIER_INNER_SPACE = 2 -- 49x49 (-24 to 24)
M.TIER_OUTER_SPACE = 3 -- 343x343 (-171 to 171)

M.currentTier = M.TIER_NEBULA

-- Progression flags (synced from hub)
M.antennaInstalled = false  -- Warden defeated + antenna brought to Studio
M.sentinelDefeated = false  -- Sentinel defeated

function M.getTier()
  return M.currentTier
end

function M.getGridBounds()
  if M.currentTier == M.TIER_OUTER_SPACE then
    return -171, 171
  elseif M.currentTier == M.TIER_INNER_SPACE then
    return -24, 24
  else
    return -3, 3
  end
end

function M.setProgression(antennaInstalled, sentinelDefeated)
  M.antennaInstalled = antennaInstalled or false
  M.sentinelDefeated = sentinelDefeated or false

  if M.sentinelDefeated then
    M.currentTier = M.TIER_OUTER_SPACE
  elseif M.antennaInstalled then
    M.currentTier = M.TIER_INNER_SPACE
  else
    M.currentTier = M.TIER_NEBULA
  end
end

-- ===================== CONSTELLATION DEFINITIONS =====================
-- Constellation grid: divide tile coords by 7 (floor) to get constellation coords
-- Constellation (0,0) at tile center = The Nebula (tiles -3..3)

M.CONSTELLATION_NAMES = {
  -- Named constellations (constellation grid coords as "cx,cy")
  ["0,0"]   = "nebula",
  ["1,0"]   = "gargantua",
  ["-1,0"]  = "pleiades",
  ["0,1"]   = "oort",
  ["0,-1"]  = "messier",
  ["1,1"]   = "vela",
  ["-1,1"]  = "pandora",
  ["-1,-1"] = "orion",
  ["1,-1"]  = "andromeda",
}

-- Full constellation data
M.CONSTELLATIONS = {
  nebula = {
    name = "The Nebula",
    description = "Hometown constellation - the heart of Inner Space",
    -- Carina/Pillars of Creation style nebula colors
    bgColor = {0.02, 0.02, 0.05},
    starColors = {{1,1,1}, {0.9,0.95,1}, {1,0.9,0.8}},
    cloudPalette = {
      {0.6, 0.3, 0.15, 0.18},
      {0.2, 0.35, 0.6, 0.15},
      {0.4, 0.2, 0.5, 0.12},
      {0.5, 0.4, 0.2, 0.1},
    },
    asteroidColor = {0.7, 0.7, 0.7},
    hazard = nil,
    asteroidDensityMod = 1.0,
  },

  gargantua = {
    name = "Gargantua",
    description = "A massive black hole warps spacetime itself",
    -- Interstellar black hole: warm amber accretion disk, dark void
    bgColor = {0.01, 0.01, 0.02},
    starColors = {{1, 0.85, 0.5}, {1, 0.7, 0.3}, {0.9, 0.6, 0.2}},
    cloudPalette = {
      {0.9, 0.6, 0.15, 0.2},   -- amber/gold accretion
      {1.0, 0.8, 0.3, 0.15},   -- bright gold
      {0.7, 0.3, 0.1, 0.12},   -- deep orange
      {0.2, 0.15, 0.05, 0.25}, -- dark matter
    },
    asteroidColor = {0.5, 0.4, 0.3},
    hazard = "gravity",
    -- Gravity pull toward center increases as player approaches
    gravityCenterTile = {0, 0}, -- Center of constellation (relative)
    gravityStrength = 200, -- Max gravitational acceleration
    asteroidDensityMod = 0.7,
    -- The Singularity station is at the center tile of this constellation
  },

  pleiades = {
    name = "Pleiades",
    description = "Brilliant blue stars illuminate crystalline asteroids",
    -- Iconic blue reflection nebula
    bgColor = {0.01, 0.02, 0.06},
    starColors = {{0.7, 0.85, 1.0}, {0.5, 0.7, 1.0}, {0.8, 0.9, 1.0}},
    cloudPalette = {
      {0.3, 0.5, 0.9, 0.22},   -- electric blue
      {0.4, 0.6, 1.0, 0.18},   -- bright blue
      {0.2, 0.3, 0.7, 0.15},   -- deep blue
      {0.5, 0.7, 1.0, 0.1},    -- pale blue
    },
    asteroidColor = {0.6, 0.75, 0.95}, -- Crystalline blue-white
    hazard = nil,
    asteroidDensityMod = 1.2,
    -- Stars are extra bright and numerous, asteroids have blue/crystal sheen
    extraStars = true,
    asteroidGlow = {0.4, 0.6, 1.0, 0.3},
  },

  oort = {
    name = "Oort Cloud",
    description = "A frozen wasteland of dark ice and streaking comets",
    -- Dark, icy, neon accents on black/grey
    bgColor = {0.01, 0.01, 0.015},
    starColors = {{0.5, 0.5, 0.6}, {0.4, 0.4, 0.5}, {0.3, 0.6, 0.7}},
    cloudPalette = {
      {0.1, 0.1, 0.15, 0.25},   -- dark grey
      {0.05, 0.05, 0.1, 0.2},   -- near-black
      {0.0, 0.3, 0.5, 0.08},    -- neon blue accent
      {0.0, 0.5, 0.3, 0.06},    -- neon green accent
    },
    asteroidColor = {0.2, 0.2, 0.25}, -- Dark icy
    hazard = "cold",
    coldDamage = 3, -- DPS while in this constellation
    asteroidDensityMod = 1.5,
    -- Comets spawn occasionally
    hasComets = true,
    cometColors = {{0.0, 0.8, 1.0}, {0.0, 1.0, 0.5}, {0.8, 0.0, 1.0}},
  },

  messier = {
    name = "Messier",
    description = "An ancient globular cluster of cream and gold stars",
    -- Messier 80 inspired: dense warm star field
    bgColor = {0.03, 0.025, 0.015},
    starColors = {{1.0, 0.95, 0.8}, {1.0, 0.85, 0.6}, {0.95, 0.9, 0.75}},
    cloudPalette = {
      {0.8, 0.7, 0.4, 0.15},   -- cream
      {0.9, 0.75, 0.3, 0.12},  -- gold
      {0.7, 0.6, 0.3, 0.1},    -- amber
      {0.6, 0.5, 0.25, 0.08},  -- bronze
    },
    asteroidColor = {0.8, 0.7, 0.5}, -- Warm toned
    hazard = nil,
    asteroidDensityMod = 0.8,
    -- Extra dense star field with cream/gold palette
    extraStars = true,
    starDensityMult = 3, -- 3x normal star count
  },

  vela = {
    name = "Vela",
    description = "Home of the Vela Pulsar - deadly energy bursts every 5 minutes",
    -- Pulsar: intense blue-white with purple/cyan streaks
    bgColor = {0.015, 0.01, 0.03},
    starColors = {{0.8, 0.8, 1.0}, {0.6, 0.5, 0.9}, {0.9, 0.7, 1.0}},
    cloudPalette = {
      {0.5, 0.3, 0.8, 0.2},    -- purple
      {0.3, 0.4, 0.9, 0.15},   -- blue
      {0.7, 0.5, 1.0, 0.12},   -- lavender
      {0.2, 0.6, 0.8, 0.1},    -- cyan
    },
    asteroidColor = {0.6, 0.5, 0.7},
    hazard = "pulsar",
    pulsarInterval = 300, -- 5 minutes (300 seconds)
    pulsarDamage = 9999,  -- Max damage (instant kill if unshielded)
    pulsarWarningTime = 30, -- 30 seconds of warning before burst
    asteroidDensityMod = 1.0,
  },

  pandora = {
    name = "Pandora",
    description = "A chaotic cluster radiating intense heat in unstable sectors",
    -- Pandora's Cluster: deep blues with hot zones
    bgColor = {0.01, 0.015, 0.04},
    starColors = {{0.6, 0.7, 1.0}, {0.4, 0.5, 0.9}, {0.7, 0.8, 1.0}},
    cloudPalette = {
      {0.2, 0.3, 0.8, 0.2},    -- deep blue
      {0.3, 0.5, 1.0, 0.18},   -- bright blue
      {0.15, 0.25, 0.7, 0.15}, -- navy
      {0.4, 0.6, 0.9, 0.1},    -- sky blue
    },
    asteroidColor = {0.5, 0.6, 0.8},
    hazard = "hot_sectors",
    hotDamage = 5, -- DPS in hot sectors
    asteroidDensityMod = 1.1,
    -- Some sectors within Pandora are Hot (random based on tile coords)
    hotSectorChance = 0.35, -- ~35% of tiles are hot
  },

  orion = {
    name = "Orion",
    description = "The great Orion Nebula - pillars of gas and newborn stars",
    -- Orion Nebula: pink, cyan, magenta gas clouds
    bgColor = {0.02, 0.015, 0.025},
    starColors = {{1.0, 0.85, 0.9}, {0.9, 0.95, 1.0}, {1.0, 0.9, 0.95}},
    cloudPalette = {
      {0.7, 0.3, 0.4, 0.22},   -- rose/pink
      {0.3, 0.5, 0.6, 0.18},   -- teal/cyan
      {0.6, 0.2, 0.5, 0.15},   -- magenta
      {0.8, 0.4, 0.3, 0.12},   -- salmon
    },
    asteroidColor = {0.7, 0.6, 0.65},
    hazard = nil,
    asteroidDensityMod = 1.0,
    -- Dense gas pillars (extra large clouds)
    gasPillars = true,
  },

  andromeda = {
    name = "Andromeda",
    description = "A spiral galaxy - each sector reveals different galactic arms",
    -- Andromeda galaxy: varies by sector (arms have distinct palettes)
    bgColor = {0.015, 0.015, 0.025},
    starColors = {{0.9, 0.9, 1.0}, {1.0, 0.95, 0.85}, {0.85, 0.9, 1.0}},
    cloudPalette = {
      {0.4, 0.3, 0.6, 0.18},   -- violet (core)
      {0.3, 0.4, 0.7, 0.15},   -- blue (arm 1)
      {0.5, 0.4, 0.3, 0.12},   -- gold (arm 2)
      {0.6, 0.3, 0.4, 0.1},    -- rose (arm 3)
    },
    asteroidColor = {0.65, 0.6, 0.7},
    hazard = nil,
    asteroidDensityMod = 0.9,
    -- Each sector uses a different sub-palette based on position
    spiralArms = true,
    armPalettes = {
      -- Core
      {{0.5, 0.4, 0.7, 0.2}, {0.6, 0.5, 0.8, 0.15}, {0.4, 0.3, 0.6, 0.12}, {1.0, 0.9, 0.7, 0.1}},
      -- Arm 1: Blue/cyan
      {{0.2, 0.4, 0.8, 0.2}, {0.3, 0.5, 0.9, 0.15}, {0.15, 0.35, 0.7, 0.12}, {0.4, 0.6, 1.0, 0.1}},
      -- Arm 2: Gold/amber
      {{0.8, 0.6, 0.2, 0.2}, {0.9, 0.7, 0.3, 0.15}, {0.7, 0.5, 0.2, 0.12}, {1.0, 0.8, 0.4, 0.1}},
      -- Arm 3: Rose/pink
      {{0.8, 0.3, 0.4, 0.2}, {0.9, 0.4, 0.5, 0.15}, {0.7, 0.3, 0.35, 0.12}, {1.0, 0.5, 0.6, 0.1}},
    },
  },
}

-- Default constellation for unnamed sectors
M.CONSTELLATIONS.generic = {
  name = "Deep Space",
  description = "Uncharted regions of Inner Space",
  bgColor = {0.02, 0.02, 0.04},
  starColors = {{1,1,1}, {0.9,0.9,1}, {1,0.95,0.9}},
  cloudPalette = {
    {0.3, 0.3, 0.4, 0.12},
    {0.2, 0.2, 0.35, 0.1},
    {0.25, 0.3, 0.4, 0.08},
    {0.2, 0.25, 0.3, 0.06},
  },
  asteroidColor = {0.6, 0.6, 0.6},
  hazard = nil,
  asteroidDensityMod = 1.0,
}

-- Outer Space (beyond 49x49)
M.CONSTELLATIONS.outer_space = {
  name = "Outer Space",
  description = "The vast emptiness beyond the Inner Space constellations",
  bgColor = {0.01, 0.01, 0.02},
  starColors = {{0.7,0.7,0.7}, {0.6,0.6,0.7}, {0.8,0.8,0.8}},
  cloudPalette = {
    {0.15, 0.15, 0.2, 0.08},
    {0.1, 0.1, 0.15, 0.06},
    {0.12, 0.12, 0.18, 0.05},
    {0.1, 0.1, 0.12, 0.04},
  },
  asteroidColor = {0.5, 0.5, 0.5},
  hazard = nil,
  asteroidDensityMod = 0.5,
}

-- ===================== CONSTELLATION LOOKUP =====================

-- Get constellation grid coordinates from tile coordinates
function M.getConstellationCoords(tileX, tileY)
  -- Each constellation is 7x7 tiles
  -- Constellation (0,0) covers tiles -3..3
  -- Constellation (1,0) covers tiles 4..10, etc.
  local cx = math.floor((tileX + 3) / 7)
  local cy = math.floor((tileY + 3) / 7)
  return cx, cy
end

-- Get the local tile position within a constellation (0-6)
function M.getLocalTilePos(tileX, tileY)
  local lx = ((tileX + 3) % 7)
  local ly = ((tileY + 3) % 7)
  return lx, ly
end

-- Get constellation ID for a tile position
function M.getConstellationId(tileX, tileY)
  -- Check if tile is in Outer Space (beyond 49x49 inner range)
  if math.abs(tileX) > 24 or math.abs(tileY) > 24 then
    return "outer_space"
  end

  local cx, cy = M.getConstellationCoords(tileX, tileY)
  local key = cx .. "," .. cy
  return M.CONSTELLATION_NAMES[key] or "generic"
end

-- Get constellation data for a tile
function M.getConstellation(tileX, tileY)
  local id = M.getConstellationId(tileX, tileY)
  return M.CONSTELLATIONS[id], id
end

-- Get constellation center tile (absolute coords)
function M.getConstellationCenter(tileX, tileY)
  local cx, cy = M.getConstellationCoords(tileX, tileY)
  -- Center of constellation in tile coords
  local centerX = cx * 7
  local centerY = cy * 7
  return centerX, centerY
end

-- ===================== HAZARD CHECKS =====================

-- Check if a tile is a hot sector in Pandora
function M.isHotSector(tileX, tileY)
  local id = M.getConstellationId(tileX, tileY)
  if id ~= "pandora" then return false end

  local data = M.CONSTELLATIONS.pandora
  -- Deterministic random based on tile coords
  local seed = tileX * 7919 + tileY * 6271 + 42
  local hash = math.abs(seed * 2654435761 % 2^32) / 2^32
  return hash < data.hotSectorChance
end

-- Calculate gravity pull for Gargantua (returns dx, dy acceleration)
function M.getGravityPull(tileX, tileY, shipX, shipY, screenW, screenH)
  local id = M.getConstellationId(tileX, tileY)
  if id ~= "gargantua" then return 0, 0 end

  local data = M.CONSTELLATIONS.gargantua
  local centerTileX, centerTileY = M.getConstellationCenter(tileX, tileY)

  -- Calculate distance from ship to center of Gargantua in tile+pixel space
  local tileDX = centerTileX - tileX
  local tileDY = centerTileY - tileY
  -- Convert to pixel distance (approximate, each tile = screen size)
  local pixDX = tileDX * screenW + (screenW / 2 - shipX)
  local pixDY = tileDY * screenH + (screenH / 2 - shipY)
  local dist = math.sqrt(pixDX * pixDX + pixDY * pixDY)

  if dist < 10 then return 0, 0 end

  -- Tiles from center (used for gravity strength scaling)
  local tileDist = math.sqrt(tileDX * tileDX + tileDY * tileDY)
  -- Max distance in constellation = ~4.5 tiles from center
  local maxDist = 4.5
  -- Gravity gets STRONGER closer to center (inverse square-ish)
  local proximity = 1.0 - math.min(1.0, tileDist / maxDist)
  local strength = data.gravityStrength * (proximity * proximity)

  -- Direction toward center
  local nx = pixDX / dist
  local ny = pixDY / dist

  return nx * strength, ny * strength
end

-- Get Vela pulsar timer state
-- Returns: timeUntilBurst, isWarning, burstActive
M.velaPulsarTimer = 0
M.velaPulsarBurstActive = false
M.velaPulsarBurstTimer = 0
M.wasInVela = false  -- Track entry/exit for timer reset

function M.updateVelaPulsar(dt, tileX, tileY)
  local id = M.getConstellationId(tileX, tileY)
  if id ~= "vela" then
    -- Reset state when leaving Vela
    M.velaPulsarBurstActive = false
    M.wasInVela = false
    return
  end

  -- Reset timer to full countdown when first entering Vela
  if not M.wasInVela then
    M.velaPulsarTimer = 0
    M.velaPulsarBurstActive = false
    M.velaPulsarBurstTimer = 0
    M.wasInVela = true
  end

  local data = M.CONSTELLATIONS.vela
  M.velaPulsarTimer = M.velaPulsarTimer + dt

  if M.velaPulsarBurstActive then
    M.velaPulsarBurstTimer = M.velaPulsarBurstTimer + dt
    if M.velaPulsarBurstTimer >= 3.0 then
      M.velaPulsarBurstActive = false
    end
    return
  end

  if M.velaPulsarTimer >= data.pulsarInterval then
    M.velaPulsarTimer = 0
    M.velaPulsarBurstActive = true
    M.velaPulsarBurstTimer = 0
  end
end

function M.getVelaPulsarState(tileX, tileY)
  local id = M.getConstellationId(tileX, tileY)
  if id ~= "vela" then return nil end

  local data = M.CONSTELLATIONS.vela
  local timeLeft = data.pulsarInterval - M.velaPulsarTimer
  local isWarning = timeLeft <= data.pulsarWarningTime and not M.velaPulsarBurstActive
  return {
    timeUntilBurst = timeLeft,
    isWarning = isWarning,
    burstActive = M.velaPulsarBurstActive,
    burstProgress = M.velaPulsarBurstActive and (M.velaPulsarBurstTimer / 3.0) or 0,
  }
end

-- ===================== COMET SYSTEM (Oort Cloud) =====================

M.comets = {}

function M.updateComets(dt, tileX, tileY, screenW, screenH)
  local id = M.getConstellationId(tileX, tileY)
  local data = M.CONSTELLATIONS[id]

  if not data or not data.hasComets then
    M.comets = {}
    return
  end

  -- Spawn comets randomly
  if #M.comets < 3 and math.random() < dt * 0.3 then
    local colors = data.cometColors
    local color = colors[math.random(#colors)]
    local side = math.random(4)
    local x, y, vx, vy
    if side == 1 then
      x = -50; y = math.random(screenH)
      vx = 200 + math.random() * 300; vy = (math.random() - 0.5) * 200
    elseif side == 2 then
      x = screenW + 50; y = math.random(screenH)
      vx = -(200 + math.random() * 300); vy = (math.random() - 0.5) * 200
    elseif side == 3 then
      x = math.random(screenW); y = -50
      vx = (math.random() - 0.5) * 200; vy = 200 + math.random() * 300
    else
      x = math.random(screenW); y = screenH + 50
      vx = (math.random() - 0.5) * 200; vy = -(200 + math.random() * 300)
    end
    table.insert(M.comets, {
      x = x, y = y, vx = vx, vy = vy,
      size = 4 + math.random() * 6,
      color = color,
      trail = {},
      life = 0,
    })
  end

  -- Update comets
  for i = #M.comets, 1, -1 do
    local c = M.comets[i]
    c.x = c.x + c.vx * dt
    c.y = c.y + c.vy * dt
    c.life = c.life + dt

    -- Add trail points
    table.insert(c.trail, 1, {x = c.x, y = c.y, age = 0})
    for j = #c.trail, 1, -1 do
      c.trail[j].age = c.trail[j].age + dt
      if c.trail[j].age > 0.5 then
        table.remove(c.trail, j)
      end
    end
    -- Keep trail manageable
    while #c.trail > 30 do
      table.remove(c.trail)
    end

    -- Remove when off screen
    if c.x < -100 or c.x > screenW + 100 or c.y < -100 or c.y > screenH + 100 then
      table.remove(M.comets, i)
    end
  end
end

function M.drawComets()
  for _, c in ipairs(M.comets) do
    -- Draw trail
    for j, t in ipairs(c.trail) do
      local alpha = (1 - t.age / 0.5) * 0.6
      local size = c.size * (1 - t.age / 0.5) * 0.5
      love.graphics.setColor(c.color[1], c.color[2], c.color[3], alpha)
      love.graphics.circle("fill", t.x, t.y, math.max(1, size))
    end
    -- Draw comet head
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", c.x, c.y, c.size * 0.6)
    love.graphics.setColor(c.color[1], c.color[2], c.color[3], 0.7)
    love.graphics.circle("fill", c.x, c.y, c.size)
  end
end

-- ===================== ANDROMEDA SPIRAL ARM PALETTE =====================

function M.getAndromedaPalette(tileX, tileY)
  local data = M.CONSTELLATIONS.andromeda
  if not data.spiralArms then return data.cloudPalette end

  local lx, ly = M.getLocalTilePos(tileX, tileY)
  -- Calculate angle from constellation center to determine which arm
  local dx = lx - 3
  local dy = ly - 3
  local angle = math.atan2(dy, dx)
  local dist = math.sqrt(dx * dx + dy * dy)

  if dist < 1.5 then
    -- Core
    return data.armPalettes[1]
  else
    -- Spiral arm based on angle
    local armIndex = math.floor(((angle + math.pi) / (2 * math.pi)) * 3) + 1
    armIndex = math.max(1, math.min(3, armIndex))
    return data.armPalettes[armIndex + 1]
  end
end

-- ===================== VISUAL HELPERS =====================

-- Get the appropriate cloud palette for a tile
function M.getCloudPalette(tileX, tileY)
  local constellation, id = M.getConstellation(tileX, tileY)
  if id == "andromeda" and constellation.spiralArms then
    return M.getAndromedaPalette(tileX, tileY)
  end
  return constellation.cloudPalette
end

-- Get asteroid visual properties for a tile
function M.getAsteroidVisuals(tileX, tileY)
  local constellation, id = M.getConstellation(tileX, tileY)
  return {
    color = constellation.asteroidColor,
    glow = constellation.asteroidGlow,
    density = constellation.asteroidDensityMod,
    icy = (id == "oort"),        -- Dark ice look
    crystal = (id == "pleiades"), -- Crystalline sparkle
    warm = (id == "messier"),    -- Cream/gold tint
  }
end

-- Get star generation parameters for a tile
function M.getStarParams(tileX, tileY)
  local constellation = M.getConstellation(tileX, tileY)
  local count = 200
  local brightCount = 30
  if constellation.extraStars then
    count = count * (constellation.starDensityMult or 2)
    brightCount = brightCount * (constellation.starDensityMult or 2)
  end
  return {
    colors = constellation.starColors,
    count = count,
    brightCount = brightCount,
    bgColor = constellation.bgColor,
  }
end

-- Get constellation display name for HUD
function M.getConstellationName(tileX, tileY)
  local constellation = M.getConstellation(tileX, tileY)
  return constellation.name
end

return M
