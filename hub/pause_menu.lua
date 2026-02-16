local M = {}

local selectedIndex = 1
local fonts = {}

-- Sub-menu state
local subMenu = nil          -- nil = main pause, "options" = options sub-menu, "enter_code" = text input, "warp_list" = omnia warp, "world_map" = world map
local optionsIndex = 1
local warpIndex = 1
local warpScrollOffset = 0
local codeInput = ""
local codeMessage = nil      -- Feedback message after entering code
local codeMessageTimer = 0
local omniaActivated = false  -- Persists for the session

-- World Map state
local worldMapCursor = {x = 0, y = 0}  -- Cursor position on the world map grid
local worldMapMessage = nil             -- Status message (e.g. "Out of radio range")
local worldMapMessageTimer = 0
local worldMapScroll = {x = 0, y = 0}  -- Scroll offset for the view

local fadeState = {
  active = false,
  alpha = 0,
  fadingOut = false,
  fadingIn = false,
  callback = nil
}

M.onResume = nil
M.onOptions = nil
M.onSave = nil
M.onExitToMenu = nil
M.returnToShip = nil      -- Set when arriving from space/asteroids
M.returnToStation = nil   -- Set when arriving from planet map
M.onWarpTo = nil           -- Callback: function(warpEntry) to teleport player
M.onFastTravel = nil       -- Callback: function(tileX, tileY) fast travel to tile

local function buildMenuItems()
  if M.returnToShip then
    return {"Resume", "World Map", "Options", "Save", "Return to Ship", "Exit to Main Menu", "Exit to Desktop"}
  elseif M.returnToStation then
    return {"Resume", "Options", "Save", "Return to Planet Map", "Exit to Main Menu", "Exit to Desktop"}
  else
    return {"Resume", "Options", "Save", "Exit to Main Menu", "Exit to Desktop"}
  end
end

-- Options sub-menu items
local function buildOptionsItems()
  return {"Enter Code", "Back"}
end

