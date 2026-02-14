local M = {}
local constellation = require("asteroids.constellation")

-- Dynamic grid bounds (change based on progression)
M.GRID_MIN = -3
M.GRID_MAX = 3

-- Current tile position
M.tileX = 0
M.tileY = 0

-- Tile types
M.TILE_EMPTY = "empty"
M.TILE_STATION = "station"
M.TILE_PORTAL = "portal"

-- Tile data indexed by "x,y" string key (only special tiles are stored)
local tiles = {}

-- Tile cache for dynamically generated tiles
local tileCache = {}

-- Initialize special tile data (stations, portals)
local function initTiles()
  tiles = {}
  tileCache = {}

  -- ===== THE NEBULA (center constellation, tiles -3..3) =====

  -- Center tile (0,0): Hometown Station
  tiles["0,0"] = {
    type = M.TILE_STATION,
    name = "Hometown Station",
    color = {0.4, 0.6, 0.9},
    helipads = {
      {x = 400, y = 300},
      {x = 550, y = 350},
      {x = 250, y = 350}
    },
    asteroidDensity = 0
  }

  -- Portal tile (0,3): The Warden
  tiles["0,3"] = {
    type = M.TILE_PORTAL,
    name = "The Warden",
    portalTarget = "warden",
    starfoxLevelId = 19,
    color = {0.8, 0.3, 0.3},
    asteroidDensity = 0.5
  }

  -- Portal tile (3,0): Vacuous Voidway (Sector X)
  tiles["3,0"] = {
    type = M.TILE_PORTAL,
    name = "Vacuous Voidway",
    portalTarget = "sector_x",
    starfoxLevelId = 8,
    color = {0.3, 0.8, 0.8},
    asteroidDensity = 0.7
  }

  -- Portal tile (-3,0): Cakewalk Corner (Corneria)
  tiles["-3,0"] = {
    type = M.TILE_PORTAL,
    name = "Cakewalk Corner",
    portalTarget = "corneria",
    starfoxLevelId = 1,
    color = {0.4, 0.9, 0.4},
    asteroidDensity = 0.3
  }

  -- Portal tile (0,-3): Asteroid Alley (Meteo)
  tiles["0,-3"] = {
    type = M.TILE_PORTAL,
    name = "Asteroid Alley",
    portalTarget = "meteo",
    starfoxLevelId = 2,
    color = {0.6, 0.5, 0.4},
    asteroidDensity = 0.9
  }

  -- ===== RAID PORTALS (corners of The Nebula) =====

  -- Portal tile (-3,-3): Synesthesia Installation
  tiles["-3,-3"] = {
    type = M.TILE_PORTAL,
    name = "Synesthesia Installation",
    portalTarget = "synesthesia",
    starfoxLevelId = 21,
    color = {0.2, 0.9, 0.9},
    asteroidDensity = 0.8
  }

  -- Portal tile (3,-3): Megalith of Memories
  tiles["3,-3"] = {
    type = M.TILE_PORTAL,
    name = "Megalith of Memories",
    portalTarget = "megalith",
    starfoxLevelId = 22,
    color = {0.3, 0.5, 0.9},
    asteroidDensity = 0.8
  }

  -- Portal tile (-3,3): Distant Dynamo
  tiles["-3,3"] = {
    type = M.TILE_PORTAL,
    name = "Distant Dynamo",
    portalTarget = "dynamo",
    starfoxLevelId = 23,
    color = {0.9, 0.6, 0.1},
    asteroidDensity = 0.8
  }

  -- Portal tile (3,3): Logician's Lament
  tiles["3,3"] = {
    type = M.TILE_PORTAL,
    name = "Logician's Lament",
    portalTarget = "logician",
    starfoxLevelId = 25,
    color = {0.7, 0.2, 0.9},
    asteroidDensity = 0.8
  }

  -- Portal tile (1,1): The Sphere
  tiles["1,1"] = {
    type = M.TILE_PORTAL,
    name = "The Sphere",
    portalTarget = "sphere",
    starfoxLevelId = 24,
    color = {0.5, 0.5, 0.5},
    asteroidDensity = 0.7
  }

  -- Portal tile (-1,-1): The Machine
  tiles["-1,-1"] = {
    type = M.TILE_PORTAL,
    name = "The Machine",
    portalTarget = "machine",
    starfoxLevelId = 26,
    color = {0.9, 0.3, 0.3},
    asteroidDensity = 0.9
  }

  -- Station tile (-2,2): Leucadia Beach Town
  tiles["-2,2"] = {
    type = M.TILE_STATION,
    name = "Leucadia",
    hubType = "leucadia",
    color = {0.3, 0.7, 0.9},
    helipads = {
      {x = 400, y = 200},
      {x = 600, y = 350},
      {x = 200, y = 400}
    },
    asteroidDensity = 0
  }

  -- Station tile (3,2): Mixia
  tiles["3,2"] = {
    type = M.TILE_STATION,
    name = "Mixia",
    hubType = "mixia",
    color = {0.7, 0.8, 0.95},
    helipads = {
      {x = 683, y = 300},
      {x = 400, y = 400},
      {x = 900, y = 350}
    },
    asteroidDensity = 0
  }

  -- ===== GARGANTUA (constellation 1,0 → tiles 4..10, -3..3) =====
  -- The Singularity at the center of Gargantua
  tiles["7,0"] = {
    type = M.TILE_STATION,
    name = "The Singularity",
    hubType = "singularity",
    color = {0.9, 0.6, 0.2},
    helipads = {
      {x = 683, y = 400},
      {x = 400, y = 250},
      {x = 900, y = 300}
    },
    asteroidDensity = 0
  }

  -- ===== PORTALS IN EXPANDED CONSTELLATIONS =====
  -- The Sentinel portal in Andromeda (constellation 1,-1)
  tiles["7,-7"] = {
    type = M.TILE_PORTAL,
    name = "The Sentinel",
    portalTarget = "sentinel",
    starfoxLevelId = 20,
    color = {0.6, 0.3, 0.8},
    asteroidDensity = 0.6
  }
