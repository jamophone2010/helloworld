local M = {}
local buildings = require("hub.buildings")

local fonts = {}
local GRID_SIZE = 32

function M.load()
  fonts.normal = love.graphics.newFont(14)
  fonts.large = love.graphics.newFont(20)
  fonts.small = love.graphics.newFont(12)
end

function M.draw(gameState, time)
  time = time or 0
  love.graphics.push()
  love.graphics.translate(-gameState.camera.x, -gameState.camera.y)

  if gameState.location == "outdoor" then
    M.drawOutdoor(gameState)
  elseif gameState.location == "casino" then
    M.drawCasinoInterior(gameState, time)
  else
    M.drawInterior(gameState)
  end

  love.graphics.pop()

  -- UI overlay
  M.drawUI(gameState)
end

function M.drawOutdoor(gameState)
  -- Background
  love.graphics.setColor(0.2, 0.6, 0.2)
  love.graphics.rectangle("fill", 0, 0, 25 * GRID_SIZE, 21 * GRID_SIZE)
  
  -- Grid (optional, for debugging)
  love.graphics.setColor(0.15, 0.5, 0.15, 0.3)
  for x = 0, 25 do
    love.graphics.line(x * GRID_SIZE, 0, x * GRID_SIZE, 21 * GRID_SIZE)
  end
  for y = 0, 21 do
    love.graphics.line(0, y * GRID_SIZE, 25 * GRID_SIZE, y * GRID_SIZE)
  end
  
  -- Roads
  love.graphics.setColor(0.4, 0.4, 0.4)
  love.graphics.rectangle("fill", 0, 8 * GRID_SIZE, 25 * GRID_SIZE, 3 * GRID_SIZE)
  love.graphics.rectangle("fill", 11 * GRID_SIZE, 0, 3 * GRID_SIZE, 21 * GRID_SIZE)
  
  -- Buildings
  for _, building in ipairs(buildings.outdoorBuildings) do
    -- Building body
    love.graphics.setColor(building.color[1] * 0.6, building.color[2] * 0.6, building.color[3] * 0.6)
    love.graphics.rectangle("fill", building.x * GRID_SIZE, building.y * GRID_SIZE, 
                          building.width * GRID_SIZE, building.height * GRID_SIZE)
    
    -- Building outline
    love.graphics.setColor(building.color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", building.x * GRID_SIZE, building.y * GRID_SIZE, 
                          building.width * GRID_SIZE, building.height * GRID_SIZE)
    
    -- Roof
    love.graphics.setColor(building.color[1] * 0.4, building.color[2] * 0.4, building.color[3] * 0.4)
    love.graphics.polygon("fill", 
      building.x * GRID_SIZE, building.y * GRID_SIZE,
      (building.x + building.width/2) * GRID_SIZE, (building.y - 1) * GRID_SIZE,
      (building.x + building.width) * GRID_SIZE, building.y * GRID_SIZE)
    
    -- Door
    love.graphics.setColor(0.3, 0.2, 0.1)
    love.graphics.rectangle("fill", building.doorX * GRID_SIZE + 4, building.doorY * GRID_SIZE + 4, 
                          GRID_SIZE - 8, GRID_SIZE - 8)
    
    -- Sign
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(building.name, (building.x) * GRID_SIZE, (building.y - 1.5) * GRID_SIZE,
                        building.width * GRID_SIZE, "center")
  end
  
  M.drawPlayer(gameState.player)
end

