local M = {}

local ships = require("starfox.ships")
local prototype = require("starfox.prototype")
local fonts = {}
local selectedIndex = 1
local transitionTimer = 0
local transitionDir = 0 -- -1 left, 1 right, 0 none
local TRANSITION_DURATION = 0.3
local shipRotation = 0
local filteredOrder = {}

-- Build the filtered ship order (hides prototype unless quest complete)
local function buildFilteredOrder()
  filteredOrder = {}
  for _, id in ipairs(ships.order) do
    if id == "prototype" and not prototype.questComplete then
      -- Skip: Prototype not yet acquired
    else
      table.insert(filteredOrder, id)
    end
  end
end

function M.load()
  fonts.title = love.graphics.newFont(32)
  fonts.large = love.graphics.newFont(24)
  fonts.normal = love.graphics.newFont(16)
  fonts.small = love.graphics.newFont(12)
  fonts.shipName = love.graphics.newFont(28)

  -- Build filtered ship list
  buildFilteredOrder()

  -- Find current selection index
  local currentId = ships.getSelected()
  for i, id in ipairs(filteredOrder) do
    if id == currentId then
      selectedIndex = i
      break
    end
  end
  if selectedIndex > #filteredOrder then
    selectedIndex = 1
  end
  transitionTimer = 0
  transitionDir = 0
  shipRotation = 0
end

function M.update(dt)
  shipRotation = shipRotation + dt * 0.5
  if transitionTimer > 0 then
    transitionTimer = math.max(0, transitionTimer - dt)
  end
end

function M.getCredits()
  return nil -- hangar doesn't use credits
end

