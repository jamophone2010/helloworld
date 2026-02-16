-- hub/elevator.lua
-- Elevator system for navigating between floors of the space station
-- Features animated transition, floor selection menu, and secret floor access

local M = {}
local floors = require("hub.floors")

-- Elevator state
local state = "closed"  -- "closed", "menu", "traveling", "arriving"
local currentFloor = 2
local targetFloor = 2
local menuSelection = 1
local travelTimer = 0
local travelDuration = 1.5
local arriveTimer = 0
local arriveDuration = 0.8
local doorOpenAmt = 0 -- 0 = closed, 1 = open
local doorSpeed = 2.0

-- Visual state
local floorIndicatorY = 0 -- animated floor number display
local shakeAmount = 0
local lightFlicker = 0

-- Fonts (initialized in load)
local titleFont, menuFont, smallFont

-- Callbacks
M.onFloorChange = nil -- called with (newFloorId) when travel completes

function M.load()
  titleFont = love.graphics.newFont("fonts/Exo2-Regular.ttf", 28)
  menuFont = love.graphics.newFont("fonts/Exo2-Regular.ttf", 20)
  smallFont = love.graphics.newFont("fonts/Exo2-Regular.ttf", 14)
  state = "closed"
  doorOpenAmt = 0
end

function M.open(floorId, unlockedQuests)
  currentFloor = floorId
  state = "menu"
  menuSelection = 1
  local availableFloors = floors.getElevatorFloors(unlockedQuests)
  -- Find current floor in list
  for i, id in ipairs(availableFloors) do
    if id == currentFloor then
      menuSelection = i
      break
    end
  end
end

function M.close()
  state = "closed"
end

function M.isOpen()
  return state ~= "closed"
end

function M.isTraveling()
  return state == "traveling" or state == "arriving"
end

function M.getState()
  return state
end

function M.update(dt, unlockedQuests)
  -- Update light flicker
  lightFlicker = lightFlicker + dt * 3
  
  if state == "traveling" then
    travelTimer = travelTimer + dt
    -- Shake during travel
    shakeAmount = math.sin(travelTimer * 20) * 3 * (1 - travelTimer / travelDuration)
    -- Update floor indicator animation
    local progress = travelTimer / travelDuration
    floorIndicatorY = currentFloor + (targetFloor - currentFloor) * progress
    
    if travelTimer >= travelDuration then
      state = "arriving"
      arriveTimer = 0
      currentFloor = targetFloor
      shakeAmount = 0
      -- Notify callback
      if M.onFloorChange then
        M.onFloorChange(currentFloor)
      end
    end
  elseif state == "arriving" then
    arriveTimer = arriveTimer + dt
    -- Open doors
    doorOpenAmt = math.min(1, arriveTimer / arriveDuration)
    if arriveTimer >= arriveDuration then
      state = "closed"
      doorOpenAmt = 0
    end
  end
end

function M.draw(unlockedQuests)
  if state == "closed" then return end
  
  local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
  
  if state == "traveling" then
    M.drawTravelScreen(sw, sh, unlockedQuests)
  elseif state == "arriving" then
    M.drawArrivalScreen(sw, sh)
  elseif state == "menu" then
    M.drawMenu(sw, sh, unlockedQuests)
  end
end