function M.drawInterior(gameState)
  local interior = buildings.interiors[gameState.location]
  if not interior then return end
  
  -- Floor
  love.graphics.setColor(0.7, 0.6, 0.5)
  love.graphics.rectangle("fill", 0, 0, interior.width * GRID_SIZE, interior.height * GRID_SIZE)
  
  -- Floor tiles
  love.graphics.setColor(0.6, 0.5, 0.4, 0.3)
  for x = 0, interior.width - 1 do
    for y = 0, interior.height - 1 do
      love.graphics.rectangle("line", x * GRID_SIZE, y * GRID_SIZE, GRID_SIZE, GRID_SIZE)
    end
  end
  
  -- Walls
  love.graphics.setColor(0.4, 0.3, 0.2)
  love.graphics.setLineWidth(4)
  love.graphics.rectangle("line", 0, 0, interior.width * GRID_SIZE, interior.height * GRID_SIZE)
  
  -- Exit door
  love.graphics.setColor(0.3, 0.6, 0.3)
  love.graphics.rectangle("fill", interior.exitX * GRID_SIZE + 4, interior.exitY * GRID_SIZE + 4,
                        GRID_SIZE - 8, GRID_SIZE - 8)
  
  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.3)
      love.graphics.rectangle("fill", portal.x * GRID_SIZE, portal.y * GRID_SIZE, 
                            GRID_SIZE * 2, GRID_SIZE * 2)
      
      love.graphics.setColor(portal.color)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", portal.x * GRID_SIZE, portal.y * GRID_SIZE, 
                            GRID_SIZE * 2, GRID_SIZE * 2)
      
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf(portal.name, portal.x * GRID_SIZE, (portal.y - 0.7) * GRID_SIZE, 
                          GRID_SIZE * 2, "center")
    end
  end
  
  -- NPCs
  for _, npc in ipairs(gameState.currentNPCs) do
    M.drawNPC(npc)
  end
  
  M.drawPlayer(gameState.player)
end

function M.drawPlayer(player)
  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", player.x, player.y + 10, 10, 5)
  
  -- Player sprite (simple representation)
  love.graphics.setColor(0.2, 0.4, 0.8)
  love.graphics.rectangle("fill", player.x - 10, player.y - 10, 20, 24)
  
  -- Head
  love.graphics.setColor(1, 0.8, 0.6)
  love.graphics.circle("fill", player.x, player.y - 14, 8)
  
  -- Direction indicator
  love.graphics.setColor(1, 1, 1)
  if player.direction == "up" then
    love.graphics.rectangle("fill", player.x - 2, player.y - 18, 4, 4)
  elseif player.direction == "down" then
    love.graphics.rectangle("fill", player.x - 2, player.y + 10, 4, 4)
  elseif player.direction == "left" then
    love.graphics.rectangle("fill", player.x - 14, player.y - 2, 4, 4)
  elseif player.direction == "right" then
    love.graphics.rectangle("fill", player.x + 10, player.y - 2, 4, 4)
  end
end

function M.drawNPC(npc)
  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", npc.x * GRID_SIZE + 16, npc.y * GRID_SIZE + 26, 10, 5)
  
  -- NPC sprite
  love.graphics.setColor(0.8, 0.3, 0.3)
  love.graphics.rectangle("fill", npc.x * GRID_SIZE + 6, npc.y * GRID_SIZE + 6, 20, 24)
  
  -- Head
  love.graphics.setColor(1, 0.7, 0.5)
  love.graphics.circle("fill", npc.x * GRID_SIZE + 16, npc.y * GRID_SIZE + 2, 8)
end

function M.drawUI(gameState)
  -- Location name
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 800, 35)
  love.graphics.setColor(1, 1, 1)
  
  local locationName = gameState.location == "outdoor" and "Town Center" or 
                       (buildings.interiors[gameState.location] and buildings.interiors[gameState.location].name or gameState.location)
  love.graphics.printf(locationName, 0, 8, 800, "center")
  
  -- Controls
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 565, 450, 35)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Arrow Keys: Move  |  Z: Run  |  E: Interact", 10, 573)
  
  -- Interaction prompts
  if gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 250, 250, 300, 100)
    love.graphics.setColor(1, 1, 0)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("Press E", 250, 270, 300, "center")
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("to play " .. gameState.nearbyPortal.name, 250, 300, 300, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 250, 250, 300, 100)
    love.graphics.setColor(0.5, 1, 0.5)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("Press E", 250, 270, 300, "center")
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("to talk to " .. gameState.nearbyNPC.name, 250, 300, 300, "center")
  end
  
  -- Dialogue box
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 100, 400, 600, 150)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 100, 400, 600, 150)
    
    love.graphics.setFont(fonts.large)
    love.graphics.setColor(1, 1, 0)
    love.graphics.print(gameState.dialogueBox.npc, 120, 415)
    
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(gameState.dialogueBox.text, 120, 450, 560, "left")
    
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press E or ESC to close", 120, 520)
  end