-- Build the full warp list for omnia cheat
local function buildWarpList()
  local list = {}

  -- ─── Starfox Stages ─────────────────────────
  table.insert(list, {type = "header", label = "═══ STARFOX STAGES ═══"})
  local starfoxLevels = {
    {id = 1,  name = "Newton's Nebula"},
    {id = 2,  name = "Asteroid Alley"},
    {id = 4,  name = "Fortuna"},
    {id = 8,  name = "Vacuous Voidway"},
    {id = 19, name = "Warden (Boss)"},
    {id = 5,  name = "Katina"},
    {id = 11, name = "Titania"},
    {id = 7,  name = "Solar"},
    {id = 10, name = "Macbeth"},
    {id = 13, name = "Bolse"},
    {id = 20, name = "Sentinel (Boss)"},
    {id = 3,  name = "Sector Y"},
    {id = 6,  name = "Aquas"},
    {id = 9,  name = "Zoness"},
    {id = 12, name = "Sector Z"},
    {id = 15, name = "Fichina"},
    {id = 14, name = "Area 6"},
    {id = 16, name = "Outer"},
    {id = 17, name = "Venom II"},
    {id = 18, name = "Venom"},
  }
  for _, lvl in ipairs(starfoxLevels) do
    table.insert(list, {type = "starfox", label = lvl.name, levelId = lvl.id})
  end

  -- ─── Starfox Raids ──────────────────────────
  table.insert(list, {type = "header", label = "═══ STARFOX RAIDS ═══"})
  local starfoxRaids = {
    {id = 21, name = "Synesthesia Installation"},
    {id = 22, name = "Megalith of Memories"},
    {id = 23, name = "Distant Dynamo"},
    {id = 25, name = "Logician's Lament"},
  }
  for _, raid in ipairs(starfoxRaids) do
    table.insert(list, {type = "starfox", label = raid.name, levelId = raid.id})
  end

  -- ─── Hometown Station (Hub) Floors ──────────
  table.insert(list, {type = "header", label = "═══ HOMETOWN STATION ═══"})
  local hometownFloors = {
    {id = 0, name = "Sub-Level Zero"},
    {id = 1, name = "Cargo Bay"},
    {id = 2, name = "Commerce Deck"},
    {id = 3, name = "Residential Deck"},
    {id = 4, name = "Flight Deck"},
    {id = 5, name = "Lookout"},
    {id = 6, name = "Apex Tower"},
  }
  for _, f in ipairs(hometownFloors) do
    table.insert(list, {type = "hub_floor", label = "Floor " .. f.id .. ": " .. f.name, hubType = "hometown", floorId = f.id})
  end

  -- ─── Mixia Floors ───────────────────────────
  table.insert(list, {type = "header", label = "═══ MIXIA ═══"})
  local mixiaFloors = {
    {id = 0, name = "Ancient Citadel"},
    {id = 1, name = "The Surface"},
    {id = 2, name = "Industrial Zone"},
    {id = 3, name = "Commerce Level"},
    {id = 4, name = "Upper District"},
    {id = 5, name = "Skyline Terrace"},
  }
  for _, f in ipairs(mixiaFloors) do
    table.insert(list, {type = "hub_floor", label = "Floor " .. f.id .. ": " .. f.name, hubType = "mixia", floorId = f.id})
  end

  -- ─── Leucadia ───────────────────────────────
  table.insert(list, {type = "header", label = "═══ LEUCADIA ═══"})
  table.insert(list, {type = "hub_area", label = "Leucadia (Beach Town)", hubType = "leucadia"})

  -- ─── The Singularity ────────────────────────
  table.insert(list, {type = "header", label = "═══ THE SINGULARITY ═══"})
  table.insert(list, {type = "hub_area", label = "The Singularity (Black Hole Station)", hubType = "singularity"})

  -- ─── Constellations (Asteroids) ─────────────
  table.insert(list, {type = "header", label = "═══ CONSTELLATIONS ═══"})
  local constellations = {
    {name = "The Nebula",    tileX = 0,   tileY = 0},
    {name = "Gargantua",     tileX = 7,   tileY = 0},
    {name = "Pleiades",      tileX = -7,  tileY = 0},
    {name = "Oort Cloud",    tileX = 0,   tileY = 7},
    {name = "Messier",       tileX = 0,   tileY = -7},
    {name = "Vela",          tileX = 7,   tileY = 7},
    {name = "Pandora",       tileX = -7,  tileY = 7},
    {name = "Orion",         tileX = -7,  tileY = -7},
    {name = "Andromeda",     tileX = 7,   tileY = -7},
  }
  for _, c in ipairs(constellations) do
    table.insert(list, {type = "constellation", label = c.name, tileX = c.tileX, tileY = c.tileY})
  end

  return list
end

local warpList = {}

function M.load()
  fonts.title = love.graphics.newFont("fonts/Exo2-Regular.ttf", 32)
  fonts.menu = love.graphics.newFont("fonts/Exo2-Regular.ttf", 24)
  fonts.small = love.graphics.newFont("fonts/Exo2-Regular.ttf", 14)
  fonts.code = love.graphics.newFont("fonts/Exo2-Regular.ttf", 20)
  selectedIndex = 1
  subMenu = nil
  optionsIndex = 1
  codeInput = ""
  codeMessage = nil
  fadeState.active = false
  fadeState.alpha = 0
  fadeState.fadingOut = false
  fadeState.fadingIn = false
  fadeState.callback = nil
end

