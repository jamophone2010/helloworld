local M = {}

local selectedIndex = 1
local fonts = {}

-- Sub-menu state
local subMenu = nil          -- nil = main pause, "options" = options sub-menu, "enter_code" = text input, "warp_list" = omnia warp
local optionsIndex = 1
local warpIndex = 1
local warpScrollOffset = 0
local codeInput = ""
local codeMessage = nil      -- Feedback message after entering code
local codeMessageTimer = 0
local omniaActivated = false  -- Persists for the session

M.onResume = nil
M.onOptions = nil
M.onSave = nil
M.onExitToMenu = nil
M.returnToShip = nil      -- Set when arriving from space/asteroids
M.returnToStation = nil   -- Set when arriving from planet map
M.onWarpTo = nil           -- Callback: function(warpEntry) to teleport player

local function buildMenuItems()
  if M.returnToShip then
    return {"Resume", "Options", "Save", "Return to Ship", "Exit to Main Menu", "Exit to Desktop"}
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
  fonts.title = love.graphics.newFont(32)
  fonts.menu = love.graphics.newFont(24)
  fonts.small = love.graphics.newFont(14)
  fonts.code = love.graphics.newFont(20)
  selectedIndex = 1
  subMenu = nil
  optionsIndex = 1
  codeInput = ""
  codeMessage = nil
end

function M.update(dt)
  if codeMessageTimer > 0 then
    codeMessageTimer = codeMessageTimer - dt
    if codeMessageTimer <= 0 then
      codeMessage = nil
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

function M.draw()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  if subMenu == "warp_list" then
    drawWarpList()
  elseif subMenu == "enter_code" then
    drawEnterCode()
  elseif subMenu == "options" then
    drawOptionsMenu()
  else
    drawMainPause()
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

  -- Set barrier to 243x243 (±121 tiles) via constellation
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
      M.onWarpTo(entry)
      -- Close pause menu after warp
      subMenu = nil
      if M.onResume then M.onResume() end
    end
  end
end

function M.keypressed(key)
  if subMenu == "warp_list" then
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