end

-- Generate tile data dynamically for any position
local function generateTile(x, y)
  local key = x .. "," .. y

  -- Check if it's a pre-defined special tile
  if tiles[key] then
    return tiles[key]
  end

  -- Check cache
  if tileCache[key] then
    return tileCache[key]
  end

  -- Get constellation info
  local cData, cId = constellation.getConstellation(x, y)
  local constellationName = cData.name

  -- Distance from the center of the constellation
  local cx, cy = constellation.getConstellationCenter(x, y)
  local dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))

  -- Base asteroid density from distance + constellation modifier
  local baseDensity = 0.3 + dist * 0.12
  local density = math.min(1.0, baseDensity * cData.asteroidDensityMod)

  -- Sector name includes constellation
  local sectorName = constellationName .. " (" .. x .. "," .. y .. ")"

  local tile = {
    type = M.TILE_EMPTY,
    name = sectorName,
    color = {cData.bgColor[1] * 10 + 0.2, cData.bgColor[2] * 10 + 0.2, cData.bgColor[3] * 10 + 0.2},
    asteroidDensity = density,
    constellation = cId,
  }

  tileCache[key] = tile
  return tile
end

function M.init()
  M.tileX = 0
  M.tileY = 0
  initTiles()
  M.updateBounds()
end

function M.updateBounds()
  local gridMin, gridMax = constellation.getGridBounds()
  M.GRID_MIN = gridMin
  M.GRID_MAX = gridMax
end

function M.setProgression(antennaInstalled, sentinelDefeated)
  constellation.setProgression(antennaInstalled, sentinelDefeated)
  M.updateBounds()
end

function M.getTile(x, y)
  local key = x .. "," .. y
  if tiles[key] then
    return tiles[key]
  end
  return generateTile(x, y)
end

function M.getCurrentTile()
  return M.getTile(M.tileX, M.tileY)
end

function M.setPosition(x, y)
  M.tileX = math.max(M.GRID_MIN, math.min(M.GRID_MAX, x))
  M.tileY = math.max(M.GRID_MIN, math.min(M.GRID_MAX, y))
end

-- Returns new tile position if moving off edge, or nil if at grid boundary
function M.checkEdgeTransition(shipX, shipY, width, height)
  local newTileX = M.tileX
  local newTileY = M.tileY
  local wrapX = shipX
  local wrapY = shipY
  local transitioned = false

  if shipX < 0 then
    if M.tileX > M.GRID_MIN then
      newTileX = M.tileX - 1
      wrapX = width
      transitioned = true
    else
      wrapX = 0
    end
  elseif shipX > width then
    if M.tileX < M.GRID_MAX then
      newTileX = M.tileX + 1
      wrapX = 0
      transitioned = true
    else
      wrapX = width
    end
  end

  if shipY < 0 then
    if M.tileY < M.GRID_MAX then
      newTileY = M.tileY + 1
      wrapY = height
      transitioned = true
    else
      wrapY = 0
    end
  elseif shipY > height then
    if M.tileY > M.GRID_MIN then
      newTileY = M.tileY - 1
      wrapY = 0
      transitioned = true
    else
      wrapY = height
    end
  end

  return transitioned, newTileX, newTileY, wrapX, wrapY
end

function M.getAsteroidCount(baseCount)
  local tile = M.getCurrentTile()
  if tile then
    return math.floor(baseCount * tile.asteroidDensity)
  end
  return baseCount
end

function M.isAtStation()
  local tile = M.getCurrentTile()
  return tile and tile.type == M.TILE_STATION
end

function M.getStationInfo()
  local tile = M.getCurrentTile()
  if tile and tile.type == M.TILE_STATION then
    return {
      name = tile.name,
      hubType = tile.hubType or "hometown",
      color = tile.color
    }
  end
  return nil
end

function M.getHelipads()
  local tile = M.getCurrentTile()
  if tile and tile.helipads then
    return tile.helipads
  end
  return {}
end

function M.isAtPortal()
  local tile = M.getCurrentTile()
  return tile and tile.type == M.TILE_PORTAL
end

function M.getPortalInfo()
  local tile = M.getCurrentTile()
  if tile and tile.type == M.TILE_PORTAL then
    return {
      name = tile.name,
      target = tile.portalTarget,
      starfoxLevelId = tile.starfoxLevelId
    }
  end
  return nil
end

-- Get constellation module reference
function M.getConstellation()
  return constellation
end

-- Get the current constellation name for HUD display
function M.getConstellationName()
  return constellation.getConstellationName(M.tileX, M.tileY)
end

-- Get current constellation ID
function M.getConstellationId()
  return constellation.getConstellationId(M.tileX, M.tileY)
end

return M