function M.drawTravelScreen(sw, sh, unlockedQuests)
  -- Full black screen with shake
  love.graphics.push()
  love.graphics.translate(math.random() * shakeAmount - shakeAmount/2, math.random() * shakeAmount - shakeAmount/2)
  
  -- Dark elevator interior
  love.graphics.setColor(0.03, 0.03, 0.06)
  love.graphics.rectangle("fill", 0, 0, sw, sh)
  
  -- Metallic wall panels
  for i = 0, 5 do
    local panelX = i * (sw / 6)
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", panelX + 2, 20, sw/6 - 4, sh - 40)
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("line", panelX + 2, 20, sw/6 - 4, sh - 40)
  end
  
  -- Moving light strips (traveling effect)
  local time = love.timer.getTime()
  local direction = targetFloor > currentFloor and 1 or -1
  for i = 0, 8 do
    local stripY = ((time * direction * 300 + i * (sh / 8)) % sh)
    local alpha = 0.3 + 0.2 * math.sin(time * 4 + i)
    love.graphics.setColor(0.2, 0.6, 1.0, alpha)
    love.graphics.rectangle("fill", 0, stripY, sw, 3)
  end
  
  -- Space station graphic (right side)
  local stationX = sw - 150
  local stationY = sh / 2
  
  -- Draw space station levels (vertical tower) - floor 6 at top, floor 0 at bottom
  -- Only show secret floors if quest is completed
  local showSecrets = unlockedQuests and (unlockedQuests["quest_floor0"] or unlockedQuests["quest_floor6"])
  
  for i = 0, 6 do
    -- Skip secret floors unless unlocked
    if (i == 0 or i == 6) and not showSecrets then
      goto continue
    end
    
    local levelY = stationY + 150 - i * 50
    -- Level platform
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", stationX - 30, levelY - 3, 60, 6, 2)
    love.graphics.setColor(0.25, 0.25, 0.35, 0.6)
    love.graphics.rectangle("line", stationX - 30, levelY - 3, 60, 6, 2)
    
    -- Level number
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.4, 0.5, 0.6, 0.5)
    love.graphics.print(i, stationX - 50, levelY - 6)
    
    ::continue::
  end
  
  -- Central elevator shaft
  love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
  love.graphics.rectangle("fill", stationX - 8, stationY - 160, 16, 320, 3)
  love.graphics.setColor(0.2, 0.4, 0.6, 0.4)
  love.graphics.rectangle("line", stationX - 8, stationY - 160, 16, 320, 3)
  
  -- Flashing dot at current position (inverted so higher floors are higher up)
  local dotY = stationY + 150 - floorIndicatorY * 50
  local pulse = 0.5 + 0.5 * math.sin(time * 4)
  love.graphics.setColor(1, 1, 1, pulse)
  love.graphics.circle("fill", stationX, dotY, 6)
  love.graphics.setColor(0.6, 0.8, 1.0, pulse * 0.5)
  love.graphics.circle("fill", stationX, dotY, 10)
  
  -- Floor indicator display (center top)
  local indicatorX = sw / 2
  local indicatorY = 60
  
  -- Display panel background
  love.graphics.setColor(0.02, 0.02, 0.04)
  love.graphics.rectangle("fill", indicatorX - 80, indicatorY - 20, 160, 60, 5)
  love.graphics.setColor(0.2, 0.6, 1.0, 0.8)
  love.graphics.rectangle("line", indicatorX - 80, indicatorY - 20, 160, 60, 5)
  
  -- Floor number
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.3, 0.8, 1.0)
  local displayFloor = math.floor(floorIndicatorY + 0.5)
  local floorDef = floors.getFloor(displayFloor)
  local floorName = floorDef and floorDef.name or ("Floor " .. displayFloor)
  love.graphics.printf("F" .. displayFloor, indicatorX - 70, indicatorY - 10, 140, "center")
  
  -- Direction arrow
  love.graphics.setFont(menuFont)
  local arrow = direction > 0 and "▲" or "▼"
  love.graphics.setColor(0.2, 0.6, 1.0, 0.5 + 0.5 * math.sin(time * 8))
  love.graphics.printf(arrow, indicatorX - 40, indicatorY + 50, 80, "center")
  
  -- "In Transit" text
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.5, 0.7, 0.9, 0.5 + 0.3 * math.sin(time * 3))
  love.graphics.printf("IN TRANSIT", 0, sh - 50, sw, "center")
  
  love.graphics.pop()
end