function M.update(dt)
  if codeMessageTimer > 0 then
    codeMessageTimer = codeMessageTimer - dt
    if codeMessageTimer <= 0 then
      codeMessage = nil
    end
  end
  if worldMapMessageTimer > 0 then
    worldMapMessageTimer = worldMapMessageTimer - dt
    if worldMapMessageTimer <= 0 then
      worldMapMessage = nil
    end
  end
  
  -- Update fade animation
  if fadeState.active then
    if fadeState.fadingOut then
      fadeState.alpha = math.min(1.0, fadeState.alpha + dt * 2.0)
      if fadeState.alpha >= 1.0 and fadeState.callback then
        local cb = fadeState.callback
        fadeState.callback = nil
        fadeState.fadingOut = false
        fadeState.fadingIn = true
        cb()
      end
    elseif fadeState.fadingIn then
      fadeState.alpha = math.max(0, fadeState.alpha - dt * 2.0)
      if fadeState.alpha <= 0 then
        fadeState.active = false
        fadeState.fadingIn = false
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

local function drawMainPause()
  local menuItems = buildMenuItems()

  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("PAUSED", 0, 200, 1366, "center")

  love.graphics.setFont(fonts.menu)
  local startY = 320
  local itemHeight = 50

  for i, item in ipairs(menuItems) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. item .. " <", 0, startY + (i - 1) * itemHeight, 1366, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(item, 0, startY + (i - 1) * itemHeight, 1366, "center")
    end
  end

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 650, 1366, "center")
end

local function drawOptionsMenu()
  local items = buildOptionsItems()

  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("OPTIONS", 0, 200, 1366, "center")

  love.graphics.setFont(fonts.menu)
  local startY = 340
  local itemHeight = 50

  for i, item in ipairs(items) do
    if i == optionsIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. item .. " <", 0, startY + (i - 1) * itemHeight, 1366, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(item, 0, startY + (i - 1) * itemHeight, 1366, "center")
    end
  end

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Back", 0, 650, 1366, "center")
end

local function drawEnterCode()
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("ENTER CODE", 0, 200, 1366, "center")

  -- Input box
  local boxW = 400
  local boxH = 50
  local boxX = (1366 - boxW) / 2
  local boxY = 350

  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)
  love.graphics.setColor(0.4, 0.6, 1)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)

  love.graphics.setFont(fonts.menu)
  love.graphics.setColor(1, 1, 1)
  local displayText = codeInput .. "_"
  love.graphics.printf(displayText, boxX + 10, boxY + 10, boxW - 20, "center")

  -- Message
  if codeMessage then
    love.graphics.setFont(fonts.code)
    if codeMessage == "Code Accepted!" then
      love.graphics.setColor(0.2, 1, 0.3)
    else
      love.graphics.setColor(1, 0.3, 0.3)
    end
    love.graphics.printf(codeMessage, 0, boxY + 70, 1366, "center")
  end

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Type a code and press ENTER | ESC: Back", 0, 650, 1366, "center")
end

local function drawWarpList()
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 0.85, 0.2)
  love.graphics.printf("OMNIA — WARP ANYWHERE", 0, 30, 1366, "center")

  local startY = 80
  local itemHeight = 28
  local maxVisible = 22
  local listFont = fonts.code or fonts.menu

  love.graphics.setFont(listFont)

  -- Count selectable items
  local selectableItems = {}
  for i, entry in ipairs(warpList) do
    if entry.type ~= "header" then
      table.insert(selectableItems, i)
    end
  end

  -- Ensure scroll keeps selected item visible
  local selectedListIndex = selectableItems[warpIndex] or 1
  if selectedListIndex - warpScrollOffset > maxVisible then
    warpScrollOffset = selectedListIndex - maxVisible
  elseif selectedListIndex - warpScrollOffset < 1 then
    warpScrollOffset = selectedListIndex - 1
  end

  local drawn = 0
  for i = warpScrollOffset + 1, #warpList do
    if drawn >= maxVisible then break end

    local entry = warpList[i]
    local y = startY + drawn * itemHeight

    if entry.type == "header" then
      love.graphics.setColor(0.4, 0.6, 1)
      love.graphics.printf(entry.label, 200, y, 966, "center")
    else
      -- Find which selectable index this is
      local isSelected = false
      for si, li in ipairs(selectableItems) do
        if li == i and si == warpIndex then
          isSelected = true
          break
        end
      end

      if isSelected then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> " .. entry.label, 250, y, 866, "left")
      else
        love.graphics.setColor(0.75, 0.75, 0.75)
        love.graphics.printf("  " .. entry.label, 250, y, 866, "left")
      end
    end

    drawn = drawn + 1
  end

  -- Scroll indicators
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  if warpScrollOffset > 0 then
    love.graphics.printf("▲ More above", 0, startY - 18, 1366, "center")
  end
  if warpScrollOffset + maxVisible < #warpList then
    love.graphics.printf("▼ More below", 0, startY + maxVisible * itemHeight + 4, 1366, "center")
  end

  love.graphics.printf("Arrows: Navigate | ENTER: Warp | ESC: Back", 0, 720, 1366, "center")