end

-- Bellagio Casino Drawing Functions

function M.drawChihulyCeiling(centerX, y, time)
  -- Animated glass sculpture with rainbow orbs
  for i = 1, 15 do
    local xOffset = (i - 8) * 55
    local yOffset = math.sin(time * 1.5 + i * 0.7) * 8
    local size = 12 + math.sin(time * 2 + i) * 4
    local hue = ((i * 25) + time * 30) % 360
    local r, g, b = M.hslToRgb(hue / 360, 0.8, 0.55)
    love.graphics.setColor(r, g, b, 0.85)
    love.graphics.circle("fill", centerX + xOffset, y + yOffset, size)
    -- Inner glow
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.circle("fill", centerX + xOffset - 3, y + yOffset - 3, size * 0.4)
  end
end

function M.hslToRgb(h, s, l)
  if s == 0 then return l, l, l end
  local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
  end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)
end

function M.drawFountain(x, y, time)
  -- Water base
  love.graphics.setColor(0.2, 0.5, 0.9, 0.6)
  love.graphics.circle("fill", x, y, 40)

  -- Animated concentric rings
  for ring = 1, 4 do
    local phase = (time * 2 + ring * 0.8) % 3
    local radius = 10 + phase * 15
    local alpha = 1 - (phase / 3)
    love.graphics.setColor(0.4, 0.7, 1, alpha * 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, radius)
  end

  -- Center spout
  love.graphics.setColor(0.6, 0.85, 1, 0.9)
  love.graphics.circle("fill", x, y, 8)
end

function M.drawFloorZone(zone, gridSize)
  local x1, y1 = zone.x1 * gridSize, zone.y1 * gridSize
  local w = (zone.x2 - zone.x1 + 1) * gridSize
  local h = (zone.y2 - zone.y1 + 1) * gridSize

  if zone.floor == "marble" then
    -- Cream/beige checkerboard
    for gx = zone.x1, zone.x2 do
      for gy = zone.y1, zone.y2 do
        local isLight = (gx + gy) % 2 == 0
        if isLight then
          love.graphics.setColor(0.95, 0.92, 0.85)
        else
          love.graphics.setColor(0.85, 0.80, 0.72)
        end
        love.graphics.rectangle("fill", gx * gridSize, gy * gridSize, gridSize, gridSize)
      end
    end
  elseif zone.floor == "carpet_red" then
    -- Deep red carpet
    love.graphics.setColor(0.55, 0.08, 0.08)
    love.graphics.rectangle("fill", x1, y1, w, h)
    -- Gold border
    love.graphics.setColor(0.85, 0.7, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x1 + 2, y1 + 2, w - 4, h - 4)
  elseif zone.floor == "carpet_dark" then
    -- Dark carpet with diamond pattern
    love.graphics.setColor(0.18, 0.1, 0.1)
    love.graphics.rectangle("fill", x1, y1, w, h)
    love.graphics.setColor(0.25, 0.15, 0.15, 0.5)
    for gx = zone.x1, zone.x2 do
      for gy = zone.y1, zone.y2 do
        if (gx + gy) % 2 == 0 then
          local cx = gx * gridSize + gridSize / 2
          local cy = gy * gridSize + gridSize / 2
          love.graphics.polygon("fill",
            cx, cy - 12,
            cx + 12, cy,
            cx, cy + 12,
            cx - 12, cy)
        end
      end
    end
  end
end