-- Draw a stylized ship preview
local function drawShipPreview(def, cx, cy, scale, alpha)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)

  local r, g, b = def.color[1], def.color[2], def.color[3]
  local ar, ag, ab = def.accentColor[1], def.accentColor[2], def.accentColor[3]

  -- Engine glow
  local pulse = math.sin(love.timer.getTime() * 4) * 0.15 + 0.85
  love.graphics.setColor(ar, ag, ab, 0.15 * alpha * pulse)
  love.graphics.circle("fill", 0, 30, 50)
  love.graphics.setColor(ar, ag, ab, 0.08 * alpha * pulse)
  love.graphics.circle("fill", 0, 30, 70)

  -- Engine flame
  love.graphics.setColor(1, 0.6, 0.1, 0.7 * alpha * pulse)
  love.graphics.polygon("fill", -8, 25, 0, 50 + math.sin(love.timer.getTime() * 12) * 8, 8, 25)
  love.graphics.setColor(1, 0.9, 0.3, 0.5 * alpha * pulse)
  love.graphics.polygon("fill", -4, 25, 0, 40 + math.sin(love.timer.getTime() * 15) * 5, 4, 25)

  -- Main body
  love.graphics.setColor(r * 0.6, g * 0.6, b * 0.6, alpha)
  love.graphics.polygon("fill", 0, -40, -20, 25, 20, 25)

  -- Wing shape depends on ship type
  if def.type == "Interceptor" then
    -- Swept-back narrow wings
    love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, alpha)
    love.graphics.polygon("fill", -18, 10, -50, 25, -20, 20)
    love.graphics.polygon("fill", 18, 10, 50, 25, 20, 20)
    -- Wing tips
    love.graphics.setColor(ar, ag, ab, 0.6 * alpha)
    love.graphics.polygon("fill", -45, 23, -50, 25, -40, 25)
    love.graphics.polygon("fill", 45, 23, 50, 25, 40, 25)
  elseif def.type == "Heavy" then
    -- Wide, thick wings with gun pods
    love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, alpha)
    love.graphics.polygon("fill", -15, 5, -55, 20, -55, 28, -15, 25)
    love.graphics.polygon("fill", 15, 5, 55, 20, 55, 28, 15, 25)
    -- Armor plating
    love.graphics.setColor(r * 0.4, g * 0.4, b * 0.4, 0.5 * alpha)
    love.graphics.polygon("fill", -10, -10, -25, 15, -10, 20)
    love.graphics.polygon("fill", 10, -10, 25, 15, 10, 20)
    -- Gun pods on wing tips
    love.graphics.setColor(0.55, 0.55, 0.6, 0.9 * alpha)
    love.graphics.rectangle("fill", -54, 17, 6, 14)
    love.graphics.rectangle("fill", 48, 17, 6, 14)
    love.graphics.setColor(1, 0.7, 0.2, 0.5 * alpha)
    love.graphics.circle("fill", -51, 17, 2)
    love.graphics.circle("fill", 51, 17, 2)
  elseif def.type == "Experimental" then
    -- Angular stealth wings with glowing vents
    love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, alpha)
    love.graphics.polygon("fill", -15, -5, -45, 18, -35, 30, -15, 20)
    love.graphics.polygon("fill", 15, -5, 45, 18, 35, 30, 15, 20)
    -- Glowing cyber-vents
    local ventPulse = math.sin(love.timer.getTime() * 6) * 0.3 + 0.7
    love.graphics.setColor(ar, ag, ab, ventPulse * 0.7 * alpha)
    for v = 0, 3 do
      local vy = -20 + v * 10
      love.graphics.rectangle("fill", -3, vy, 6, 4)
    end
    love.graphics.setColor(ar, ag, ab, ventPulse * 0.1 * alpha)
    love.graphics.circle("fill", 0, 0, 30)
  else
    -- Balanced wings
    love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5, alpha)
    love.graphics.polygon("fill", -15, 5, -40, 18, -40, 25, -15, 22)
    love.graphics.polygon("fill", 15, 5, 40, 18, 40, 25, 15, 22)
  end

  -- Cockpit
  love.graphics.setColor(0.3, 0.8, 1, 0.7 * alpha)
  love.graphics.polygon("fill", 0, -25, -6, -8, 6, -8)

  -- Outline
  love.graphics.setColor(1, 1, 1, 0.4 * alpha)
  love.graphics.setLineWidth(1.5)
  love.graphics.polygon("line", 0, -40, -20, 25, 20, 25)

  -- Accent stripe
  love.graphics.setColor(ar, ag, ab, 0.8 * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.line(0, -35, 0, 20)

  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

-- Draw a stat bar
local function drawStatBar(label, value, maxVal, x, y, w, h, color, alpha)
  love.graphics.setColor(1, 1, 1, 0.8 * alpha)
  love.graphics.setFont(fonts.small)
  love.graphics.print(label, x, y - 14)

  -- Background
  love.graphics.setColor(0.15, 0.15, 0.2, 0.8 * alpha)
  love.graphics.rectangle("fill", x, y, w, h, 3, 3)

  -- Fill
  local pct = math.min(value / maxVal, 1)
  love.graphics.setColor(color[1], color[2], color[3], 0.9 * alpha)
  love.graphics.rectangle("fill", x, y, w * pct, h, 3, 3)

  -- Border
  love.graphics.setColor(1, 1, 1, 0.3 * alpha)
  love.graphics.rectangle("line", x, y, w, h, 3, 3)
end

function M.draw()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Background - dark hangar
  love.graphics.setColor(0.05, 0.05, 0.1)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Floor grid
  love.graphics.setColor(0.1, 0.1, 0.2, 0.3)
  for i = 0, screenW, 40 do
    love.graphics.line(i, screenH * 0.6, i, screenH)
  end
  for i = math.floor(screenH * 0.6), screenH, 20 do
    love.graphics.line(0, i, screenW, i)
  end

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.4, 0.8, 1)
  love.graphics.printf("H A N G A R", 0, 30, screenW, "center")

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.printf("SELECT YOUR SHIP", 0, 68, screenW, "center")

  local def = ships.defs[filteredOrder[selectedIndex]]
  local slideOffset = 0
  if transitionTimer > 0 then
    local t = transitionTimer / TRANSITION_DURATION
    slideOffset = t * transitionDir * 200
  end

  -- Draw adjacent ship previews (dimmed)
  local prevIdx = selectedIndex - 1
  if prevIdx < 1 then prevIdx = #filteredOrder end
  local nextIdx = selectedIndex + 1
  if nextIdx > #filteredOrder then nextIdx = 1 end

  local prevDef = ships.defs[filteredOrder[prevIdx]]
  local nextDef = ships.defs[filteredOrder[nextIdx]]

  drawShipPreview(prevDef, screenW * 0.15 + slideOffset, screenH * 0.38, 1.5, 0.25)
  drawShipPreview(nextDef, screenW * 0.85 + slideOffset, screenH * 0.38, 1.5, 0.25)

  -- Draw main ship (centered, large)
  local mainAlpha = 1.0
  if transitionTimer > 0 then
    mainAlpha = 1.0 - (transitionTimer / TRANSITION_DURATION) * 0.3
  end
  drawShipPreview(def, screenW * 0.5 + slideOffset, screenH * 0.35, 3.5, mainAlpha)

  -- Platform circle under ship
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.15)
  love.graphics.ellipse("fill", screenW * 0.5, screenH * 0.52, 120, 25)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.4)
  love.graphics.setLineWidth(2)
  love.graphics.ellipse("line", screenW * 0.5, screenH * 0.52, 120, 25)
  love.graphics.setLineWidth(1)

  -- Ship name and type
  love.graphics.setFont(fonts.shipName)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3])
  love.graphics.printf(def.name, 0, screenH * 0.57, screenW, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.8)
  love.graphics.printf(def.type .. " Class", 0, screenH * 0.57 + 32, screenW, "center")

  -- Info panel
  local panelX = screenW * 0.5 - 250
  local panelY = screenH * 0.67
  local panelW = 500
  local panelH = 200

  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.4)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
  love.graphics.setLineWidth(1)

  -- Stat bars
  local barX = panelX + 20
  local barW = 180
  local barH = 12

  drawStatBar("SHIELD", def.healthMultiplier, 2.0, barX, panelY + 25, barW, barH, {0.2, 0.8, 0.3}, 1)
  drawStatBar("SPEED", def.speedMultiplier, 1.5, barX, panelY + 58, barW, barH, {0.3, 0.5, 1.0}, 1)
  drawStatBar("DODGE", def.dodgeMultiplier, 1.5, barX, panelY + 91, barW, barH, {1.0, 0.8, 0.2}, 1)

  -- Special ability section
  local specX = panelX + 230
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.print("SPECIAL:", specX, panelY + 12)

  if def.hasSpecial then
    love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3])
    love.graphics.print(def.specialName, specX, panelY + 32)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf(def.specialDesc, specX, panelY + 55, 240, "left")

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("Morse A (dot-dash) to activate", specX, panelY + 100, 240, "left")
  else
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print("None", specX, panelY + 32)
  end

  -- Description
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.6, 0.6, 0.7)
  love.graphics.printf(def.description, panelX + 20, panelY + 130, panelW - 40, "left")

  -- Navigation arrows
  love.graphics.setFont(fonts.large)
  local arrowPulse = math.sin(love.timer.getTime() * 3) * 0.2 + 0.8
  love.graphics.setColor(1, 1, 1, arrowPulse)
  love.graphics.printf("<", 30, screenH * 0.35, 40, "center")
  love.graphics.printf(">", screenW - 70, screenH * 0.35, 40, "center")

  -- Ship counter dots
  local dotY = screenH * 0.55
  local totalDots = #filteredOrder
  local dotSpacing = 20
  local dotsStartX = screenW * 0.5 - (totalDots - 1) * dotSpacing * 0.5
  for i = 1, totalDots do
    if i == selectedIndex then
      love.graphics.setColor(def.color[1], def.color[2], def.color[3])
      love.graphics.circle("fill", dotsStartX + (i - 1) * dotSpacing, dotY, 5)
    else
      love.graphics.setColor(0.3, 0.3, 0.4)
      love.graphics.circle("fill", dotsStartX + (i - 1) * dotSpacing, dotY, 3)
    end
  end

  -- Currently equipped indicator
  local currentId = ships.getSelected()
  if filteredOrder[selectedIndex] == currentId then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0.3, 1, 0.3)
    love.graphics.printf("[ EQUIPPED ]", 0, panelY + panelH + 10, screenW, "center")
  else
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("Press E to Equip  |  ESC to Exit", 0, panelY + panelH + 10, screenW, "center")
  end

  -- Controls
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.4, 0.4, 0.5)
  love.graphics.printf("LEFT/RIGHT: Browse  |  E: Equip  |  ESC: Exit", 0, screenH - 30, screenW, "center")
end

function M.keypressed(key)
  if key == "escape" then
    if returnToHub then
      returnToHub()
    end
  elseif key == "left" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then
      selectedIndex = #filteredOrder
    end
    transitionTimer = TRANSITION_DURATION
    transitionDir = 1
  elseif key == "right" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #filteredOrder then
      selectedIndex = 1
    end
    transitionTimer = TRANSITION_DURATION
    transitionDir = -1
  elseif key == "e" then
    -- Equip selected ship
    local id = filteredOrder[selectedIndex]
    ships.setSelected(id)
    -- Also store in hub
    local ok, hub = pcall(require, "hub")
    if ok and hub.setSelectedShip then
      hub.setSelectedShip(id)
    end
  end
end

return M
