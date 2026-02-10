local M = {}

-- 7x7 grid centered at (0,0), ranges from -3 to 3
M.GRID_MIN = -3
M.GRID_MAX = 3

-- Current tile position
M.tileX = 0
M.tileY = 0

-- Tile types
M.TILE_EMPTY = "empty"
M.TILE_STATION = "station"
M.TILE_PORTAL = "portal"

-- Tile data indexed by "x,y" string key
local tiles = {}

-- Initialize tile data
local function initTiles()
  tiles = {}

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
    asteroidDensity = 0 -- No asteroids at station
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

  -- Fill empty tiles with varying asteroid densities
  for x = M.GRID_MIN, M.GRID_MAX do
    for y = M.GRID_MIN, M.GRID_MAX do
      local key = x .. "," .. y
      if not tiles[key] then
        -- Distance from center affects asteroid density
        local dist = math.sqrt(x * x + y * y)
        local density = 0.3 + dist * 0.15
        tiles[key] = {
          type = M.TILE_EMPTY,
          name = "Sector " .. x .. "," .. y,
          color = {0.3, 0.3, 0.4},
          asteroidDensity = math.min(density, 1.0)
        }
      end
    end
  end
end

function M.init()
  M.tileX = 0
  M.tileY = 0
  initTiles()
end

function M.getTile(x, y)
  local key = x .. "," .. y
  return tiles[key]
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
      wrapX = 0 -- Clamp at boundary
    end
  elseif shipX > width then
    if M.tileX < M.GRID_MAX then
      newTileX = M.tileX + 1
      wrapX = 0
      transitioned = true
    else
      wrapX = width -- Clamp at boundary
    end
  end

  if shipY < 0 then
    if M.tileY < M.GRID_MAX then
      newTileY = M.tileY + 1  -- Going up increments Y
      wrapY = height
      transitioned = true
    else
      wrapY = 0
    end
  elseif shipY > height then
    if M.tileY > M.GRID_MIN then
      newTileY = M.tileY - 1  -- Going down decrements Y
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

return M