function M.drawBlackjackTable(x, y, gridSize)
  local cx = x * gridSize + gridSize * 1.5
  local cy = y * gridSize + gridSize * 1.5

  -- Table shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", cx + 3, cy + 3, gridSize * 1.4, gridSize * 1.1)

  -- Green felt semi-circle
  love.graphics.setColor(0.1, 0.45, 0.2)
  love.graphics.arc("fill", cx, cy + gridSize * 0.3, gridSize * 1.3, math.pi, 0)

  -- Table edge
  love.graphics.setColor(0.4, 0.25, 0.1)
  love.graphics.setLineWidth(4)
  love.graphics.arc("line", cx, cy + gridSize * 0.3, gridSize * 1.3, math.pi, 0)

  -- Betting circles
  love.graphics.setColor(1, 1, 1, 0.4)
  love.graphics.setLineWidth(2)
  for i = -1, 1 do
    love.graphics.circle("line", cx + i * gridSize * 0.7, cy - gridSize * 0.2, 10)
  end

  -- Dealer position marker
  love.graphics.setColor(0.8, 0.7, 0.2)
  love.graphics.rectangle("fill", cx - 15, cy + gridSize * 0.15, 30, 6)
end

function M.drawRouletteTable(x, y, gridSize, time)
  local cx = x * gridSize + gridSize * 2
  local cy = y * gridSize + gridSize * 1.5

  -- Betting cloth
  love.graphics.setColor(0.1, 0.45, 0.2)
  love.graphics.rectangle("fill", x * gridSize + gridSize * 2.5, y * gridSize, gridSize * 1.5, gridSize * 3)

  -- Wheel base
  love.graphics.setColor(0.35, 0.2, 0.1)
  love.graphics.circle("fill", cx, cy, gridSize * 1.2)

  -- Wheel segments (animated rotation)
  local segments = 12
  local rotation = time * 0.5
  for i = 0, segments - 1 do
    local angle1 = (i / segments) * math.pi * 2 + rotation
    local angle2 = ((i + 1) / segments) * math.pi * 2 + rotation
    if i == 0 then
      love.graphics.setColor(0, 0.6, 0)
    elseif i % 2 == 0 then
      love.graphics.setColor(0.8, 0.1, 0.1)
    else
      love.graphics.setColor(0.1, 0.1, 0.1)
    end
    love.graphics.arc("fill", cx, cy, gridSize, angle1, angle2)
  end

  -- Center hub
  love.graphics.setColor(0.85, 0.75, 0.3)
  love.graphics.circle("fill", cx, cy, gridSize * 0.25)

  -- Outer rim
  love.graphics.setColor(0.5, 0.35, 0.15)
  love.graphics.setLineWidth(5)
  love.graphics.circle("line", cx, cy, gridSize * 1.2)
end

function M.drawSlotMachines(x, y, gridSize, time)
  for i = 0, 2 do
    local mx = x * gridSize + i * gridSize
    local my = y * gridSize

    -- Machine body
    love.graphics.setColor(0.7, 0.55, 0.1)
    love.graphics.rectangle("fill", mx + 4, my + 4, gridSize - 8, gridSize * 1.8)

    -- Screen
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", mx + 8, my + 12, gridSize - 16, gridSize * 0.7)

    -- Blinking lights
    local blink = math.sin(time * 4 + i * 2) > 0
    if blink then
      love.graphics.setColor(1, 0.2, 0.2)
    else
      love.graphics.setColor(0.3, 0.1, 0.1)
    end
    love.graphics.circle("fill", mx + 12, my + 8, 4)

    local blink2 = math.sin(time * 4 + i * 2 + 1) > 0
    if blink2 then
      love.graphics.setColor(0.2, 1, 0.2)
    else
      love.graphics.setColor(0.1, 0.3, 0.1)
    end
    love.graphics.circle("fill", mx + gridSize - 12, my + 8, 4)

    -- Lever
    love.graphics.setColor(0.6, 0.1, 0.1)
    love.graphics.rectangle("fill", mx + gridSize - 6, my + gridSize * 0.9, 4, gridSize * 0.6)
    love.graphics.circle("fill", mx + gridSize - 4, my + gridSize * 0.85, 6)
  end
