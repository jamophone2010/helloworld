-- asteroids/dungeon.lua
-- Zelda-dungeon-style constellation regions at the four Deep Space corners.
-- Each corner constellation (7x7 tiles) is a themed dungeon with maze walls,
-- obstacles, enemies, and increasingly psychedelic decorations closer to the
-- corner portal tile.
--
-- The four dungeons:
--   Megalith of Memories  (3,3)   — RAM/NAND/hard-drive theme
--   Distant Dynamo        (-3,-3) — power cables/transformers/heat theme
--   Logician's Lament     (3,-3)  — CPU die / metal-layer maze
--   Synesthesia Install.  (-3,3)  — GPU / Nvidia hype-video theme
--
-- Dungeon architecture (per tile):
--   • Maze walls — solid barriers the ship cannot pass through
--   • Hazard zones — electric fields, heat vents, data streams
--   • Enemies — dungeon guardians (turrets, roaming sentries, etc.)
--   • Decorations — themed background/foreground art
--   • Intensity — increases as tiles approach the corner portal

local M = {}
local constellation = require("asteroids.constellation")

-- ===================== CONSTANTS =====================

local WALL_THICKNESS = 18          -- pixel width of maze walls
local WALL_COLOR = {0.25, 0.25, 0.3, 0.9}
local FIELD_DAMAGE = 4             -- DPS from electric fields / hazard zones
local TURRET_SHOOT_INTERVAL = 2.0  -- seconds between turret shots
local SENTRY_SPEED = 120           -- pixels/sec for roaming sentries
local SENTRY_HEALTH = 5

-- ===================== DUNGEON STATE =====================

-- Current dungeon data (regenerated on tile enter)
local current = {
  active = false,
  dungeonId = nil,      -- "megalith", "dynamo", "logician", "synesthesia"
  tileX = 0,
  tileY = 0,
  intensity = 0,        -- 0..1, higher = closer to corner
  walls = {},           -- {x, y, w, h} rectangles
  hazardZones = {},     -- {x, y, w, h, type, timer}
  turrets = {},         -- {x, y, angle, timer, health}
  sentries = {},        -- {x, y, vx, vy, health, angle, patrol}
  decorations = {},     -- {type, x, y, ...} themed background elements
  fgDecorations = {},   -- foreground overlay decorations
  time = 0,
}

-- ===================== INTENSITY CALCULATION =====================

-- Intensity goes from 0 (farthest from portal) to 1 (portal tile).
-- Based on Chebyshev distance from the constellation center to the corner.
local function calcIntensity(tileX, tileY, dungeonId)
  local cx, cy = constellation.getConstellationCoords(tileX, tileY)
  -- Local position within the constellation (0-6)
  local lx, ly = constellation.getLocalTilePos(tileX, tileY)

  -- The portal is at the extreme corner of the constellation.
  -- Figure out which corner based on dungeonId:
  local cornerLX, cornerLY
  if dungeonId == "megalith" then      -- (3,3)  → top-right → local (6,6)
    cornerLX, cornerLY = 6, 6
  elseif dungeonId == "dynamo" then    -- (-3,-3) → bottom-left → local (0,0)
    cornerLX, cornerLY = 0, 0
  elseif dungeonId == "logician" then  -- (3,-3)  → bottom-right → local (6,0)
    cornerLX, cornerLY = 6, 0
  elseif dungeonId == "synesthesia" then -- (-3,3) → top-left → local (0,6)
    cornerLX, cornerLY = 0, 6
  else
    return 0
  end

  -- Chebyshev distance from corner (max 6)
  local dist = math.max(math.abs(lx - cornerLX), math.abs(ly - cornerLY))
  return math.max(0, 1 - dist / 6)
end

-- ===================== DETERMINISTIC RNG =====================

local dungeonRng = 0
local function dungeonSeed(tileX, tileY, salt)
  dungeonRng = math.abs((tileX * 73856093 + tileY * 19349663 + (salt or 0) * 83492791) % 2147483647)
end
local function dungeonRand()
  dungeonRng = (dungeonRng * 1103515245 + 12345) % 2147483648
  return dungeonRng / 2147483648
end
local function dungeonRandInt(a, b)
  return a + math.floor(dungeonRand() * (b - a + 1))
end

-- ===================== MAZE GENERATION =====================

-- Generate maze walls for a single tile.
-- Uses a simple recursive-backtracker on a small grid, then converts to wall rects.
-- Grid is 9x7 cells (wider than tall for widescreen).
-- The maze always has openings on edges that connect to neighboring tiles.

local MAZE_COLS = 9
local MAZE_ROWS = 7

