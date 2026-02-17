local M = {}

local resolution = require("resolution")
local controller = require("controller")
local selectedIndex = 1
local fonts = {}

-- Sub-menu state
local subMenu = nil          -- nil = main pause, "options" = options sub-menu, "enter_code" = text input, "warp_list" = omnia warp, "world_map" = world map
local optionsIndex = 1
local warpIndex = 1
local warpScrollOffset = 0
local warpTab = 1            -- 1 = Starfox, 2 = Planets, 3 = Constellations
local warpTabs = {}          -- {[1] = {label, items}, [2] = ..., [3] = ...}
local warpTabNames = {"STARFOX", "PLANETS", "CONSTELLATIONS"}
local warpFloorMenu = nil    -- nil = top-level, or {hubType=..., label=..., floors={...}}
local warpFloorIndex = 1     -- Selection index within floor sub-menu
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
  return {
    { label = "Resolution: " .. resolution.getCurrentLabel(), type = "resolution" },
    { label = "Controller: " .. controller.getCurrentLabel(), type = "controller" },
    { label = "Enter Code", type = "enter_code" },
    { label = "Back", type = "back" },
  }
end

-- Build the warp tabs for omnia cheat (3 tabs: Starfox, Planets, Constellations)
local function buildWarpTabs()
  local tabs = {}

  -- Tab 1: Starfox
  local starfox = {}
  table.insert(starfox, {type = "header", label = "STAGES"})
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
    table.insert(starfox, {type = "starfox", label = lvl.name, levelId = lvl.id})
  end
  table.insert(starfox, {type = "header", label = "RAIDS"})
  local starfoxRaids = {
    {id = 21, name = "Synesthesia Installation"},
    {id = 22, name = "Megalith of Memories"},
    {id = 23, name = "Distant Dynamo"},
    {id = 25, name = "Logician's Lament"},
  }
  for _, raid in ipairs(starfoxRaids) do
    table.insert(starfox, {type = "starfox", label = raid.name, levelId = raid.id})
  end
  tabs[1] = starfox

  -- Tab 2: Planets
  -- Multi-floor worlds use hub_parent (opens floor sub-menu on select)
  -- Single-floor worlds are just hub_area (warp directly)
  local planets = {}
  table.insert(planets, {type = "hub_parent", label = "Hometown Station", hubType = "hometown", floors = {
    {id = 0, name = "Sub-Level Zero"},
    {id = 1, name = "Cargo Bay"},
    {id = 2, name = "Commerce Deck"},
    {id = 3, name = "Residential Deck"},
    {id = 4, name = "Flight Deck"},
    {id = 5, name = "Lookout"},
    {id = 6, name = "Apex Tower"},
  }})
  table.insert(planets, {type = "hub_parent", label = "Mixia", hubType = "mixia", floors = {
    {id = 0, name = "Ancient Citadel"},
    {id = 1, name = "The Surface"},
    {id = 2, name = "Industrial Zone"},
    {id = 3, name = "Commerce Level"},
    {id = 4, name = "Upper District"},
    {id = 5, name = "Skyline Terrace"},
  }})
  table.insert(planets, {type = "hub_area", label = "Leucadia", hubType = "leucadia"})
  table.insert(planets, {type = "hub_area", label = "The Singularity", hubType = "singularity"})
  table.insert(planets, {type = "hub_area", label = "Elendil", hubType = "elendil"})
  table.insert(planets, {type = "hub_area", label = "Chillon", hubType = "chillon"})
  table.insert(planets, {type = "hub_area", label = "Kala Patthar", hubType = "kalapatthar"})
  table.insert(planets, {type = "hub_area", label = "Cereus", hubType = "cereus"})
  tabs[2] = planets

  -- Tab 3: Constellations
  local constellationsList = {}
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
    table.insert(constellationsList, {type = "constellation", label = c.name, tileX = c.tileX, tileY = c.tileY})
  end
  tabs[3] = constellationsList

  return tabs