end

-- ═══════════════════════════════════════
-- WORLD MAP
-- ═══════════════════════════════════════

local function drawWorldMap()
  local ok1, worldmap = pcall(require, "asteroids.worldmap")
  local ok2, constellation = pcall(require, "asteroids.constellation")
  if not ok1 or not ok2 then return end

  local WORLD_MIN = -31
  local WORLD_MAX = 31
  local WORLD_SIZE = 63  -- 63x63 tiles

  -- Map display area
  local screenW = 1366
  local screenH = 768
  local mapPadding = 40
  local headerHeight = 50
  local footerHeight = 50

  -- Calculate cell size to fit the full 63x63 grid
  local availW = screenW - mapPadding * 2
  local availH = screenH - headerHeight - footerHeight - mapPadding
  local cellSize = math.floor(math.min(availW / WORLD_SIZE, availH / WORLD_SIZE))
  cellSize = math.max(cellSize, 8) -- minimum cell size
  local mapSize = cellSize * WORLD_SIZE

  local mapX = math.floor((screenW - mapSize) / 2)
  local mapY = headerHeight + 10

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.7, 1)
  love.graphics.printf("WORLD MAP", 0, 10, screenW, "center")

  -- Background
  love.graphics.setColor(0.05, 0.05, 0.08, 0.95)
  love.graphics.rectangle("fill", mapX - 2, mapY - 2, mapSize + 4, mapSize + 4)

  -- Player position
  local playerTX = worldmap.tileX
  local playerTY = worldmap.tileY

  -- Draw all tiles
  for ty = WORLD_MAX, WORLD_MIN, -1 do
    for tx = WORLD_MIN, WORLD_MAX do
      local drawCellX = mapX + (tx - WORLD_MIN) * cellSize
      local drawCellY = mapY + (WORLD_MAX - ty) * cellSize

      local discovered = worldmap.isDiscovered(tx, ty)
      local tile = worldmap.getTile(tx, ty)
      local zone = constellation.getZone(tx, ty)

      if discovered then
        -- Discovered tile: show full color
        if tile.type == worldmap.TILE_STATION then
          love.graphics.setColor(0.3, 0.6, 0.9, 0.9)
        elseif tile.type == worldmap.TILE_PORTAL then
          love.graphics.setColor(tile.color[1] * 0.8, tile.color[2] * 0.8, tile.color[3] * 0.8, 0.9)
        else
          -- Color by zone
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
            love.graphics.setColor(0.12, 0.12, 0.18, 0.5)
          else -- outer space
            love.graphics.setColor(0.08, 0.08, 0.1, 0.4)
          end
        end
        love.graphics.rectangle("fill", drawCellX, drawCellY, cellSize - 1, cellSize - 1)
      else
        -- Undiscovered: very faint zone outline only
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

  -- Draw constellation boundaries (7x7 grid lines)
  love.graphics.setColor(0.3, 0.3, 0.4, 0.4)
  for i = 0, 9 do
    local lineX = mapX + i * 7 * cellSize
    love.graphics.line(lineX, mapY, lineX, mapY + mapSize)
    local lineY = mapY + i * 7 * cellSize
    love.graphics.line(mapX, lineY, mapX + mapSize, lineY)
  end

  -- Draw zone boundary rings
  -- Named zone boundary (inner 3x3 constellations = tiles -10..10 → 21 tiles)
  love.graphics.setColor(0.4, 0.6, 0.8, 0.5)
  local namedMinPx = mapX + ((-10) - WORLD_MIN) * cellSize
  local namedSize = 21 * cellSize
  love.graphics.rectangle("line", namedMinPx, mapY + (WORLD_MAX - 10) * cellSize, namedSize, namedSize)

  -- Deep space boundary (tiles -17..17 → 35 tiles)
  love.graphics.setColor(0.5, 0.4, 0.3, 0.4)
  local deepMinPx = mapX + ((-17) - WORLD_MIN) * cellSize
  local deepSize = 35 * cellSize
  love.graphics.rectangle("line", deepMinPx, mapY + (WORLD_MAX - 17) * cellSize, deepSize, deepSize)

  -- Draw constellation labels
  love.graphics.setFont(fonts.small)
  local constellationLabels = {
    {name = "The Nebula",  cx = 0,  cy = 0},
    {name = "Gargantua",   cx = 1,  cy = 0},
    {name = "Pleiades",    cx = -1, cy = 0},
    {name = "Oort Cloud",  cx = 0,  cy = 1},
    {name = "Messier",     cx = 0,  cy = -1},
    {name = "Vela",        cx = 1,  cy = 1},
    {name = "Pandora",     cx = -1, cy = 1},
    {name = "Orion",       cx = -1, cy = -1},
    {name = "Andromeda",   cx = 1,  cy = -1},
  }
  for _, c in ipairs(constellationLabels) do
    local centerTileX = c.cx * 7
    local centerTileY = c.cy * 7
    local labelX = mapX + (centerTileX - WORLD_MIN) * cellSize
    local labelY = mapY + (WORLD_MAX - centerTileY) * cellSize
    love.graphics.setColor(0.6, 0.7, 0.9, 0.7)
    love.graphics.printf(c.name, labelX - 3.5 * cellSize, labelY - cellSize * 0.3, 7 * cellSize, "center")
  end

  -- Draw zone labels for Deep Space and Outer Space rings
  love.graphics.setColor(0.4, 0.4, 0.5, 0.5)
  -- Deep space label at top
  local deepLabelY = mapY + (WORLD_MAX - 14) * cellSize
  love.graphics.printf("DEEP SPACE", mapX, deepLabelY, mapSize, "center")
  -- Outer space label at top
  local outerLabelY = mapY + (WORLD_MAX - 25) * cellSize
  love.graphics.printf("OUTER SPACE", mapX, outerLabelY, mapSize, "center")

  -- Draw special tiles (stations/portals) with icons
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
        -- Station: filled square
        love.graphics.setColor(0.3, 0.8, 1, 1)
        love.graphics.rectangle("fill", iconX - iconR, iconY - iconR, iconR * 2, iconR * 2)
      elseif tile.type == worldmap.TILE_PORTAL then
        -- Portal: diamond/triangle
        love.graphics.setColor(tile.color[1], tile.color[2], tile.color[3], 1)
        love.graphics.polygon("fill",
          iconX, iconY - iconR,
          iconX + iconR, iconY,
          iconX, iconY + iconR,
          iconX - iconR, iconY)
      end
    end
  end

  -- Draw cursor
  local cursorCellX = mapX + (worldMapCursor.x - WORLD_MIN) * cellSize
  local cursorCellY = mapY + (WORLD_MAX - worldMapCursor.y) * cellSize
  local pulse = math.sin(love.timer.getTime() * 4) * 0.3 + 0.7
  love.graphics.setColor(1, 1, 0, pulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cursorCellX - 1, cursorCellY - 1, cellSize + 1, cellSize + 1)
  love.graphics.setLineWidth(1)

  -- Draw player position marker
  local playerCellX = mapX + (playerTX - WORLD_MIN) * cellSize + cellSize / 2
  local playerCellY = mapY + (WORLD_MAX - playerTY) * cellSize + cellSize / 2
  love.graphics.setColor(0, 1, 0, 0.9)
  love.graphics.circle("fill", playerCellX, playerCellY, math.max(2, cellSize * 0.3))

  -- Info panel at bottom
  local infoY = mapY + mapSize + 5
  love.graphics.setFont(fonts.small)

  -- Cursor tile info
  local cursorTile = worldmap.getTile(worldMapCursor.x, worldMapCursor.y)
  local cursorZone = constellation.getZone(worldMapCursor.x, worldMapCursor.y)
  local zoneName = worldmap.getZoneName(worldMapCursor.x, worldMapCursor.y)
  local discovered = worldmap.isDiscovered(worldMapCursor.x, worldMapCursor.y)
  local inRange = worldmap.canFastTravel(worldMapCursor.x, worldMapCursor.y)

  -- Left: tile info
  love.graphics.setColor(0.8, 0.8, 0.9)
  local tileLabel = "(" .. worldMapCursor.x .. ", " .. worldMapCursor.y .. ") " .. zoneName
  if discovered and cursorTile.type ~= worldmap.TILE_EMPTY then
    tileLabel = tileLabel .. " — " .. (cursorTile.name or "")
  elseif not discovered then
    tileLabel = tileLabel .. " (Unexplored)"
  end
  love.graphics.print(tileLabel, mapX, infoY)

  -- Right: radio range status
  if inRange then
    love.graphics.setColor(0.3, 1, 0.4)
    love.graphics.printf("● IN RANGE — ENTER to Fast Travel", 0, infoY, screenW - mapX, "right")
  else
    love.graphics.setColor(0.7, 0.3, 0.3)
    love.graphics.printf("○ OUT OF RANGE", 0, infoY, screenW - mapX, "right")
  end

  -- Status message (e.g. "Cannot fast travel: out of radio range")
  if worldMapMessage then
    love.graphics.setFont(fonts.code or fonts.menu)
    love.graphics.setColor(1, 0.4, 0.3, 0.9)
    love.graphics.printf(worldMapMessage, 0, infoY + 16, screenW, "center")
  end

  -- Controls
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Move Cursor | ENTER: Fast Travel | P: Center on Player | ESC: Back", 0, screenH - 22, screenW, "center")

  -- Legend
  local legendX = mapX
  local legendY = infoY + 18
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.print("Legend:", legendX, legendY)
  -- Station icon
  love.graphics.setColor(0.3, 0.8, 1)
  love.graphics.rectangle("fill", legendX + 52, legendY + 2, 8, 8)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("Station", legendX + 64, legendY)
  -- Portal icon
  love.graphics.setColor(0.8, 0.5, 0.3)
  love.graphics.polygon("fill",
    legendX + 130, legendY + 1,
    legendX + 135, legendY + 6,
    legendX + 130, legendY + 11,
    legendX + 125, legendY + 6)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("Portal", legendX + 140, legendY)
  -- Player icon
  love.graphics.setColor(0, 1, 0)
  love.graphics.circle("fill", legendX + 204, legendY + 6, 4)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.print("You", legendX + 212, legendY)