end

function M.drawShopCounter(x, y, gridSize, width)
  -- Counter base
  love.graphics.setColor(0.5, 0.35, 0.2)
  love.graphics.rectangle("fill", x * gridSize, y * gridSize, width * gridSize, gridSize)

  -- Counter top
  love.graphics.setColor(0.7, 0.6, 0.5)
  love.graphics.rectangle("fill", x * gridSize, y * gridSize, width * gridSize, 8)

  -- Display cases
  for i = 0, width - 1 do
    love.graphics.setColor(0.8, 0.85, 0.9, 0.5)
    love.graphics.rectangle("fill", x * gridSize + i * gridSize + 6, y * gridSize + 12, gridSize - 12, gridSize - 16)
    love.graphics.setColor(0.6, 0.5, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x * gridSize + i * gridSize + 6, y * gridSize + 12, gridSize - 12, gridSize - 16)
  end
end

function M.drawSculpture(x, y, gridSize)
  local cx = x * gridSize + gridSize / 2
  local cy = y * gridSize + gridSize / 2

  -- Pedestal
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.rectangle("fill", cx - 12, cy + 5, 24, 10)

  -- Abstract sculpture (stacked shapes)
  love.graphics.setColor(0.85, 0.75, 0.3)
  love.graphics.polygon("fill",
    cx, cy - 15,
    cx + 10, cy,
    cx - 10, cy)
  love.graphics.setColor(0.75, 0.65, 0.25)
  love.graphics.rectangle("fill", cx - 8, cy, 16, 8)
end

function M.drawCasinoInterior(gameState, time)
  local interior = buildings.interiors[gameState.location]
  if not interior then return end

  local gridSize = GRID_SIZE

  -- Draw floor zones first
  if interior.zones then
    for _, zone in ipairs(interior.zones) do
      M.drawFloorZone(zone, gridSize)
    end
  end

  -- Walls
  love.graphics.setColor(0.3, 0.2, 0.15)
  love.graphics.setLineWidth(6)
  love.graphics.rectangle("line", 0, 0, interior.width * gridSize, interior.height * gridSize)

  -- Chihuly ceiling in foyer
  M.drawChihulyCeiling(interior.width * gridSize / 2, gridSize * 1.5, time)

  -- Decorations
  if interior.decorations then
    for _, deco in ipairs(interior.decorations) do
      if deco.type == "fountain" then
        M.drawFountain(deco.x * gridSize + gridSize / 2, deco.y * gridSize + gridSize / 2, time)
      elseif deco.type == "sculpture" then
        M.drawSculpture(deco.x, deco.y, gridSize)
      elseif deco.type == "counter" then
        M.drawShopCounter(deco.x, deco.y, gridSize, deco.w or 4)
      elseif deco.type == "slots" then
        M.drawSlotMachines(deco.x, deco.y, gridSize, time)
      elseif deco.type == "blackjack_table" then
        M.drawBlackjackTable(deco.x, deco.y, gridSize)
      elseif deco.type == "roulette_table" then
        M.drawRouletteTable(deco.x, deco.y, gridSize, time)
      end
    end
  end

  -- Exit door
  love.graphics.setColor(0.3, 0.6, 0.3)
  love.graphics.rectangle("fill", interior.exitX * gridSize + 4, interior.exitY * gridSize + 4,
                        gridSize - 8, gridSize - 8)

  -- Portals (semi-transparent markers)
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.25)
      love.graphics.rectangle("fill", portal.x * gridSize, portal.y * gridSize,
                            gridSize * 2, gridSize * 2)

      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf(portal.name, portal.x * gridSize, (portal.y - 0.5) * gridSize,
                          gridSize * 2, "center")
    end
  end

  -- NPCs
  for _, npc in ipairs(gameState.currentNPCs) do
    M.drawNPC(npc)
  end

  M.drawPlayer(gameState.player)
end

return M