end

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
  warpFloorMenu = nil
  warpFloorIndex = 1
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
  local startY = 310
  local itemHeight = 50

  for i, item in ipairs(items) do
    if i == optionsIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. item.label .. " <", 0, startY + (i - 1) * itemHeight, 1366, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(item.label, 0, startY + (i - 1) * itemHeight, 1366, "center")
    end
  end

  -- Show hint for cycling rows
  local selItem = items[optionsIndex]
  if selItem and (selItem.type == "resolution" or selItem.type == "controller") then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("< LEFT / RIGHT > to change  |  ENTER to apply", 0, startY + #items * itemHeight + 10, 1366, "center")
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
  local screenW = 1366

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 0.85, 0.2)
  love.graphics.printf("OMNIA - WARP ANYWHERE", 0, 20, screenW, "center")

  -- Tab Bar
  local tabY = 60
  local tabW = 260
  local tabSpacing = 20
  local totalTabW = #warpTabNames * tabW + (#warpTabNames - 1) * tabSpacing
  local tabStartX = math.floor((screenW - totalTabW) / 2)

  love.graphics.setFont(fonts.menu)
  for i, name in ipairs(warpTabNames) do
    local tx = tabStartX + (i - 1) * (tabW + tabSpacing)
    if i == warpTab then
      love.graphics.setColor(0.15, 0.2, 0.35)
      love.graphics.rectangle("fill", tx, tabY, tabW, 36, 6, 6)
      love.graphics.setColor(1, 0.85, 0.2)
      love.graphics.rectangle("line", tx, tabY, tabW, 36, 6, 6)
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf(name, tx, tabY + 5, tabW, "center")
    else
      love.graphics.setColor(0.1, 0.1, 0.15, 0.7)
      love.graphics.rectangle("fill", tx, tabY, tabW, 36, 6, 6)
      love.graphics.setColor(0.3, 0.3, 0.4)
      love.graphics.rectangle("line", tx, tabY, tabW, 36, 6, 6)
      love.graphics.setColor(0.5, 0.5, 0.55)
      love.graphics.printf(name, tx, tabY + 5, tabW, "center")
    end
  end

  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.printf("<", tabStartX - 30, tabY + 5, 20, "center")
  love.graphics.printf(">", tabStartX + totalTabW + 10, tabY + 5, 20, "center")

  -- Tab Content
  local startY = 110
  local itemHeight = 28
  local maxVisible = 20
  local listFont = fonts.code or fonts.menu
  love.graphics.setFont(listFont)

  -- Floor sub-menu mode
  if warpFloorMenu then
    love.graphics.setFont(fonts.menu)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.printf(warpFloorMenu.label .. " - Select Floor", 200, startY, 966, "center")

    love.graphics.setFont(listFont)
    local floors = warpFloorMenu.floors
    for i, f in ipairs(floors) do
      local y = startY + 36 + (i - 1) * itemHeight
      if i == warpFloorIndex then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> Floor " .. f.id .. ": " .. f.name, 250, y, 866, "left")
      else
        love.graphics.setColor(0.75, 0.75, 0.75)
        love.graphics.printf("  Floor " .. f.id .. ": " .. f.name, 250, y, 866, "left")
      end
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("UP/DOWN Navigate | ENTER: Warp | ESC: Back to list", 0, 720, screenW, "center")
    return
  end

  -- Normal list mode
  local currentList = warpTabs[warpTab] or {}

  local selectableItems = {}
  for i, entry in ipairs(currentList) do
    if entry.type ~= "header" then
      table.insert(selectableItems, i)
    end
  end

  local selectedListIndex = selectableItems[warpIndex] or 1
  if selectedListIndex - warpScrollOffset > maxVisible then
    warpScrollOffset = selectedListIndex - maxVisible
  elseif selectedListIndex - warpScrollOffset < 1 then
    warpScrollOffset = selectedListIndex - 1
  end

  local drawn = 0
  for i = warpScrollOffset + 1, #currentList do
    if drawn >= maxVisible then break end

    local entry = currentList[i]
    local y = startY + drawn * itemHeight

    if entry.type == "header" then
      love.graphics.setColor(0.4, 0.6, 1)
      love.graphics.printf(entry.label, 200, y, 966, "center")
    else
      local isSelected = false
      for si, li in ipairs(selectableItems) do
        if li == i and si == warpIndex then
          isSelected = true
          break
        end
      end

      local suffix = ""
      if entry.type == "hub_parent" then
        suffix = "  >"
      end

      if isSelected then
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("> " .. entry.label .. suffix, 250, y, 866, "left")
      else
        love.graphics.setColor(0.75, 0.75, 0.75)
        love.graphics.printf("  " .. entry.label .. suffix, 250, y, 866, "left")
      end
    end

    drawn = drawn + 1
  end

  -- Scroll indicators
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  if warpScrollOffset > 0 then
    love.graphics.printf("^ More above", 0, startY - 18, screenW, "center")
  end
  if warpScrollOffset + maxVisible < #currentList then
    love.graphics.printf("v More below", 0, startY + maxVisible * itemHeight + 4, screenW, "center")
  end

  love.graphics.printf("<> Tabs | UP/DOWN Navigate | ENTER: Warp | ESC: Back", 0, 720, screenW, "center")