end

function M.draw()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  if subMenu == "world_map" then
    drawWorldMap()
  elseif subMenu == "warp_list" then
    drawWarpList()
  elseif subMenu == "enter_code" then
    drawEnterCode()
  elseif subMenu == "options" then
    drawOptionsMenu()
  else
    drawMainPause()
  end
  
  -- White fade overlay
  if fadeState.active and fadeState.alpha > 0 then
    love.graphics.setColor(1, 1, 1, fadeState.alpha)
    love.graphics.rectangle("fill", 0, 0, 1366, 768)
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

local function keypressedMainPause(key)
  local menuItems = buildMenuItems()
  if key == "up" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then
      selectedIndex = #menuItems
    end
  elseif key == "down" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #menuItems then
      selectedIndex = 1
    end
  elseif key == "escape" then
    if M.onResume then
      M.onResume()
    end
  elseif key == "return" or key == "space" then
    local item = menuItems[selectedIndex]
    if item == "Resume" then
      if M.onResume then M.onResume() end
    elseif item == "World Map" then
      subMenu = "world_map"
      -- Initialize cursor at player position
      local ok, worldmap = pcall(require, "asteroids.worldmap")
      if ok then
        worldMapCursor.x = worldmap.tileX
        worldMapCursor.y = worldmap.tileY
      end
      worldMapMessage = nil
    elseif item == "Options" then
      subMenu = "options"
      optionsIndex = 1
    elseif item == "Save" then
      if M.onSave then M.onSave() end
    elseif item == "Return to Ship" then
      if M.returnToShip then M.returnToShip() end
    elseif item == "Return to Planet Map" then
      if M.returnToStation then M.returnToStation() end
    elseif item == "Exit to Main Menu" then
      if M.onExitToMenu then M.onExitToMenu() end
    elseif item == "Exit to Desktop" then
      love.event.quit()
    end
  end