local function generateMaze(width, height, tileX, tileY, dungeonId, intensity)
  dungeonSeed(tileX, tileY, 777)

  local cellW = math.floor(width / MAZE_COLS)
  local cellH = math.floor(height / MAZE_ROWS)

  -- Initialize grid: each cell tracks which walls are open
  -- walls[r][c] = {top=true, right=true, bottom=true, left=true}
  local grid = {}
  for r = 1, MAZE_ROWS do
    grid[r] = {}
    for c = 1, MAZE_COLS do
      grid[r][c] = {top = true, right = true, bottom = true, left = true, visited = false}
    end
  end

  -- Recursive backtracker
  local stack = {}
  local startR = dungeonRandInt(1, MAZE_ROWS)
  local startC = dungeonRandInt(1, MAZE_COLS)
  grid[startR][startC].visited = true
  table.insert(stack, {startR, startC})

  while #stack > 0 do
    local cr, cc = stack[#stack][1], stack[#stack][2]
    -- Collect unvisited neighbors
    local neighbors = {}
    if cr > 1 and not grid[cr-1][cc].visited then table.insert(neighbors, {cr-1, cc, "top", "bottom"}) end
    if cr < MAZE_ROWS and not grid[cr+1][cc].visited then table.insert(neighbors, {cr+1, cc, "bottom", "top"}) end
    if cc > 1 and not grid[cr][cc-1].visited then table.insert(neighbors, {cr, cc-1, "left", "right"}) end
    if cc < MAZE_COLS and not grid[cr][cc+1].visited then table.insert(neighbors, {cr, cc+1, "right", "left"}) end

    if #neighbors > 0 then
      -- Pick random neighbor
      local pick = neighbors[dungeonRandInt(1, #neighbors)]
      local nr, nc, wall1, wall2 = pick[1], pick[2], pick[3], pick[4]
      grid[cr][cc][wall1] = false
      grid[nr][nc][wall2] = false
      grid[nr][nc].visited = true
      table.insert(stack, {nr, nc})
    else
      table.remove(stack)
    end
  end

  -- Always open passages on all 4 edges (so player can enter/exit the tile)
  -- Open at least 2 passages per edge
  for i = 1, 2 do
    local c = dungeonRandInt(1, MAZE_COLS)
    grid[1][c].top = false          -- top edge
    grid[MAZE_ROWS][c].bottom = false -- bottom edge
  end
  for i = 1, 2 do
    local r = dungeonRandInt(1, MAZE_ROWS)
    grid[r][1].left = false         -- left edge
    grid[r][MAZE_COLS].right = false -- right edge
  end

  -- Reduce wall density based on inverse intensity (outer tiles = easier)
  -- At intensity 0 remove ~60% of walls, at intensity 1 remove ~15%
  local removeChance = 0.6 - intensity * 0.45
  for r = 1, MAZE_ROWS do
    for c = 1, MAZE_COLS do
      if dungeonRand() < removeChance then grid[r][c].top = false end
      if dungeonRand() < removeChance then grid[r][c].left = false end
    end
  end

  -- Convert remaining walls to rectangles
  local walls = {}
  local t = WALL_THICKNESS

  for r = 1, MAZE_ROWS do
    for c = 1, MAZE_COLS do
      local x = (c - 1) * cellW
      local y = (r - 1) * cellH

      if grid[r][c].top then
        table.insert(walls, {x = x, y = y, w = cellW, h = t})
      end
      if grid[r][c].left then
        table.insert(walls, {x = x, y = y, w = t, h = cellH})
      end
      -- Right edge wall (only rightmost column)
      if c == MAZE_COLS and grid[r][c].right then
        table.insert(walls, {x = x + cellW - t, y = y, w = t, h = cellH})
      end
      -- Bottom edge wall (only bottom row)
      if r == MAZE_ROWS and grid[r][c].bottom then
        table.insert(walls, {x = x, y = y + cellH - t, w = cellW, h = t})
      end
    end
  end

  return walls, cellW, cellH
end

-- ===================== ENEMY GENERATION =====================

-- Turrets: stationary, shoot at the player periodically
local function spawnTurrets(width, height, walls, intensity, dungeonId)
  local turrets = {}
  local count = math.floor(1 + intensity * 4) -- 1-5 turrets
  dungeonSeed(current.tileX, current.tileY, 888)

  for i = 1, count do
    local x, y
    local attempts = 0
    repeat
      x = dungeonRand() * (width - 100) + 50
      y = dungeonRand() * (height - 100) + 50
      attempts = attempts + 1
    until attempts > 20 or not M.pointInWall(x, y, walls)

    table.insert(turrets, {
      x = x,
      y = y,
      angle = 0,
      timer = TURRET_SHOOT_INTERVAL * (0.5 + dungeonRand() * 0.5),
      health = 3 + math.floor(intensity * 4),
      maxHealth = 3 + math.floor(intensity * 4),
      size = 16,
      flashTimer = 0,
      dead = false,
      dungeonId = dungeonId,
    })
  end
  return turrets
end

-- Sentries: roaming enemies that patrol corridors
local function spawnSentries(width, height, walls, intensity, dungeonId)
  local sentries = {}
  local count = math.floor(intensity * 3) -- 0-3 sentries
  dungeonSeed(current.tileX, current.tileY, 999)

  for i = 1, count do
    local x, y
    local attempts = 0
    repeat
      x = dungeonRand() * (width - 100) + 50
      y = dungeonRand() * (height - 100) + 50
      attempts = attempts + 1
    until attempts > 20 or not M.pointInWall(x, y, walls)

    local angle = dungeonRand() * math.pi * 2
    table.insert(sentries, {
      x = x,
      y = y,
      vx = math.cos(angle) * SENTRY_SPEED,
      vy = math.sin(angle) * SENTRY_SPEED,
      health = SENTRY_HEALTH + math.floor(intensity * 5),
      maxHealth = SENTRY_HEALTH + math.floor(intensity * 5),
      size = 14,
      angle = angle,
      patrolTimer = 2 + dungeonRand() * 3,
      flashTimer = 0,
      dead = false,
      dungeonId = dungeonId,
    })
  end
  return sentries
end

-- ===================== HAZARD ZONE GENERATION =====================

local function spawnHazardZones(width, height, walls, intensity, dungeonId)
  local zones = {}
  local count = math.floor(1 + intensity * 3)
  dungeonSeed(current.tileX, current.tileY, 666)

  for i = 1, count do
    local zoneW = 80 + dungeonRand() * 120
    local zoneH = 80 + dungeonRand() * 120
    local x = dungeonRand() * (width - zoneW)
    local y = dungeonRand() * (height - zoneH)

    local zoneType
    if dungeonId == "megalith" then
      zoneType = "data_stream"
    elseif dungeonId == "dynamo" then
      zoneType = "heat_vent"
    elseif dungeonId == "logician" then
      zoneType = "electric_field"
    elseif dungeonId == "synesthesia" then
      zoneType = "shader_beam"
    else
      zoneType = "generic"
    end

    table.insert(zones, {
      x = x, y = y, w = zoneW, h = zoneH,
      type = zoneType,
      timer = 0,
      pulsePhase = dungeonRand() * math.pi * 2,
      active = true,
      damage = FIELD_DAMAGE * (0.5 + intensity * 0.5),
    })
  end
  return zones
end

-- ===================== DECORATION GENERATION =====================

-- Themed background decorations that intensify closer to the corner.

local function generateDecorations(width, height, intensity, dungeonId)
  local decs = {}
  local fgDecs = {}
  dungeonSeed(current.tileX, current.tileY, 555)

  if dungeonId == "megalith" then
    -- RAM cell grids, M.2 chip outlines, data bus traces, NAND cell arrays
    local gridCount = 3 + math.floor(intensity * 6)
    for i = 1, gridCount do
      local gw = 60 + dungeonRand() * 180
      local gh = 40 + dungeonRand() * 120
      table.insert(decs, {
        type = "ram_grid",
        x = dungeonRand() * (width - gw),
        y = dungeonRand() * (height - gh),
        w = gw, h = gh,
        cols = dungeonRandInt(4, 12),
        rows = dungeonRandInt(2, 8),
        activeChance = 0.3 + intensity * 0.5,
        pulseSpeed = 0.5 + dungeonRand() * 2,
        pulseOffset = dungeonRand() * math.pi * 2,
      })
    end
    -- M.2 chip outlines
    local chipCount = 1 + math.floor(intensity * 3)
    for i = 1, chipCount do
      table.insert(decs, {
        type = "m2_chip",
        x = dungeonRand() * (width - 200) + 20,
        y = dungeonRand() * (height - 100) + 10,
        w = 120 + dungeonRand() * 150,
        h = 50 + dungeonRand() * 60,
        pinCount = dungeonRandInt(8, 24),
        label = ({"NAND", "DDR5", "M.2", "NVMe", "SRAM", "DRAM", "FLASH", "ROM"})[dungeonRandInt(1, 8)],
      })
    end
    -- Data bus traces (horizontal/vertical lines)
    local traceCount = 5 + math.floor(intensity * 10)
    for i = 1, traceCount do
      local horizontal = dungeonRand() > 0.5
      table.insert(decs, {
        type = "data_trace",
        x = dungeonRand() * width,
        y = dungeonRand() * height,
        length = 100 + dungeonRand() * 300,
        horizontal = horizontal,
        colorIdx = dungeonRandInt(1, 4),
        pulseSpeed = 1 + dungeonRand() * 3,
        thickness = 1 + math.floor(intensity * 2),
      })
    end
    -- NAND cell arrays (psychedelic at high intensity)
    if intensity > 0.3 then
      local nandCount = math.floor(intensity * 4)
      for i = 1, nandCount do
        table.insert(fgDecs, {
          type = "nand_array",
          x = dungeonRand() * (width - 200),
          y = dungeonRand() * (height - 150),
          w = 150 + dungeonRand() * 200,
          h = 100 + dungeonRand() * 150,
          cells = dungeonRandInt(16, 64),
          glowIntensity = intensity,
        })
      end
    end

  elseif dungeonId == "dynamo" then
    -- Power cables, fans, transformers, sparks, heat waves
    local cableCount = 4 + math.floor(intensity * 8)
    for i = 1, cableCount do
      local pts = {}
      local px = dungeonRand() * width
      local py = dungeonRand() * height
      local segs = dungeonRandInt(4, 10)
      for s = 1, segs do
        table.insert(pts, {x = px, y = py})
        if dungeonRand() > 0.5 then
          px = px + (dungeonRand() - 0.5) * 150
        else
          py = py + (dungeonRand() - 0.5) * 150
        end
        px = math.max(0, math.min(width, px))
        py = math.max(0, math.min(height, py))
      end
      table.insert(decs, {
        type = "power_cable",
        points = pts,
        colorIdx = dungeonRandInt(1, 4),
        thickness = 2 + math.floor(intensity * 3),
        sparkChance = intensity * 0.3,
      })
    end
    -- Spinning fans
    local fanCount = 1 + math.floor(intensity * 3)
    for i = 1, fanCount do
      table.insert(decs, {
        type = "fan",
        x = dungeonRand() * (width - 100) + 50,
        y = dungeonRand() * (height - 100) + 50,
        radius = 30 + dungeonRand() * 50,
        blades = dungeonRandInt(3, 7),
        speed = 1 + dungeonRand() * 3 + intensity * 2,
        angleOffset = dungeonRand() * math.pi * 2,
      })
    end
    -- Transformer coils
    local xfmrCount = math.floor(intensity * 3)
    for i = 1, xfmrCount do
      table.insert(decs, {
        type = "transformer",
        x = dungeonRand() * (width - 80) + 40,
        y = dungeonRand() * (height - 80) + 40,
        w = 40 + dungeonRand() * 60,
        h = 50 + dungeonRand() * 70,
        coilTurns = dungeonRandInt(5, 15),
      })
    end
    -- Heat shimmer (foreground, psychedelic at high intensity)
    if intensity > 0.2 then
      table.insert(fgDecs, {
        type = "heat_shimmer",
        intensity = intensity,
      })
    end
    -- Electric arcs (foreground)
    if intensity > 0.4 then
      local arcCount = math.floor(intensity * 4)
      for i = 1, arcCount do
        table.insert(fgDecs, {
          type = "electric_arc",
          x1 = dungeonRand() * width,
          y1 = dungeonRand() * height,
          x2 = dungeonRand() * width,
          y2 = dungeonRand() * height,
          colorIdx = dungeonRandInt(1, 4),
          flickerSpeed = 3 + dungeonRand() * 5,
        })
      end
    end

  elseif dungeonId == "logician" then
    -- CPU die layout: metal layer traces, vias, logic gate symbols, electric fields
    -- The whole tile looks like a CPU die cross-section
    -- Background: silicon substrate grid
    table.insert(decs, {
      type = "substrate_grid",
      cellSize = 40 + math.floor(intensity * 20),
    })
    -- Metal layer traces (like top-metal routing)
    local traceCount = 8 + math.floor(intensity * 12)
    for i = 1, traceCount do
      local pts = {}
      local px = dungeonRand() * width
      local py = dungeonRand() * height
      local segs = dungeonRandInt(3, 8)
      for s = 1, segs do
        table.insert(pts, {x = px, y = py})
        -- Manhattan routing (90-degree turns like real metal layers)
        if s % 2 == 0 then
          px = px + (dungeonRand() - 0.5) * 200
        else
          py = py + (dungeonRand() - 0.5) * 200
        end
        px = math.max(0, math.min(width, px))
        py = math.max(0, math.min(height, py))
      end
      table.insert(decs, {
        type = "metal_trace",
        points = pts,
        layer = dungeonRandInt(1, 4),
        thickness = 2 + dungeonRandInt(0, 2),
      })
    end
    -- Vias (connections between layers)
    local viaCount = 5 + math.floor(intensity * 15)
    for i = 1, viaCount do
      table.insert(decs, {
        type = "via",
        x = dungeonRand() * width,
        y = dungeonRand() * height,
        size = 4 + dungeonRand() * 4,
      })
    end
    -- Logic gate symbols (AND, OR, NOT, XOR drawn as decorative elements)
    if intensity > 0.2 then
      local gateCount = math.floor(intensity * 6)
      local gateTypes = {"AND", "OR", "NOT", "XOR", "NAND", "NOR", "FF", "MUX"}
      for i = 1, gateCount do
        table.insert(decs, {
          type = "logic_gate",
          x = dungeonRand() * (width - 60) + 30,
          y = dungeonRand() * (height - 40) + 20,
          gateType = gateTypes[dungeonRandInt(1, #gateTypes)],
          size = 20 + dungeonRand() * 20,
        })
      end
    end
    -- Foreground electric fields (outside maze corridors, pulsing violet)
    if intensity > 0.3 then
      table.insert(fgDecs, {
        type = "cpu_field_overlay",
        intensity = intensity,
      })
    end

  elseif dungeonId == "synesthesia" then
    -- GPU die: shader core blocks, VRAM modules, data pipelines, prismatic effects
    -- Background: PCB-green die shot grid
    table.insert(decs, {
      type = "gpu_die_grid",
      cellSize = 60 + math.floor(intensity * 30),
    })
    -- Shader core blocks (rectangles with internal patterns)
    local coreCount = 2 + math.floor(intensity * 5)
    for i = 1, coreCount do
      table.insert(decs, {
        type = "shader_core",
        x = dungeonRand() * (width - 140) + 20,
        y = dungeonRand() * (height - 100) + 10,
        w = 80 + dungeonRand() * 120,
        h = 60 + dungeonRand() * 80,
        coreIdx = dungeonRandInt(1, 4),
        subCores = dungeonRandInt(4, 16),
        active = dungeonRand() < (0.3 + intensity * 0.6),
      })
    end
    -- VRAM modules
    local vramCount = 1 + math.floor(intensity * 2)
    for i = 1, vramCount do
      table.insert(decs, {
        type = "vram_module",
        x = dungeonRand() * (width - 100) + 20,
        y = dungeonRand() * (height - 50) + 10,
        w = 80 + dungeonRand() * 60,
        h = 30 + dungeonRand() * 30,
        label = ({"GDDR6X", "HBM3", "VRAM", "GDDR7", "HBM3E"})[dungeonRandInt(1, 5)],
      })
    end
    -- Streaming data pipelines (animated lines connecting components)
    local pipeCount = 3 + math.floor(intensity * 6)
    for i = 1, pipeCount do
      table.insert(decs, {
        type = "data_pipeline",
        x1 = dungeonRand() * width,
        y1 = dungeonRand() * height,
        x2 = dungeonRand() * width,
        y2 = dungeonRand() * height,
        colorIdx = dungeonRandInt(1, 4),
        speed = 100 + dungeonRand() * 200,
        dotCount = dungeonRandInt(3, 8),
      })
    end
    -- Foreground: prismatic refraction overlay (increasingly psychedelic)
    if intensity > 0.2 then
      table.insert(fgDecs, {
        type = "prism_overlay",
        intensity = intensity,
      })
    end
    -- Nvidia-style streaming geometry triangles
    if intensity > 0.3 then
      local triCount = math.floor(intensity * 8)
      for i = 1, triCount do
        table.insert(fgDecs, {
          type = "stream_triangle",
          x = dungeonRand() * width,
          y = dungeonRand() * height,
          size = 15 + dungeonRand() * 40,
          speed = 50 + dungeonRand() * 150,
          angle = dungeonRand() * math.pi * 2,
          colorIdx = dungeonRandInt(1, 7),
        })
      end
    end
  end

  return decs, fgDecs
end

-- ===================== PUBLIC API =====================

-- Check if a tile is inside a dungeon constellation
function M.isDungeonTile(tileX, tileY)
  local cId = constellation.getConstellationId(tileX, tileY)
  local cData = constellation.CONSTELLATIONS[cId]
  return cData and cData.isDungeon == true, cId
end

-- Initialize dungeon state for a tile
function M.init(tileX, tileY, width, height)
  local isDungeon, dungeonId = M.isDungeonTile(tileX, tileY)
  if not isDungeon then
    current.active = false
    current.walls = {}
    current.hazardZones = {}
    current.turrets = {}
    current.sentries = {}
    current.decorations = {}
    current.fgDecorations = {}
    return
  end

  current.active = true
  current.dungeonId = dungeonId
  current.tileX = tileX
  current.tileY = tileY
  current.intensity = calcIntensity(tileX, tileY, dungeonId)
  current.time = 0

  -- Generate maze walls
  current.walls = generateMaze(width, height, tileX, tileY, dungeonId, current.intensity)

  -- Generate hazard zones
  current.hazardZones = spawnHazardZones(width, height, current.walls, current.intensity, dungeonId)

  -- Generate enemies
  current.turrets = spawnTurrets(width, height, current.walls, current.intensity, dungeonId)
  current.sentries = spawnSentries(width, height, current.walls, current.intensity, dungeonId)

  -- Generate decorations
  current.decorations, current.fgDecorations = generateDecorations(width, height, current.intensity, dungeonId)
end

function M.isActive()
  return current.active
end

function M.getIntensity()
  return current.intensity
end

function M.getDungeonId()
  return current.dungeonId
end

-- ===================== COLLISION HELPERS =====================

function M.pointInWall(px, py, walls)
  walls = walls or current.walls
  for _, w in ipairs(walls) do
    if px >= w.x and px <= w.x + w.w and py >= w.y and py <= w.y + w.h then
      return true
    end
  end
  return false
end

-- Check and resolve ship collision with walls. Returns clamped x, y and whether hit occurred.
function M.resolveWallCollision(shipX, shipY, shipRadius)
  if not current.active then return shipX, shipY, false end

  local hit = false
  local sx, sy = shipX, shipY
  local r = shipRadius or 12

  for _, w in ipairs(current.walls) do
    -- Find closest point on wall rect to ship center
    local closestX = math.max(w.x, math.min(sx, w.x + w.w))
    local closestY = math.max(w.y, math.min(sy, w.y + w.h))
    local dx = sx - closestX
    local dy = sy - closestY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < r and dist > 0 then
      -- Push ship out
      local overlap = r - dist
      sx = sx + (dx / dist) * overlap
      sy = sy + (dy / dist) * overlap
      hit = true
    elseif dist == 0 then
      -- Ship center is inside wall — push to nearest edge
      local pushDirs = {
        {dx = w.x - r - sx, dy = 0},                  -- push left
        {dx = w.x + w.w + r - sx, dy = 0},             -- push right
        {dx = 0, dy = w.y - r - sy},                    -- push up
        {dx = 0, dy = w.y + w.h + r - sy},              -- push down
      }
      local best = pushDirs[1]
      local bestDist = math.abs(best.dx) + math.abs(best.dy)
      for i = 2, 4 do
        local d = math.abs(pushDirs[i].dx) + math.abs(pushDirs[i].dy)
        if d < bestDist then best = pushDirs[i]; bestDist = d end
      end
      sx = sx + best.dx
      sy = sy + best.dy
      hit = true
    end
  end

  return sx, sy, hit
end

-- Check if ship is in a hazard zone, return total damage per second
function M.getHazardDamage(shipX, shipY)
  if not current.active then return 0 end
  local totalDmg = 0
  for _, z in ipairs(current.hazardZones) do
    if z.active and shipX >= z.x and shipX <= z.x + z.w and shipY >= z.y and shipY <= z.y + z.h then
      totalDmg = totalDmg + z.damage
    end
  end
  return totalDmg
end

-- Get turret bullets (called by init.lua to spawn bullets)
function M.getTurretShots(shipX, shipY, dt)
  if not current.active then return {} end
  local shots = {}

  for _, t in ipairs(current.turrets) do
    if not t.dead then
      -- Aim at player
      local dx = shipX - t.x
      local dy = shipY - t.y
      t.angle = math.atan2(dy, dx)

      t.timer = t.timer - dt
      if t.timer <= 0 then
        t.timer = TURRET_SHOOT_INTERVAL * (0.8 + current.intensity * 0.4)
        local speed = 200 + current.intensity * 100
        table.insert(shots, {
          x = t.x,
          y = t.y,
          vx = math.cos(t.angle) * speed,
          vy = math.sin(t.angle) * speed,
          damage = 5 + math.floor(current.intensity * 5),
          dungeonBullet = true,
        })
      end
    end
  end

  return shots
end

-- ===================== UPDATE =====================

function M.update(dt, width, height, shipX, shipY)
  if not current.active then return end

  current.time = current.time + dt

  -- Update sentries
  for _, s in ipairs(current.sentries) do
    if not s.dead then
      s.x = s.x + s.vx * dt
      s.y = s.y + s.vy * dt

      -- Bounce off walls
      local newX, newY, hit = M.resolveWallCollision(s.x, s.y, s.size)
      if hit then
        -- Reverse direction on hit
        if newX ~= s.x then s.vx = -s.vx end
        if newY ~= s.y then s.vy = -s.vy end
        s.x = newX
        s.y = newY
      end

      -- Bounce off screen edges
      if s.x < s.size then s.x = s.size; s.vx = math.abs(s.vx) end
      if s.x > width - s.size then s.x = width - s.size; s.vx = -math.abs(s.vx) end
      if s.y < s.size then s.y = s.size; s.vy = math.abs(s.vy) end
      if s.y > height - s.size then s.y = height - s.size; s.vy = -math.abs(s.vy) end

      -- Patrol direction changes
      s.patrolTimer = s.patrolTimer - dt
      if s.patrolTimer <= 0 then
        s.patrolTimer = 2 + math.random() * 3
        local angle = math.random() * math.pi * 2
        s.vx = math.cos(angle) * SENTRY_SPEED
        s.vy = math.sin(angle) * SENTRY_SPEED
      end

      -- Approach player if close
      local pdx = shipX - s.x
      local pdy = shipY - s.y
      local pDist = math.sqrt(pdx * pdx + pdy * pdy)
      if pDist < 250 then
        local chaseStr = 0.3
        s.vx = s.vx + (pdx / pDist) * SENTRY_SPEED * chaseStr * dt
        s.vy = s.vy + (pdy / pDist) * SENTRY_SPEED * chaseStr * dt
        -- Clamp speed
        local spd = math.sqrt(s.vx * s.vx + s.vy * s.vy)
        if spd > SENTRY_SPEED * 1.5 then
          s.vx = s.vx / spd * SENTRY_SPEED * 1.5
          s.vy = s.vy / spd * SENTRY_SPEED * 1.5
        end
      end

      s.angle = math.atan2(s.vy, s.vx)

      -- Flash timer
      if s.flashTimer > 0 then s.flashTimer = s.flashTimer - dt end
    end
  end

  -- Update turret flash
  for _, t in ipairs(current.turrets) do
    if t.flashTimer > 0 then t.flashTimer = t.flashTimer - dt end
  end

  -- Update hazard zone timers
  for _, z in ipairs(current.hazardZones) do
    z.timer = z.timer + dt
  end
end

-- ===================== DAMAGE HANDLING =====================

-- Hit a turret. Returns true if destroyed.
function M.damageTurret(index, damage)
  local t = current.turrets[index]
  if not t or t.dead then return false end
  t.health = t.health - damage
  t.flashTimer = 0.15
  if t.health <= 0 then
    t.dead = true
    return true
  end
  return false
end

-- Hit a sentry. Returns true if destroyed.
function M.damageSentry(index, damage)
  local s = current.sentries[index]
  if not s or s.dead then return false end
  s.health = s.health - damage
  s.flashTimer = 0.15
  if s.health <= 0 then
    s.dead = true
    return true
  end
  return false
end

-- Check bullet collisions with dungeon enemies
-- Returns list of {type, index, x, y} for destroyed enemies
function M.checkBulletCollisions(bullets)
  if not current.active then return {} end
  local destroyed = {}

  for bIdx = #bullets, 1, -1 do
    local b = bullets[bIdx]
    if not b.dungeonBullet then -- Don't let dungeon bullets hit dungeon enemies
      -- Check turrets
      for tIdx, t in ipairs(current.turrets) do
        if not t.dead then
          local dx = b.x - t.x
          local dy = b.y - t.y
          if math.sqrt(dx*dx + dy*dy) < t.size + 4 then
            local killed = M.damageTurret(tIdx, 1)
            table.remove(bullets, bIdx)
            if killed then
              table.insert(destroyed, {type = "turret", index = tIdx, x = t.x, y = t.y})
            end
            break
          end
        end
      end

      -- Check sentries (only if bullet still exists)
      if bullets[bIdx] == b then
        for sIdx, s in ipairs(current.sentries) do
          if not s.dead then
            local dx = b.x - s.x
            local dy = b.y - s.y
            if math.sqrt(dx*dx + dy*dy) < s.size + 4 then
              local killed = M.damageSentry(sIdx, 1)
              table.remove(bullets, bIdx)
              if killed then
                table.insert(destroyed, {type = "sentry", index = sIdx, x = s.x, y = s.y})
              end
              break
            end
          end
        end
      end
    end
  end

  return destroyed
end

-- Check ship collision with sentries
-- Returns damage amount if collision
function M.checkShipCollision(shipX, shipY, shipRadius)
  if not current.active then return 0 end
  local totalDmg = 0
  local sr = shipRadius or 12

  for _, s in ipairs(current.sentries) do
    if not s.dead then
      local dx = shipX - s.x
      local dy = shipY - s.y
      if math.sqrt(dx*dx + dy*dy) < sr + s.size then
        totalDmg = totalDmg + 10
        s.dead = true
      end
    end
  end

  return totalDmg
end

-- ===================== DRAW =====================

-- Get themed wall color based on dungeon
local function getWallColor(dungeonId, intensity)
  if dungeonId == "megalith" then
    return {0.1, 0.2 + intensity * 0.2, 0.5 + intensity * 0.3, 0.9}
  elseif dungeonId == "dynamo" then
    return {0.5 + intensity * 0.3, 0.2, 0.05, 0.9}
  elseif dungeonId == "logician" then
    return {0.4 + intensity * 0.2, 0.35 + intensity * 0.2, 0.5 + intensity * 0.2, 0.9}
  elseif dungeonId == "synesthesia" then
    return {0.05, 0.3 + intensity * 0.3, 0.2 + intensity * 0.1, 0.9}
  end
  return WALL_COLOR
end

-- Draw background decorations (behind everything)
function M.drawBackground(width, height)
  if not current.active then return end

  local cData = constellation.CONSTELLATIONS[current.dungeonId]
  if not cData then return end
  local dec = cData.decoration
  local t = current.time
  local intensity = current.intensity

  for _, d in ipairs(current.decorations) do
    -- ===== MEGALITH decorations =====
    if d.type == "ram_grid" then
      local cellW = d.w / d.cols
      local cellH = d.h / d.rows
      for r = 0, d.rows - 1 do
        for c = 0, d.cols - 1 do
          local cx = d.x + c * cellW
          local cy = d.y + r * cellH
          local phase = math.sin(t * d.pulseSpeed + d.pulseOffset + r * 0.5 + c * 0.3)
          local active = (phase > 0 and math.abs(phase) > (1 - d.activeChance))
          if active then
            local ci = 3 + math.floor(intensity)
            ci = math.min(ci, #dec.cellColors)
            local cc = dec.cellColors[ci]
            local glow = 0.3 + phase * 0.4
            love.graphics.setColor(cc[1], cc[2], cc[3], glow)
            love.graphics.rectangle("fill", cx + 1, cy + 1, cellW - 2, cellH - 2)
          else
            local cc = dec.cellColors[1]
            love.graphics.setColor(cc[1], cc[2], cc[3], 0.2)
            love.graphics.rectangle("fill", cx + 1, cy + 1, cellW - 2, cellH - 2)
          end
          -- Cell border
          love.graphics.setColor(0.15, 0.25, 0.5, 0.3)
          love.graphics.rectangle("line", cx, cy, cellW, cellH)
        end
      end

    elseif d.type == "m2_chip" then
      -- Chip body
      love.graphics.setColor(dec.chipColor[1], dec.chipColor[2], dec.chipColor[3], 0.7)
      love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 3, 3)
      -- Chip border
      love.graphics.setColor(0.3, 0.3, 0.4, 0.6)
      love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 3, 3)
      -- Pins along bottom
      local pinSpacing = d.w / (d.pinCount + 1)
      for p = 1, d.pinCount do
        love.graphics.setColor(dec.pinColor[1], dec.pinColor[2], dec.pinColor[3], 0.6)
        love.graphics.rectangle("fill", d.x + p * pinSpacing - 2, d.y + d.h, 4, 8)
      end
      -- Label
      love.graphics.setColor(0.4, 0.5, 0.7, 0.5)
      love.graphics.printf(d.label, d.x, d.y + d.h * 0.35, d.w, "center")

    elseif d.type == "data_trace" then
      local tc = dec.traceColors[d.colorIdx]
      local pulse = math.sin(t * d.pulseSpeed) * 0.3 + 0.5
      love.graphics.setColor(tc[1], tc[2], tc[3], tc[4] * pulse)
      love.graphics.setLineWidth(d.thickness)
      if d.horizontal then
        love.graphics.line(d.x, d.y, d.x + d.length, d.y)
      else
        love.graphics.line(d.x, d.y, d.x, d.y + d.length)
      end
      love.graphics.setLineWidth(1)

    -- ===== DYNAMO decorations =====
    elseif d.type == "power_cable" then
      local cc = dec.cableColors[d.colorIdx]
      love.graphics.setColor(cc[1], cc[2], cc[3], cc[4])
      love.graphics.setLineWidth(d.thickness)
      for i = 1, #d.points - 1 do
        love.graphics.line(d.points[i].x, d.points[i].y, d.points[i+1].x, d.points[i+1].y)
      end
      love.graphics.setLineWidth(1)
      -- Sparks along cable
      if d.sparkChance > 0 and math.sin(t * 7 + d.points[1].x) > (1 - d.sparkChance) then
        local si = math.floor(t * 3) % (#d.points - 1) + 1
        local sp = d.points[si]
        local sc = dec.sparkColors[math.floor(t * 2) % #dec.sparkColors + 1]
        love.graphics.setColor(sc[1], sc[2], sc[3], 0.8)
        love.graphics.circle("fill", sp.x, sp.y, 3 + intensity * 4)
      end

    elseif d.type == "fan" then
      -- Hub
      love.graphics.setColor(dec.fanHubColor[1], dec.fanHubColor[2], dec.fanHubColor[3], 0.6)
      love.graphics.circle("fill", d.x, d.y, d.radius * 0.2)
      -- Blades
      local baseAngle = t * d.speed + d.angleOffset
      for b = 0, d.blades - 1 do
        local bAngle = baseAngle + (b / d.blades) * math.pi * 2
        local bx1 = d.x + math.cos(bAngle) * d.radius * 0.15
        local by1 = d.y + math.sin(bAngle) * d.radius * 0.15
        local bx2 = d.x + math.cos(bAngle + 0.3) * d.radius
        local by2 = d.y + math.sin(bAngle + 0.3) * d.radius
        local bx3 = d.x + math.cos(bAngle - 0.1) * d.radius * 0.9
        local by3 = d.y + math.sin(bAngle - 0.1) * d.radius * 0.9
        love.graphics.setColor(dec.fanColor[1], dec.fanColor[2], dec.fanColor[3], 0.5)
        love.graphics.polygon("fill", bx1, by1, bx2, by2, bx3, by3)
      end
      -- Outer ring
      love.graphics.setColor(0.3, 0.3, 0.35, 0.4)
      love.graphics.circle("line", d.x, d.y, d.radius)

    elseif d.type == "transformer" then
      -- Core
      love.graphics.setColor(dec.coreColor[1], dec.coreColor[2], dec.coreColor[3], 0.6)
      love.graphics.rectangle("fill", d.x - d.w/2, d.y - d.h/2, d.w, d.h, 4, 4)
      -- Coil windings
      love.graphics.setColor(dec.coilColor[1], dec.coilColor[2], dec.coilColor[3], 0.5)
      for ci = 0, d.coilTurns - 1 do
        local cy = d.y - d.h/2 + (ci + 0.5) / d.coilTurns * d.h
        love.graphics.arc("line", "open", d.x - d.w/2, cy, d.w * 0.3, -math.pi/2, math.pi/2)
        love.graphics.arc("line", "open", d.x + d.w/2, cy, d.w * 0.3, math.pi/2, math.pi * 1.5)
      end

    -- ===== LOGICIAN decorations =====
    elseif d.type == "substrate_grid" then
      local cs = d.cellSize
      love.graphics.setColor(dec.substrateColor[1], dec.substrateColor[2], dec.substrateColor[3], 0.3)
      for gx = 0, width, cs do
        love.graphics.line(gx, 0, gx, height)
      end
      for gy = 0, height, cs do
        love.graphics.line(0, gy, width, gy)
      end

    elseif d.type == "metal_trace" then
      local mc = dec.metalColors[d.layer]
      love.graphics.setColor(mc[1], mc[2], mc[3], mc[4])
      love.graphics.setLineWidth(d.thickness)
      for i = 1, #d.points - 1 do
        love.graphics.line(d.points[i].x, d.points[i].y, d.points[i+1].x, d.points[i+1].y)
      end
      love.graphics.setLineWidth(1)

    elseif d.type == "via" then
      love.graphics.setColor(dec.viaColor[1], dec.viaColor[2], dec.viaColor[3], 0.6)
      love.graphics.circle("fill", d.x, d.y, d.size)
      love.graphics.setColor(dec.viaColor[1] * 0.7, dec.viaColor[2] * 0.7, dec.viaColor[3] * 0.7, 0.4)
      love.graphics.circle("line", d.x, d.y, d.size + 2)

    elseif d.type == "logic_gate" then
      local gc = dec.gateColor
      love.graphics.setColor(gc[1], gc[2], gc[3], gc[4])
      love.graphics.printf(d.gateType, d.x - d.size/2, d.y - d.size * 0.3, d.size, "center")

    -- ===== SYNESTHESIA decorations =====
    elseif d.type == "gpu_die_grid" then
      local cs = d.cellSize
      love.graphics.setColor(dec.dieBorderColor[1], dec.dieBorderColor[2], dec.dieBorderColor[3], 0.2)
      for gx = 0, width, cs do
        love.graphics.line(gx, 0, gx, height)
      end
      for gy = 0, height, cs do
        love.graphics.line(0, gy, width, gy)
      end

    elseif d.type == "shader_core" then
      local cc = dec.coreColors[d.coreIdx]
      -- Core block background
      local alpha = d.active and 0.4 or 0.15
      love.graphics.setColor(cc[1], cc[2], cc[3], alpha)
      love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 2, 2)
      -- Sub-core grid
      local cols = math.ceil(math.sqrt(d.subCores))
      local rows = math.ceil(d.subCores / cols)
      local scW = d.w / cols
      local scH = d.h / rows
      for sr = 0, rows - 1 do
        for sc = 0, cols - 1 do
          if sr * cols + sc < d.subCores then
            local phase = math.sin(t * 2 + sr * 0.7 + sc * 0.5)
            local subAlpha = d.active and (0.2 + phase * 0.3) or 0.05
            love.graphics.setColor(cc[1] * 1.3, cc[2] * 1.3, cc[3] * 1.3, subAlpha)
            love.graphics.rectangle("fill", d.x + sc * scW + 1, d.y + sr * scH + 1, scW - 2, scH - 2)
          end
        end
      end
      -- Border
      love.graphics.setColor(cc[1], cc[2], cc[3], 0.6)
      love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 2, 2)

    elseif d.type == "vram_module" then
      -- Module body
      love.graphics.setColor(dec.vramColor[1], dec.vramColor[2], dec.vramColor[3], 0.6)
      love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 2, 2)
      love.graphics.setColor(dec.vramLabelColor[1], dec.vramLabelColor[2], dec.vramLabelColor[3], 0.5)
      love.graphics.printf(d.label, d.x, d.y + d.h * 0.25, d.w, "center")
      love.graphics.setColor(0.2, 0.4, 0.3, 0.5)
      love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 2, 2)

    elseif d.type == "data_pipeline" then
      -- Line connecting two points
      local pc = dec.pipelineColors[d.colorIdx]
      love.graphics.setColor(pc[1], pc[2], pc[3], 0.2)
      love.graphics.line(d.x1, d.y1, d.x2, d.y2)
      -- Animated dots moving along the line
      for dot = 0, d.dotCount - 1 do
        local progress = ((t * d.speed / 400 + dot / d.dotCount) % 1)
        local dx = d.x1 + (d.x2 - d.x1) * progress
        local dy = d.y1 + (d.y2 - d.y1) * progress
        love.graphics.setColor(pc[1], pc[2], pc[3], 0.6)
        love.graphics.circle("fill", dx, dy, 2 + intensity * 2)
      end
    end
  end
end

-- Draw maze walls
function M.drawWalls(width, height)
  if not current.active then return end

  local wc = getWallColor(current.dungeonId, current.intensity)
  local cData = constellation.CONSTELLATIONS[current.dungeonId]
  local dec = cData and cData.decoration

  for _, w in ipairs(current.walls) do
    -- Main wall
    love.graphics.setColor(wc[1], wc[2], wc[3], wc[4])
    love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

    -- Themed wall detail
    if current.dungeonId == "megalith" then
      -- Circuit trace pattern on walls
      love.graphics.setColor(0.2, 0.4, 0.8, 0.3)
      if w.w > w.h then -- horizontal wall
        love.graphics.line(w.x + 4, w.y + w.h/2, w.x + w.w - 4, w.y + w.h/2)
      else -- vertical wall
        love.graphics.line(w.x + w.w/2, w.y + 4, w.x + w.w/2, w.y + w.h - 4)
      end
    elseif current.dungeonId == "dynamo" then
      -- Warning stripes
      local stripeCount = math.max(1, math.floor((w.w > w.h and w.w or w.h) / 20))
      for si = 0, stripeCount - 1 do
        if si % 2 == 0 then
          love.graphics.setColor(0.9, 0.7, 0.0, 0.2)
          if w.w > w.h then
            love.graphics.rectangle("fill", w.x + si * 20, w.y, 10, w.h)
          else
            love.graphics.rectangle("fill", w.x, w.y + si * 20, w.w, 10)
          end
        end
      end
    elseif current.dungeonId == "logician" then
      -- Metal sheen gradient
      love.graphics.setColor(0.8, 0.75, 0.6, 0.15)
      love.graphics.rectangle("fill", w.x + 1, w.y + 1, w.w - 2, (w.h > 4 and w.h/3 or w.h - 2))
    elseif current.dungeonId == "synesthesia" then
      -- Green PCB trace on wall edges
      love.graphics.setColor(0.0, 0.6, 0.3, 0.3)
      love.graphics.rectangle("line", w.x + 1, w.y + 1, w.w - 2, w.h - 2)
    end
  end
end

-- Draw hazard zones
function M.drawHazardZones(width, height)
  if not current.active then return end

  for _, z in ipairs(current.hazardZones) do
    local pulse = math.sin(current.time * 3 + z.pulsePhase) * 0.15 + 0.25

    if z.type == "data_stream" then
      love.graphics.setColor(0.1, 0.3, 0.8, pulse)
      love.graphics.rectangle("fill", z.x, z.y, z.w, z.h)
      -- Streaming data lines
      for i = 0, 4 do
        local yOff = ((current.time * 80 + i * z.h / 5) % z.h)
        love.graphics.setColor(0.3, 0.6, 1, pulse * 1.5)
        love.graphics.line(z.x, z.y + yOff, z.x + z.w, z.y + yOff)
      end
    elseif z.type == "heat_vent" then
      love.graphics.setColor(0.8, 0.3, 0.0, pulse)
      love.graphics.rectangle("fill", z.x, z.y, z.w, z.h)
      -- Rising heat waves
      for i = 0, 3 do
        local yOff = z.h - ((current.time * 50 + i * z.h / 4) % z.h)
        local wave = math.sin(current.time * 4 + i) * 10
        love.graphics.setColor(1, 0.6, 0.1, pulse * 0.8)
        love.graphics.line(z.x + wave, z.y + yOff, z.x + z.w + wave, z.y + yOff)
      end
    elseif z.type == "electric_field" then
      love.graphics.setColor(0.5, 0.2, 0.8, pulse)
      love.graphics.rectangle("fill", z.x, z.y, z.w, z.h)
      -- Crackling energy lines
      for i = 0, 2 do
        local x1 = z.x + math.random() * z.w
        local y1 = z.y + math.random() * z.h
        local x2 = x1 + (math.random() - 0.5) * 40
        local y2 = y1 + (math.random() - 0.5) * 40
        love.graphics.setColor(0.8, 0.4, 1, pulse * 2)
        love.graphics.line(x1, y1, x2, y2)
      end
    elseif z.type == "shader_beam" then
      -- Prismatic beam zone
      local hue = (current.time * 0.5 + z.pulsePhase) % 1
      local r, g, b = M.hsvToRgb(hue, 0.8, 0.9)
      love.graphics.setColor(r, g, b, pulse * 0.6)
      love.graphics.rectangle("fill", z.x, z.y, z.w, z.h)
    end

    -- Border
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.rectangle("line", z.x, z.y, z.w, z.h)
  end
end

-- Draw enemies (turrets and sentries)
function M.drawEnemies(width, height)
  if not current.active then return end
  local t = current.time

  -- Draw turrets
  for _, turret in ipairs(current.turrets) do
    if not turret.dead then
      local flash = turret.flashTimer > 0

      -- Base
      if flash then
        love.graphics.setColor(1, 1, 1, 0.9)
      else
        if turret.dungeonId == "megalith" then
          love.graphics.setColor(0.2, 0.3, 0.7, 0.9)
        elseif turret.dungeonId == "dynamo" then
          love.graphics.setColor(0.7, 0.3, 0.1, 0.9)
        elseif turret.dungeonId == "logician" then
          love.graphics.setColor(0.5, 0.3, 0.7, 0.9)
        elseif turret.dungeonId == "synesthesia" then
          love.graphics.setColor(0.1, 0.6, 0.4, 0.9)
        else
          love.graphics.setColor(0.5, 0.5, 0.5, 0.9)
        end
      end
      love.graphics.circle("fill", turret.x, turret.y, turret.size)

      -- Turret barrel
      local bx = turret.x + math.cos(turret.angle) * turret.size * 1.3
      local by = turret.y + math.sin(turret.angle) * turret.size * 1.3
      love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
      love.graphics.setLineWidth(3)
      love.graphics.line(turret.x, turret.y, bx, by)
      love.graphics.setLineWidth(1)

      -- Health bar
      if turret.health < turret.maxHealth then
        local barW = turret.size * 2
        local barH = 3
        local barX = turret.x - barW / 2
        local barY = turret.y - turret.size - 8
        love.graphics.setColor(0.3, 0.3, 0.3, 0.7)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        love.graphics.setColor(0, 1, 0.3, 0.9)
        love.graphics.rectangle("fill", barX, barY, barW * turret.health / turret.maxHealth, barH)
      end
    end
  end

  -- Draw sentries
  for _, sentry in ipairs(current.sentries) do
    if not sentry.dead then
      local flash = sentry.flashTimer > 0

      if flash then
        love.graphics.setColor(1, 1, 1, 0.9)
      else
        if sentry.dungeonId == "megalith" then
          love.graphics.setColor(0.3, 0.5, 0.9, 0.9)
        elseif sentry.dungeonId == "dynamo" then
          love.graphics.setColor(0.9, 0.5, 0.1, 0.9)
        elseif sentry.dungeonId == "logician" then
          love.graphics.setColor(0.6, 0.4, 0.9, 0.9)
        elseif sentry.dungeonId == "synesthesia" then
          love.graphics.setColor(0.2, 0.8, 0.5, 0.9)
        else
          love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
        end
      end

      -- Diamond shape
      local s = sentry.size
      love.graphics.polygon("fill",
        sentry.x, sentry.y - s,
        sentry.x + s, sentry.y,
        sentry.x, sentry.y + s,
        sentry.x - s, sentry.y)

      -- Direction indicator
      local nx = math.cos(sentry.angle) * s * 0.6
      local ny = math.sin(sentry.angle) * s * 0.6
      love.graphics.setColor(1, 1, 1, 0.5)
      love.graphics.circle("fill", sentry.x + nx, sentry.y + ny, 3)

      -- Health bar
      if sentry.health < sentry.maxHealth then
        local barW = sentry.size * 2
        local barH = 3
        local barX = sentry.x - barW / 2
        local barY = sentry.y - sentry.size - 8
        love.graphics.setColor(0.3, 0.3, 0.3, 0.7)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        love.graphics.setColor(0, 1, 0.3, 0.9)
        love.graphics.rectangle("fill", barX, barY, barW * sentry.health / sentry.maxHealth, barH)
      end
    end
  end
end

-- Draw foreground decorations (on top of game elements)
function M.drawForeground(width, height)
  if not current.active then return end

  local cData = constellation.CONSTELLATIONS[current.dungeonId]
  if not cData then return end
  local dec = cData.decoration
  local t = current.time
  local intensity = current.intensity

  for _, d in ipairs(current.fgDecorations) do
    if d.type == "nand_array" then
      -- Glowing NAND cell grid (megalith, foreground overlay)
      local cellSize = math.max(6, d.w / math.sqrt(d.cells))
      local cols = math.floor(d.w / cellSize)
      local rows = math.ceil(d.cells / cols)
      for r = 0, rows - 1 do
        for c = 0, cols - 1 do
          local phase = math.sin(t * 1.5 + r * 0.8 + c * 0.6)
          local glow = math.max(0, phase) * d.glowIntensity * 0.3
          local hue = (t * 0.1 + (r + c) * 0.05) % 1
          local cr, cg, cb = M.hsvToRgb(hue, 0.6 * d.glowIntensity, 0.8)
          love.graphics.setColor(cr, cg, cb, glow)
          love.graphics.rectangle("fill", d.x + c * cellSize, d.y + r * cellSize, cellSize - 1, cellSize - 1)
        end
      end

    elseif d.type == "heat_shimmer" then
      -- Full-screen heat distortion overlay (dynamo)
      for i = 0, 5 do
        local yBase = (t * 30 + i * height / 6) % height
        local alpha = d.intensity * 0.08
        love.graphics.setColor(1, 0.5, 0.1, alpha)
        local pts = {}
        for x = 0, width, 20 do
          table.insert(pts, x)
          table.insert(pts, yBase + math.sin(x * 0.02 + t * 2) * 8 * d.intensity)
        end
        if #pts >= 4 then
          love.graphics.setLineWidth(2)
          love.graphics.line(pts)
          love.graphics.setLineWidth(1)
        end
      end

    elseif d.type == "electric_arc" then
      -- Flickering electric arc between two points (dynamo)
      local flicker = math.sin(t * d.flickerSpeed) > 0.2
      if flicker then
        local sc = dec.sparkColors[d.colorIdx]
        love.graphics.setColor(sc[1], sc[2], sc[3], 0.4 + intensity * 0.3)
        love.graphics.setLineWidth(1 + intensity * 2)
        -- Jagged line
        local segs = 8
        local pts = {d.x1, d.y1}
        for s = 1, segs - 1 do
          local frac = s / segs
          local mx = d.x1 + (d.x2 - d.x1) * frac + (math.random() - 0.5) * 30
          local my = d.y1 + (d.y2 - d.y1) * frac + (math.random() - 0.5) * 30
          table.insert(pts, mx)
          table.insert(pts, my)
        end
        table.insert(pts, d.x2)
        table.insert(pts, d.y2)
        love.graphics.line(pts)
        love.graphics.setLineWidth(1)
      end

    elseif d.type == "cpu_field_overlay" then
      -- Pulsing electric field overlay outside maze corridors (logician)
      local fieldAlpha = d.intensity * 0.06 * (math.sin(t * 1.5) * 0.5 + 0.5)
      local fc = dec.fieldColors[1]
      love.graphics.setColor(fc[1], fc[2], fc[3], fieldAlpha)
      love.graphics.rectangle("fill", 0, 0, width, height)

    elseif d.type == "prism_overlay" then
      -- Prismatic color sweep overlay (synesthesia)
      local bandCount = 3 + math.floor(d.intensity * 5)
      for i = 0, bandCount - 1 do
        local hue = (t * 0.15 + i / bandCount) % 1
        local cr, cg, cb = M.hsvToRgb(hue, 0.9, 1.0)
        local yPos = (t * 40 + i * height / bandCount) % height
        love.graphics.setColor(cr, cg, cb, d.intensity * 0.06)
        love.graphics.rectangle("fill", 0, yPos, width, height / bandCount * 0.5)
      end

    elseif d.type == "stream_triangle" then
      -- Nvidia-style streaming geometry triangles (synesthesia)
      local cx = (d.x + math.cos(d.angle) * d.speed * t) % width
      local cy = (d.y + math.sin(d.angle) * d.speed * t) % height
      local pc = dec.prismColors[d.colorIdx]
      local alpha = 0.15 + intensity * 0.2
      love.graphics.setColor(pc[1], pc[2], pc[3], alpha)
      local s = d.size
      love.graphics.polygon("line",
        cx, cy - s,
        cx + s * 0.866, cy + s * 0.5,
        cx - s * 0.866, cy + s * 0.5)
    end
  end
end

-- ===================== UTILITY =====================

-- HSV to RGB conversion for prismatic effects
function M.hsvToRgb(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local tt = v * (1 - (1 - f) * s)
  i = i % 6

  if i == 0 then return v, tt, p
  elseif i == 1 then return q, v, p
  elseif i == 2 then return p, v, tt
  elseif i == 3 then return p, q, v
  elseif i == 4 then return tt, p, v
  else return v, p, q
  end
end

-- Get walls for external collision checking
function M.getWalls()
  return current.walls
end

-- Get all living enemies for external systems
function M.getEnemies()
  local enemies = {}
  for i, t in ipairs(current.turrets) do
    if not t.dead then
      table.insert(enemies, {type = "turret", index = i, x = t.x, y = t.y, size = t.size})
    end
  end
  for i, s in ipairs(current.sentries) do
    if not s.dead then
      table.insert(enemies, {type = "sentry", index = i, x = s.x, y = s.y, size = s.size})
    end
  end
  return enemies
end

return M