function M.drawArrivalScreen(sw, sh)
  -- Floor reveal with opening doors
  local floorDef = floors.getFloor(currentFloor)
  local scheme = floorDef and floorDef.colorScheme or {bg = {0.03, 0.03, 0.06}, neon = {0.3, 0.6, 1.0}}
  
  -- Background (floor color shows through)
  love.graphics.setColor(scheme.bg[1], scheme.bg[2], scheme.bg[3])
  love.graphics.rectangle("fill", 0, 0, sw, sh)
  
  -- Sliding doors
  local doorWidth = sw / 2 * (1 - doorOpenAmt)
  -- Left door
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", 0, 0, doorWidth, sh)
  love.graphics.setColor(0.15, 0.15, 0.22)
  love.graphics.rectangle("fill", doorWidth - 10, 0, 10, sh)
  -- Right door
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", sw - doorWidth, 0, doorWidth, sh)
  love.graphics.setColor(0.15, 0.15, 0.22)
  love.graphics.rectangle("fill", sw - doorWidth, 0, 10, sh)
  
  -- Neon trim on doors
  local nr, ng, nb = scheme.neon[1], scheme.neon[2], scheme.neon[3]
  love.graphics.setColor(nr, ng, nb, 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.line(doorWidth, 0, doorWidth, sh)
  love.graphics.line(sw - doorWidth, 0, sw - doorWidth, sh)
  love.graphics.setLineWidth(1)
  
  -- Floor name display
  if doorOpenAmt > 0.3 then
    local textAlpha = math.min(1, (doorOpenAmt - 0.3) / 0.4)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(nr, ng, nb, textAlpha)
    love.graphics.printf(floorDef and floorDef.name or "Floor " .. currentFloor, 0, sh/2 - 30, sw, "center")
    love.graphics.setFont(smallFont)
    love.graphics.setColor(nr, ng, nb, textAlpha * 0.7)
    love.graphics.printf(floorDef and floorDef.subtitle or "", 0, sh/2 + 10, sw, "center")
  end
end

function M.drawMenu(sw, sh, unlockedQuests)
  local availableFloors = floors.getElevatorFloors(unlockedQuests)
  
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle("fill", 0, 0, sw, sh)
  
  -- Elevator panel background
  local panelW, panelH = 400, 50 + #availableFloors * 50 + 80
  local panelX = sw/2 - panelW/2
  local panelY = sh/2 - panelH/2
  
  -- Panel body
  love.graphics.setColor(0.05, 0.05, 0.1)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8)
  
  -- Panel border (neon blue)
  love.graphics.setColor(0.2, 0.6, 1.0, 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8)
  love.graphics.setLineWidth(1)
  
  -- Title
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.3, 0.8, 1.0)
  love.graphics.printf("E L E V A T O R", panelX, panelY + 15, panelW, "center")
  
  -- Neon underline
  love.graphics.setColor(0.2, 0.6, 1.0, 0.6)
  love.graphics.rectangle("fill", panelX + 40, panelY + 52, panelW - 80, 2)
  
  -- Floor buttons
  love.graphics.setFont(menuFont)
  local time = love.timer.getTime()
  
  for i, floorId in ipairs(availableFloors) do
    local floorDef = floors.getFloor(floorId)
    local btnY = panelY + 60 + (i - 1) * 50
    local isSelected = (i == menuSelection)
    local isCurrent = (floorId == currentFloor)
    local nr, ng, nb = floorDef.colorScheme.neon[1], floorDef.colorScheme.neon[2], floorDef.colorScheme.neon[3]
    
    if isSelected then
      -- Selected highlight
      love.graphics.setColor(nr, ng, nb, 0.15 + 0.05 * math.sin(time * 4))
      love.graphics.rectangle("fill", panelX + 10, btnY, panelW - 20, 42, 4)
      love.graphics.setColor(nr, ng, nb, 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", panelX + 10, btnY, panelW - 20, 42, 4)
      love.graphics.setLineWidth(1)
    end
    
    -- Floor number indicator
    local numColor = isSelected and {1, 1, 1} or {0.5, 0.5, 0.6}
    love.graphics.setColor(numColor[1], numColor[2], numColor[3])
    love.graphics.printf("F" .. floorId, panelX + 20, btnY + 8, 40, "center")
    
    -- Floor name
    local nameColor = isSelected and {nr, ng, nb} or {0.5, 0.5, 0.6}
    love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3])
    love.graphics.printf(floorDef.name, panelX + 70, btnY + 8, 200, "left")
    
    -- Current floor indicator
    if isCurrent then
      love.graphics.setFont(smallFont)
      love.graphics.setColor(0.3, 1.0, 0.4)
      love.graphics.printf("◄ HERE", panelX + 280, btnY + 12, 100, "center")
      love.graphics.setFont(menuFont)
    end
  end
  
  -- Controls hint
  love.graphics.setFont(smallFont)
  love.graphics.setColor(0.4, 0.5, 0.6)
  love.graphics.printf("↑↓ Select    ENTER Confirm    ESC Close", panelX, panelY + panelH - 30, panelW, "center")
end

function M.keypressed(key, unlockedQuests)
  if state ~= "menu" then return false end
  
  local availableFloors = floors.getElevatorFloors(unlockedQuests)
  
  if key == "up" then
    menuSelection = menuSelection - 1
    if menuSelection < 1 then menuSelection = #availableFloors end
    return true
  elseif key == "down" then
    menuSelection = menuSelection + 1
    if menuSelection > #availableFloors then menuSelection = 1 end
    return true
  elseif key == "return" or key == "space" then
    local selectedFloorId = availableFloors[menuSelection]
    if selectedFloorId ~= currentFloor then
      targetFloor = selectedFloorId
      state = "traveling"
      travelTimer = 0
      floorIndicatorY = currentFloor
      shakeAmount = 0
      -- Longer travel for more floors
      local distance = math.abs(targetFloor - currentFloor)
      travelDuration = 1.0 + distance * 0.3
    else
      state = "closed"
    end
    return true
  elseif key == "escape" then
    state = "closed"
    return true
  end
  
  return false
end

function M.getCurrentFloor()
  return currentFloor
end

function M.setCurrentFloor(floorId)
  currentFloor = floorId
end

return M