end

local function keypressedOptions(key)
  local items = buildOptionsItems()
  if key == "up" then
    optionsIndex = optionsIndex - 1
    if optionsIndex < 1 then optionsIndex = #items end
  elseif key == "down" then
    optionsIndex = optionsIndex + 1
    if optionsIndex > #items then optionsIndex = 1 end
  elseif key == "escape" then
    subMenu = nil
  elseif key == "return" or key == "space" then
    local item = items[optionsIndex]
    if item == "Enter Code" then
      subMenu = "enter_code"
      codeInput = ""
      codeMessage = nil
    elseif item == "Back" then
      subMenu = nil
    end
  end
end

local function activateOmnia()
  omniaActivated = true
  codeMessage = "Code Accepted!"
  codeMessageTimer = 1.5

  -- Set barrier to 63x63 (±31 tiles) via constellation
  local ok, constellation = pcall(require, "asteroids.constellation")
  if ok then
    -- Override to maximum outer space bounds
    constellation.currentTier = constellation.TIER_OUTER_SPACE
    constellation.sentinelDefeated = true
    constellation.antennaInstalled = true
  end

  -- Update worldmap bounds
  local ok2, worldmap = pcall(require, "asteroids.worldmap")
  if ok2 and worldmap.updateBounds then
    worldmap.updateBounds()
  end

  -- Open warp list after brief delay (show message first)
  warpList = buildWarpList()
  warpIndex = 1
  warpScrollOffset = 0