end

-- ═══════════════════════════════════════
-- WORLD MAP
-- ═══════════════════════════════════════

local function drawWorldMap()
  local ok1, worldmap = pcall(require, "asteroids.worldmap")
  local ok2, constellation = pcall(require, "asteroids.constellation")
  if not ok1 or not ok2 then return end

  local WORLD_MIN = -38
  local WORLD_MAX = 38

  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local marginX   = 18
  local headerH   = 42   -- title bar
  local footerH   = 72   -- info panel + controls
  local availW    = screenW - marginX * 2
  local availH    = screenH - headerH - footerH - 6

  -- Accessible tile bounds
  local gridMin = worldmap.GRID_MIN
  local gridMax = worldmap.GRID_MAX

  -- Show the accessible range plus a small border of inaccessible space for context
  local CONTEXT  = math.min(6, math.floor((WORLD_MAX - gridMax)))
  local showMinX = math.max(WORLD_MIN, gridMin - CONTEXT)
  local showMaxX = math.min(WORLD_MAX, gridMax + CONTEXT)
  local showMinY = math.max(WORLD_MIN, gridMin - CONTEXT)
  local showMaxY = math.min(WORLD_MAX, gridMax + CONTEXT)
  local showW    = showMaxX - showMinX + 1
  local showH    = showMaxY - showMinY + 1

  local cellSize = math.floor(math.min(availW / showW, availH / showH))
  cellSize = math.max(6, math.min(64, cellSize))

  local mapW = showW * cellSize
  local mapH = showH * cellSize
  local mapX = marginX + math.floor((availW - mapW) / 2)
  local mapY = headerH + 4

  -- ─── Title ───────────────────────────────────
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.75, 1)
  love.graphics.printf("WORLD MAP", 0, 8, screenW, "center")

  -- ─── Full background ─────────────────────────
  love.graphics.setColor(0.02, 0.02, 0.04, 1)
  love.graphics.rectangle("fill", mapX, mapY, mapW, mapH)

  -- ─── Draw tiles ──────────────────────────────
  for ty = showMaxY, showMinY, -1 do
    for tx = showMinX, showMaxX do
      local drawX    = mapX + (tx - showMinX) * cellSize
      local drawY    = mapY + (showMaxY - ty) * cellSize
      local inBounds = tx >= gridMin and tx <= gridMax and ty >= gridMin and ty <= gridMax
      local disc     = worldmap.isDiscovered(tx, ty)
      local zone     = constellation.getZone(tx, ty)

      if not inBounds then
        -- Outside the player's accessible area: nearly black
        love.graphics.setColor(0.02, 0.02, 0.04, 1)
      elseif not disc then
        -- Accessible but unexplored: dark grey, zone-tinted
        if zone == constellation.ZONE_NAMED then
          love.graphics.setColor(0.07, 0.07, 0.11, 1)
        elseif zone == constellation.ZONE_DEEP_SPACE then
          love.graphics.setColor(0.05, 0.05, 0.08, 1)
        else
          love.graphics.setColor(0.03, 0.03, 0.05, 1)
        end
      else
        -- Discovered: full colour by zone/type
        local tile = worldmap.getTile(tx, ty)
        if tile.type == worldmap.TILE_STATION then
          love.graphics.setColor(0.18, 0.35, 0.6, 1)
        elseif tile.type == worldmap.TILE_PORTAL then
          love.graphics.setColor(
            tile.color[1] * 0.6, tile.color[2] * 0.6, tile.color[3] * 0.6, 1)
        else
          if zone == constellation.ZONE_NAMED then
            local cId   = constellation.getConstellationId(tx, ty)
            local cData = constellation.CONSTELLATIONS[cId]
            if cData then
              local bg = cData.bgColor
              love.graphics.setColor(bg[1] * 4 + 0.08, bg[2] * 4 + 0.08, bg[3] * 4 + 0.08, 1)
            else
              love.graphics.setColor(0.14, 0.14, 0.22, 1)
            end
          elseif zone == constellation.ZONE_DEEP_SPACE then
            local cId   = constellation.getConstellationId(tx, ty)
            local cData = constellation.CONSTELLATIONS[cId]
            if cData and cData.bgColor then
              local bg = cData.bgColor
              love.graphics.setColor(bg[1] * 3 + 0.06, bg[2] * 3 + 0.06, bg[3] * 3 + 0.06, 1)
            else
              love.graphics.setColor(0.09, 0.09, 0.14, 1)
            end
          else
            love.graphics.setColor(0.06, 0.07, 0.09, 1)
          end
        end
      end
      love.graphics.rectangle("fill", drawX, drawY, cellSize - 1, cellSize - 1)
    end
  end

  -- ─── Constellation grid lines (within accessible area only) ──
  love.graphics.setColor(0.22, 0.22, 0.3, 0.45)
  love.graphics.setLineWidth(1)
  for cx = -6, 6 do
    local tileX = cx * 7
    if tileX > showMinX and tileX <= showMaxX then
      local lineX = mapX + (tileX - showMinX) * cellSize
      local clampTop    = mapY + math.max(0, (showMaxY - gridMax)) * cellSize
      local clampBottom = mapY + math.min(mapH, (showMaxY - gridMin + 1) * cellSize)
      love.graphics.line(lineX, clampTop, lineX, clampBottom)
    end
  end
  for cy = -6, 6 do
    local tileY = cy * 7
    if tileY > showMinY and tileY <= showMaxY then
      local lineY = mapY + (showMaxY - tileY) * cellSize
      local clampLeft  = mapX + math.max(0, (gridMin - showMinX)) * cellSize
      local clampRight = mapX + math.min(mapW, (gridMax - showMinX + 1) * cellSize)
      love.graphics.line(clampLeft, lineY, clampRight, lineY)
    end
  end

  -- ─── Accessible-area boundary (light blue) ───
  local bx = mapX + (gridMin - showMinX) * cellSize
  local by = mapY + (showMaxY - gridMax) * cellSize
  local bw = (gridMax - gridMin + 1) * cellSize
  local bh = (gridMax - gridMin + 1) * cellSize
  love.graphics.setColor(0.35, 0.75, 1.0, 0.85)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bw, bh)
  love.graphics.setLineWidth(1)

  -- ─── Zone boundary inner rings ────────────────
  -- Named zone inner ring (tiles -10..10 = 21x21)
  if -10 >= showMinX and 10 <= showMaxX then
    local nMinX = mapX + ((-10) - showMinX) * cellSize
    local nMinY = mapY + (showMaxY - 10) * cellSize
    local nSz   = 21 * cellSize
    love.graphics.setColor(0.4, 0.6, 0.85, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", nMinX, nMinY, nSz, nSz)
  end

  -- ─── Special-tile icons ───────────────────────
  local specialTiles = worldmap.getAllSpecialTiles()
  for key, stile in pairs(specialTiles) do
    local tx, ty = key:match("^(-?%d+),(-?%d+)$")
    tx, ty = tonumber(tx), tonumber(ty)
    if tx and ty and tx >= showMinX and tx <= showMaxX
       and ty >= showMinY and ty <= showMaxY then
      local disc  = worldmap.isDiscovered(tx, ty)
      local cx    = mapX + (tx - showMinX) * cellSize + cellSize * 0.5
      local cy    = mapY + (showMaxY - ty) * cellSize + cellSize * 0.5
      local iconR = math.max(3, cellSize * 0.32)

      if stile.type == worldmap.TILE_STATION then
        if disc then
          -- Bright filled square
          love.graphics.setColor(0.3, 0.85, 1, 1)
          love.graphics.rectangle("fill", cx - iconR, cy - iconR, iconR * 2, iconR * 2)
        else
          -- Dim outline only
          love.graphics.setColor(0.18, 0.45, 0.6, 0.55)
          love.graphics.rectangle("line", cx - iconR, cy - iconR, iconR * 2, iconR * 2)
        end
      elseif stile.type == worldmap.TILE_PORTAL then
        if disc then
          love.graphics.setColor(stile.color[1], stile.color[2], stile.color[3], 1)
        else
          love.graphics.setColor(stile.color[1] * 0.35, stile.color[2] * 0.35, stile.color[3] * 0.35, 0.55)
        end
        love.graphics.polygon("fill",
          cx, cy - iconR, cx + iconR, cy, cx, cy + iconR, cx - iconR, cy)
      end

      -- "VISITED" badge for discovered special tiles (large-enough cells only)
      if disc and cellSize >= 18 then
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.9, 1.0, 0.85, 0.85)
        love.graphics.printf("VISITED", cx - cellSize * 0.5, cy + iconR + 1, cellSize, "center")
      end
    end
  end

  -- ─── Constellation name labels ────────────────
  if cellSize >= 10 then
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
      {name = "Synesthesia", cx = -3, cy = 3},
      {name = "Megalith",    cx = 3,  cy = 3},
      {name = "Dynamo",      cx = -3, cy = -3},
      {name = "Logician",    cx = 3,  cy = -3},
    }
    love.graphics.setFont(fonts.small)
    for _, c in ipairs(constellationLabels) do
      local cTileX = c.cx * 7
      local cTileY = c.cy * 7
      -- Only draw if center is within the view
      if cTileX >= showMinX and cTileX <= showMaxX
         and cTileY >= showMinY and cTileY <= showMaxY then
        local lx = mapX + (cTileX - showMinX) * cellSize
        local ly = mapY + (showMaxY - cTileY) * cellSize
        love.graphics.setColor(0.55, 0.65, 0.85, 0.65)
        love.graphics.printf(c.name, lx - 3.5 * cellSize, ly + cellSize * 0.25, 7 * cellSize, "center")
      end
    end
  end

  -- ─── Zone labels (deep / outer space bands) ───
  if showMaxY > 10 or showMinY < -10 then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.35, 0.35, 0.45, 0.5)
    if showMaxY >= 18 and showMinY <= -18 then
      local dlY = mapY + (showMaxY - 18) * cellSize
      love.graphics.printf("DEEP SPACE", mapX, dlY, mapW, "center")
    end
    if showMaxY >= 32 and showMinY <= -32 then
      local olY = mapY + (showMaxY - 32) * cellSize
      love.graphics.printf("OUTER SPACE", mapX, olY, mapW, "center")
    end
  end

  -- ─── Player marker ────────────────────────────
  local pTX, pTY = worldmap.tileX, worldmap.tileY
  if pTX >= showMinX and pTX <= showMaxX and pTY >= showMinY and pTY <= showMaxY then
    local px = mapX + (pTX - showMinX) * cellSize + cellSize * 0.5
    local py = mapY + (showMaxY - pTY) * cellSize + cellSize * 0.5
    love.graphics.setColor(0.1, 1, 0.35, 1)
    love.graphics.circle("fill", px, py, math.max(3, cellSize * 0.28))
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.circle("line", px, py, math.max(3, cellSize * 0.28))
  end

  -- ─── Cursor ───────────────────────────────────
  -- Clamp cursor to view
  if worldMapCursor.x < showMinX then worldMapCursor.x = showMinX end
  if worldMapCursor.x > showMaxX then worldMapCursor.x = showMaxX end
  if worldMapCursor.y < showMinY then worldMapCursor.y = showMinY end
  if worldMapCursor.y > showMaxY then worldMapCursor.y = showMaxY end

  local cDX    = mapX + (worldMapCursor.x - showMinX) * cellSize
  local cDY    = mapY + (showMaxY - worldMapCursor.y) * cellSize
  local tPulse = math.sin(love.timer.getTime() * 4) * 0.3 + 0.7
  love.graphics.setColor(1, 1, 0, tPulse)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cDX - 1, cDY - 1, cellSize + 2, cellSize + 2)
  love.graphics.setLineWidth(1)

  -- ─── Info panel ───────────────────────────────
  local infoY = mapY + mapH + 8

  local cursorTile = worldmap.getTile(worldMapCursor.x, worldMapCursor.y)
  local zoneName   = worldmap.getZoneName and worldmap.getZoneName(worldMapCursor.x, worldMapCursor.y) or ""
  local disc       = worldmap.isDiscovered(worldMapCursor.x, worldMapCursor.y)
  local inRange    = worldmap.canFastTravel(worldMapCursor.x, worldMapCursor.y)
  local inAccess   = worldMapCursor.x >= gridMin and worldMapCursor.x <= gridMax
                     and worldMapCursor.y >= gridMin and worldMapCursor.y <= gridMax

  love.graphics.setFont(fonts.small)

  -- Status tag
  local statusTag, statusR, statusG, statusB
  if not inAccess then
    statusTag, statusR, statusG, statusB = "INACCESSIBLE", 0.4, 0.4, 0.45
  elseif disc then
    statusTag, statusR, statusG, statusB = "VISITED", 0.35, 1, 0.55
  else
    statusTag, statusR, statusG, statusB = "UNEXPLORED", 0.45, 0.5, 0.6
  end

  -- Tile name line
  local tileName = ""
  if disc and cursorTile.type ~= worldmap.TILE_EMPTY then
    tileName = "  —  " .. (cursorTile.name or "")
  end
  local coordLabel = "(" .. worldMapCursor.x .. ", " .. worldMapCursor.y .. ")  "
    .. zoneName .. tileName

  love.graphics.setColor(0.75, 0.8, 0.95)
  love.graphics.print(coordLabel, mapX, infoY)

  -- Status tag (right-aligned beside coord line)
  love.graphics.setColor(statusR, statusG, statusB, 0.9)
  love.graphics.printf("[ " .. statusTag .. " ]", mapX, infoY, mapW, "right")

  -- Fast-travel hint
  local ftY = infoY + 20
  if inRange then
    love.graphics.setColor(0.25, 0.9, 0.4)
    love.graphics.printf("● ENTER to Fast Travel", 0, ftY, screenW - marginX, "right")
  elseif inAccess then
    love.graphics.setColor(0.65, 0.45, 0.18)
    love.graphics.printf("○ Out of radio range", 0, ftY, screenW - marginX, "right")
  end

  -- Error / status message
  if worldMapMessage then
    love.graphics.setColor(1, 0.35, 0.25, math.min(1, worldMapMessageTimer))
    love.graphics.printf(worldMapMessage, 0, ftY, screenW, "center")
  end

  -- ─── Legend ───────────────────────────────────
  local legY = infoY + 20
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.45, 0.45, 0.55)
  love.graphics.print("Legend:", mapX, legY)

  local lx = mapX + 58
  -- Station
  love.graphics.setColor(0.3, 0.85, 1)
  love.graphics.rectangle("fill", lx, legY + 2, 9, 9)
  love.graphics.setColor(0.6, 0.65, 0.75)
  love.graphics.print("Station", lx + 12, legY)
  lx = lx + 72
  -- Portal
  love.graphics.setColor(0.85, 0.5, 0.25)
  love.graphics.polygon("fill", lx+4, legY, lx+8, legY+5, lx+4, legY+10, lx, legY+5)
  love.graphics.setColor(0.6, 0.65, 0.75)
  love.graphics.print("Portal", lx + 12, legY)
  lx = lx + 68
  -- You
  love.graphics.setColor(0.1, 1, 0.35)
  love.graphics.circle("fill", lx + 4, legY + 5, 4)
  love.graphics.setColor(0.6, 0.65, 0.75)
  love.graphics.print("You", lx + 12, legY)
  lx = lx + 50
  -- Boundary
  love.graphics.setColor(0.35, 0.75, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", lx, legY + 2, 9, 9)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.6, 0.65, 0.75)
  love.graphics.print("Accessible boundary", lx + 12, legY)

  -- ─── Controls footer ──────────────────────────
  love.graphics.setColor(0.38, 0.38, 0.45)
  love.graphics.printf(
    "↑↓←→ Move Cursor   ENTER Fast Travel   P Center on Ship   ESC Back",
    0, screenH - 22, screenW, "center")
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
  elseif key == "left" then
    local item = items[optionsIndex]
    if item and item.type == "resolution" then
      resolution.prevPreset()
    elseif item and item.type == "controller" then
      controller.prevPreset()
    end
  elseif key == "right" then
    local item = items[optionsIndex]
    if item and item.type == "resolution" then
      resolution.nextPreset()
    elseif item and item.type == "controller" then
      controller.nextPreset()
    end
  elseif key == "escape" then
    subMenu = nil
  elseif key == "return" or key == "space" then
    local item = items[optionsIndex]
    if item.type == "resolution" then
      resolution.apply()
      resolution.save()
    elseif item.type == "controller" then
      controller.save()
    elseif item.type == "enter_code" then
      subMenu = "enter_code"
      codeInput = ""
      codeMessage = nil
    elseif item.type == "back" then
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
  warpTabs = buildWarpTabs()
  warpTab = 1
  warpIndex = 1
  warpScrollOffset = 0
  warpFloorMenu = nil
  warpFloorIndex = 1
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
  -- Floor sub-menu mode
  if warpFloorMenu then
    local floors = warpFloorMenu.floors
    if key == "up" then
      warpFloorIndex = warpFloorIndex - 1
      if warpFloorIndex < 1 then warpFloorIndex = #floors end
    elseif key == "down" then
      warpFloorIndex = warpFloorIndex + 1
      if warpFloorIndex > #floors then warpFloorIndex = 1 end
    elseif key == "escape" then
      warpFloorMenu = nil
      warpFloorIndex = 1
    elseif key == "return" or key == "space" then
      local floor = floors[warpFloorIndex]
      if floor and M.onWarpTo then
        local entry = {type = "hub_floor", hubType = warpFloorMenu.hubType, floorId = floor.id}
        fadeState.active = true
        fadeState.alpha = 0
        fadeState.fadingOut = true
        fadeState.callback = function()
          M.onWarpTo(entry)
          subMenu = nil
          warpFloorMenu = nil
          warpFloorIndex = 1
          if M.onResume then M.onResume() end
        end
      end
    end
    return
  end

  -- Normal list mode
  local currentList = warpTabs[warpTab] or {}

  local selectableItems = {}
  for i, entry in ipairs(currentList) do
    if entry.type ~= "header" then
      table.insert(selectableItems, i)
    end
  end

  if key == "left" then
    warpTab = warpTab - 1
    if warpTab < 1 then warpTab = #warpTabs end
    warpIndex = 1
    warpScrollOffset = 0
  elseif key == "right" then
    warpTab = warpTab + 1
    if warpTab > #warpTabs then warpTab = 1 end
    warpIndex = 1
    warpScrollOffset = 0
  elseif key == "up" then
    warpIndex = warpIndex - 1
    if warpIndex < 1 then warpIndex = #selectableItems end
  elseif key == "down" then
    warpIndex = warpIndex + 1
    if warpIndex > #selectableItems then warpIndex = 1 end
  elseif key == "escape" then
    subMenu = nil
  elseif key == "return" or key == "space" then
    if #selectableItems == 0 then return end
    local listIndex = selectableItems[warpIndex]
    local entry = currentList[listIndex]
    if not entry then return end

    -- Multi-floor world: open floor sub-menu
    if entry.type == "hub_parent" then
      warpFloorMenu = {hubType = entry.hubType, label = entry.label, floors = entry.floors}
      warpFloorIndex = 1
      return
    end

    if M.onWarpTo then
      fadeState.active = true
      fadeState.alpha = 0
      fadeState.fadingOut = true
      fadeState.callback = function()
        M.onWarpTo(entry)
        subMenu = nil
        if M.onResume then M.onResume() end
      end
    end
  end
end

local function keypressedWorldMap(key)
  local WORLD_MIN = -38
  local WORLD_MAX = 38
  local ok0, worldmap0 = pcall(require, "asteroids.worldmap")
  local viewMin = ok0 and math.max(WORLD_MIN, worldmap0.GRID_MIN - 6) or WORLD_MIN
  local viewMax = ok0 and math.min(WORLD_MAX, worldmap0.GRID_MAX + 6) or WORLD_MAX

  if key == "escape" then
    subMenu = nil
    worldMapMessage = nil
  elseif key == "up" then
    worldMapCursor.y = math.min(viewMax, worldMapCursor.y + 1)
  elseif key == "down" then
    worldMapCursor.y = math.max(viewMin, worldMapCursor.y - 1)
  elseif key == "left" then
    worldMapCursor.x = math.max(viewMin, worldMapCursor.x - 1)
  elseif key == "right" then
    worldMapCursor.x = math.min(viewMax, worldMapCursor.x + 1)
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
  warpTabs = buildWarpTabs()
  warpTab = 1
  warpIndex = 1
  warpScrollOffset = 0
  warpFloorMenu = nil
  warpFloorIndex = 1
  subMenu = "warp_list"
end

function M.mousepressed(x, y, button)
  -- Not implemented for pause menu
end

return M