end

local function keypressedEnterCode(key)
  if key == "escape" then
    subMenu = "options"
    codeInput = ""
    codeMessage = nil
  elseif key == "backspace" then
    codeInput = codeInput:sub(1, -2)
  elseif key == "return" then
    if codeInput:lower() == "omnia" then
      activateOmnia()
      -- After code accepted, go to warp list
      subMenu = "warp_list"
    else
      codeMessage = "Invalid Code"
      codeMessageTimer = 2
      codeInput = ""
    end
  end
end

local function keypressedWarpList(key)
  -- Count selectable items
  local selectableItems = {}
  for i, entry in ipairs(warpList) do
    if entry.type ~= "header" then
      table.insert(selectableItems, i)
    end
  end

  if key == "up" then
    warpIndex = warpIndex - 1
    if warpIndex < 1 then warpIndex = #selectableItems end
  elseif key == "down" then
    warpIndex = warpIndex + 1
    if warpIndex > #selectableItems then warpIndex = 1 end
  elseif key == "escape" then
    subMenu = nil
  elseif key == "return" or key == "space" then
    local listIndex = selectableItems[warpIndex]
    local entry = warpList[listIndex]
    if entry and M.onWarpTo then
      -- Start fade to white
      fadeState.active = true
      fadeState.alpha = 0
      fadeState.fadingOut = true
      fadeState.callback = function()
        M.onWarpTo(entry)
        -- Close pause menu after warp
        subMenu = nil
        if M.onResume then M.onResume() end
      end
    end
  end
end

local function keypressedWorldMap(key)
  local WORLD_MIN = -31
  local WORLD_MAX = 31

  if key == "escape" then
    subMenu = nil
    worldMapMessage = nil
  elseif key == "up" then
    worldMapCursor.y = math.min(WORLD_MAX, worldMapCursor.y + 1)
  elseif key == "down" then
    worldMapCursor.y = math.max(WORLD_MIN, worldMapCursor.y - 1)
  elseif key == "left" then
    worldMapCursor.x = math.max(WORLD_MIN, worldMapCursor.x - 1)
  elseif key == "right" then
    worldMapCursor.x = math.min(WORLD_MAX, worldMapCursor.x + 1)
  elseif key == "p" then
    -- Center cursor on player
    local ok, worldmap = pcall(require, "asteroids.worldmap")
    if ok then
      worldMapCursor.x = worldmap.tileX
      worldMapCursor.y = worldmap.tileY
    end
  elseif key == "return" or key == "space" then
    -- Attempt fast travel
    local ok, worldmap = pcall(require, "asteroids.worldmap")
    if not ok then return end

    -- Don't fast travel to current tile
    if worldMapCursor.x == worldmap.tileX and worldMapCursor.y == worldmap.tileY then
      worldMapMessage = "You are already here!"
      worldMapMessageTimer = 2
      return
    end

    -- Check radio range
    if not worldmap.canFastTravel(worldMapCursor.x, worldMapCursor.y) then
      local ok2, constellation = pcall(require, "asteroids.constellation")
      local zone = ok2 and constellation.getZone(worldMapCursor.x, worldMapCursor.y) or nil
      if zone == constellation.ZONE_OUTER_SPACE then
        worldMapMessage = "Cannot fast travel: Outer Space is beyond radio range"
      elseif zone == constellation.ZONE_DEEP_SPACE then
        worldMapMessage = "Cannot fast travel: need Power Amplifier for Deep Space range"
      else
        worldMapMessage = "Cannot fast travel: need Mega Antenna for radio communication"
      end
      worldMapMessageTimer = 3
      return
    end

    -- Check if target tile is within current grid bounds (accessible)
    if worldMapCursor.x < worldmap.GRID_MIN or worldMapCursor.x > worldmap.GRID_MAX or
       worldMapCursor.y < worldmap.GRID_MIN or worldMapCursor.y > worldmap.GRID_MAX then
      worldMapMessage = "Cannot fast travel: sector not yet accessible"
      worldMapMessageTimer = 2
      return
    end

    -- Fast travel!
    if M.onFastTravel then
      M.onFastTravel(worldMapCursor.x, worldMapCursor.y)
      subMenu = nil
      worldMapMessage = nil
      if M.onResume then M.onResume() end
    end
  end
end

function M.keypressed(key)
  if subMenu == "world_map" then
    keypressedWorldMap(key)
  elseif subMenu == "warp_list" then
    keypressedWarpList(key)
  elseif subMenu == "enter_code" then
    keypressedEnterCode(key)
  elseif subMenu == "options" then
    keypressedOptions(key)
  else
    keypressedMainPause(key)
  end
end

function M.textinput(text)
  if subMenu == "enter_code" then
    -- Only allow letters
    if text:match("^%a$") then
      codeInput = codeInput .. text
    end
  end
end

function M.isOmniaActive()
  return omniaActivated
end

function M.openWarpList()
  warpList = buildWarpList()
  warpIndex = 1
  warpScrollOffset = 0
  subMenu = "warp_list"
end

function M.mousepressed(x, y, button)
  -- Not implemented for pause menu
end

return M
