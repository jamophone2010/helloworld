-- mixia/init.lua
-- Multi-level city planet hub (Coruscant/Taris inspired)
-- Daylight theme with elevator between city levels

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local floors = require("mixia.floors")
local buildings = require("mixia.buildings")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil
M.returnToAsteroids = nil

-- Elevator state
local elevatorState = {
  active = false,
  selectedFloor = 3,
  floors = {},
  animationTime = 0
}

function M.load()
  gameState.currentFloor = gameState.currentFloor or 5  -- Start at Skyline Terrace
  gameState.location = "floor"
  gameState.interiorId = nil

  local floorDef = floors.getFloor(gameState.currentFloor)
  local startX = floorDef.elevatorPos.x * 32 + 16
  local startY = floorDef.elevatorPos.y * 32 + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.nearElevator = false
  gameState.collisionMap = floors.createFloorCollisionMap(gameState.currentFloor)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.buildingEntryCooldown = 0
  gameState.transition = nil
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.returnFloor = nil
  gameState.fadeInFromStarfox = false

  gameState.credits = 1000000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false}
  gameState.paused = false
  gameState.animationTime = 0
  gameState.unlockedQuests = gameState.unlockedQuests or {}

  M.setupFloorNPCs(gameState.currentFloor)

  audio.load()
  pauseMenu.load()

  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil
    }
    gameState.fadeInFromStarfox = false
  end
end

-- ═══════════════════════════════════════
-- GETTERS / SETTERS
-- ═══════════════════════════════════════

function M.getCredits() return gameState.credits end
function M.setCredits(amount) gameState.credits = amount end
function M.getNotes() return gameState.notes end
function M.setNotes(amount) gameState.notes = amount end

function M.addNotes(amount)
  gameState.notes = gameState.notes + amount
  currency.save(gameState.notes)
end

function M.spendNotes(amount)
  if gameState.notes >= amount then
    gameState.notes = gameState.notes - amount
    currency.save(gameState.notes)
    return true
  end
  return false
end

function M.getShopItems() return gameState.shopItems end
function M.clearShopItems() gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false} end
function M.setPaused(paused) gameState.paused = paused end

function M.setFadeInFromStarfox(enable)
  gameState.fadeInFromStarfox = enable
end

-- ═══════════════════════════════════════
-- FLOOR MANAGEMENT
-- ═══════════════════════════════════════

function M.setupFloorNPCs(floorId)
  gameState.currentNPCs = {}
  local floorDef = floors.getFloor(floorId)
  if floorDef and floorDef.npcs then
    for _, npcData in ipairs(floorDef.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue))
    end
  end
end

function M.changeFloor(newFloor)
  gameState.currentFloor = newFloor
  gameState.location = "floor"
  gameState.interiorId = nil

  local floorDef = floors.getFloor(newFloor)
  if floorDef then
    gameState.player.gridX = floorDef.elevatorPos.x
    gameState.player.gridY = floorDef.elevatorPos.y
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y

    gameState.collisionMap = floors.createFloorCollisionMap(newFloor)
    gameState.currentPortals = nil
    M.setupFloorNPCs(newFloor)
  end

  elevatorState.active = false
end

function M.enterBuilding(buildingId)
  local interior = buildings.getInterior(buildingId)
  if not interior then return end

  gameState.interiorId = buildingId
  gameState.location = "interior"
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = buildings.createInteriorCollisionMap(buildingId)
  gameState.currentPortals = interior.portals

  gameState.currentNPCs = {}
  if interior.npcs then
    for _, npcData in ipairs(interior.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue))
    end
  end
end

function M.exitBuilding()
  gameState.transition = {
    phase = "out",
    timer = 0,
    duration = 0.2,
    callback = function()
      M.doExitBuilding()
    end
  }
end

function M.doExitBuilding()
  gameState.location = "floor"
  local buildingId = gameState.interiorId
  gameState.interiorId = nil
  gameState.buildingEntryCooldown = 0.5

  local floorDef = floors.getFloor(gameState.currentFloor)
  if floorDef then
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY + 1
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
      gameState.returnPosition = nil
    else
      if floorDef.buildings then
        for _, b in ipairs(floorDef.buildings) do
          if b.interior == buildingId then
            gameState.player.gridX = b.doorX
            gameState.player.gridY = b.doorY + 1
            gameState.player.x = gameState.player.gridX * 32 + 16
            gameState.player.y = gameState.player.gridY * 32 + 16
            gameState.player.targetX = gameState.player.x
            gameState.player.targetY = gameState.player.y
            break
          end
        end
      end
    end

    gameState.collisionMap = floors.createFloorCollisionMap(gameState.currentFloor)
    gameState.currentPortals = nil
    M.setupFloorNPCs(gameState.currentFloor)
  end
end

-- ═══════════════════════════════════════
-- ELEVATOR
-- ═══════════════════════════════════════

function M.openElevator()
  elevatorState.active = true
  elevatorState.selectedFloor = gameState.currentFloor
  elevatorState.floors = floors.getElevatorFloors(gameState.unlockedQuests)
  elevatorState.animationTime = 0
end

function M.closeElevator()
  elevatorState.active = false
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  if gameState.paused then return end

  gameState.animationTime = gameState.animationTime + dt
  elevatorState.animationTime = elevatorState.animationTime + dt

  if elevatorState.active then
    return
  end

  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player)
  end

  if love.keyboard.isDown("up") then
    player.tryMove(gameState.player, "up", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("down") then
    player.tryMove(gameState.player, "down", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("left") then
    player.tryMove(gameState.player, "left", gameState.collisionMap, gameState.currentNPCs)
  elseif love.keyboard.isDown("right") then
    player.tryMove(gameState.player, "right", gameState.collisionMap, gameState.currentNPCs)
  end

  camera.update(gameState.camera, gameState.player.x, gameState.player.y)

  if gameState.transition then
    gameState.transition.timer = gameState.transition.timer + dt
    if gameState.transition.phase == "out" then
      if gameState.transition.timer >= gameState.transition.duration then
        if gameState.transition.callback then
          gameState.transition.callback()
        end
        gameState.transition.phase = "in"
        gameState.transition.timer = 0
      end
    elseif gameState.transition.phase == "in" then
      if gameState.transition.timer >= gameState.transition.duration then
        gameState.transition = nil
      end
    end
    return
  end

  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then
      gameState.buildingEntryCooldown = 0
    end
  end

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.nearElevator = false

  if gameState.location == "floor" then
    local floorDef = floors.getFloor(gameState.currentFloor)
    if floorDef and floorDef.buildings and gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(floorDef.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY then
          gameState.nearBuildingDoor = b
          local interiorId = b.interior
          gameState.transition = {
            phase = "out",
            timer = 0,
            duration = 0.2,
            callback = function()
              M.enterBuilding(interiorId)
              audio.playPortal()
            end
          }
          break
        end
      end
    end

    if floors.isOnElevator(gameState.currentFloor, gameState.player.gridX, gameState.player.gridY) then
      gameState.nearElevator = true
    end
  else
    if gameState.currentPortals then
      for _, portal in ipairs(gameState.currentPortals) do
        local dx = math.abs(gameState.player.gridX - portal.x)
        local dy = math.abs(gameState.player.gridY - portal.y)
        if dx <= 1 and dy <= 1 then
          gameState.nearbyPortal = portal
          break
        end
      end
    end

    if gameState.interiorId then
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
        M.exitBuilding()
      end
    end
  end

  for _, npcObj in ipairs(gameState.currentNPCs) do
    local npcGridX = npcObj.gridX or npcObj.x
    local npcGridY = npcObj.gridY or npcObj.y
    if math.abs(gameState.player.gridX - npcGridX) <= 1 and
       math.abs(gameState.player.gridY - npcGridY) <= 1 then
      gameState.nearbyNPC = npcObj
      break
    end
  end
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

function M.draw()
  local floorDef = floors.getFloor(gameState.currentFloor)
  local colors = floorDef and floorDef.colorScheme or floors.COLORS

  -- Sky/background based on level
  if gameState.location == "floor" then
    M.drawBackground(floorDef)
  end

  love.graphics.push()
  love.graphics.translate(-gameState.camera.x + love.graphics.getWidth() / 2,
                          -gameState.camera.y + love.graphics.getHeight() / 2)

  if gameState.location == "floor" then
    M.drawFloor(floorDef)
  else
    M.drawInterior()
  end

  player.draw(gameState.player)

  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.draw(npcObj)
  end

  love.graphics.pop()

  M.drawUI()

  if elevatorState.active then
    M.drawElevator()
  end

  if gameState.paused then
    pauseMenu.draw()
  end

  if gameState.transition then
    local alpha = 0
    if gameState.transition.phase == "out" then
      alpha = gameState.transition.timer / gameState.transition.duration
    elseif gameState.transition.phase == "in" then
      alpha = 1 - gameState.transition.timer / gameState.transition.duration
    end
    alpha = math.max(0, math.min(1, alpha))
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  end
end

function M.drawBackground(floorDef)
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  if not floorDef then return end

  local lightLevel = floorDef.lightLevel or 0.8
  local bg = floorDef.colorScheme.bg

  -- Draw sky/ceiling based on level
  if gameState.currentFloor >= 4 then
    -- Upper levels: bright sky with clouds
    love.graphics.setColor(floors.COLORS.sky[1] * lightLevel, floors.COLORS.sky[2] * lightLevel, floors.COLORS.sky[3] * lightLevel)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Sun
    love.graphics.setColor(floors.COLORS.sun[1], floors.COLORS.sun[2], floors.COLORS.sun[3], 0.8)
    love.graphics.circle("fill", screenW - 100, 80, 40)

    -- Clouds
    love.graphics.setColor(floors.COLORS.cloud[1], floors.COLORS.cloud[2], floors.COLORS.cloud[3], 0.6)
    for i = 1, 5 do
      local cx = (i * 250 + gameState.animationTime * 10) % (screenW + 200) - 100
      love.graphics.ellipse("fill", cx, 60 + i * 15, 80, 25)
    end
  elseif gameState.currentFloor == 3 then
    -- Commerce: filtered sunlight
    love.graphics.setColor(bg[1] * lightLevel, bg[2] * lightLevel, bg[3] * lightLevel)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  elseif gameState.currentFloor == 2 then
    -- Industrial: smoggy
    love.graphics.setColor(bg[1] * lightLevel, bg[2] * lightLevel, bg[3] * lightLevel)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    -- Smog overlay
    love.graphics.setColor(0.4, 0.35, 0.3, 0.3)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  else
    -- Lower levels: dark, grimy
    love.graphics.setColor(bg[1] * lightLevel, bg[2] * lightLevel, bg[3] * lightLevel)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

function M.drawFloor(floorDef)
  if not floorDef then return end

  local colors = floorDef.colorScheme
  local lightLevel = floorDef.lightLevel or 0.8

  -- Floor ground
  love.graphics.setColor(colors.bg[1] * 0.9, colors.bg[2] * 0.9, colors.bg[3] * 0.9)
  love.graphics.rectangle("fill", 0, 0, floorDef.width * 32, floorDef.height * 32)

  -- Grid pattern
  love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.1)
  for x = 0, floorDef.width * 32, 32 do
    love.graphics.line(x, 0, x, floorDef.height * 32)
  end
  for y = 0, floorDef.height * 32, 32 do
    love.graphics.line(0, y, floorDef.width * 32, y)
  end

  -- Elevator platform
  local ep = floorDef.elevatorPos
  local pulse = math.sin(gameState.animationTime * 2) * 0.1 + 0.9
  love.graphics.setColor(colors.accent[1] * pulse, colors.accent[2] * pulse, colors.accent[3] * pulse, 0.5)
  love.graphics.rectangle("fill", (ep.x - 1) * 32, (ep.y - 1) * 32, 96, 96)
  love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.8)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", (ep.x - 1) * 32, (ep.y - 1) * 32, 96, 96)

  -- Buildings
  if floorDef.buildings then
    for _, b in ipairs(floorDef.buildings) do
      M.drawBuilding(b, colors, lightLevel)
    end
  end

  -- Paths (subtle highlight)
  if floorDef.paths then
    love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.05)
    for _, path in ipairs(floorDef.paths) do
      love.graphics.rectangle("fill", path.x1 * 32, path.y1 * 32,
        (path.x2 - path.x1 + 1) * 32, (path.y2 - path.y1 + 1) * 32)
    end
  end
end

function M.drawBuilding(b, colors, lightLevel)
  local x = b.x * 32
  local y = b.y * 32
  local w = b.w * 32
  local h = b.h * 32

  -- Building shadow
  love.graphics.setColor(0, 0, 0, 0.2)
  love.graphics.rectangle("fill", x + 4, y + 4, w, h)

  -- Building body
  love.graphics.setColor(b.color[1] * lightLevel, b.color[2] * lightLevel, b.color[3] * lightLevel)
  love.graphics.rectangle("fill", x, y, w, h)

  -- Accent stripe
  love.graphics.setColor(b.accentColor[1], b.accentColor[2], b.accentColor[3])
  love.graphics.rectangle("fill", x, y, w, 8)

  -- Windows
  love.graphics.setColor(colors.light[1], colors.light[2], colors.light[3], 0.7)
  local windowY = y + 16
  for wx = x + 8, x + w - 20, 20 do
    love.graphics.rectangle("fill", wx, windowY, 12, 10)
  end

  -- Door
  love.graphics.setColor(b.accentColor[1] * 0.6, b.accentColor[2] * 0.6, b.accentColor[3] * 0.6)
  love.graphics.rectangle("fill", b.doorX * 32 + 4, b.doorY * 32 - 28, 24, 28)

  -- Building name
  love.graphics.setColor(1, 1, 1, 0.9)
  local font = love.graphics.getFont()
  local textW = font:getWidth(b.name)
  love.graphics.print(b.name, x + w/2 - textW/2, y - 18)
end

function M.drawInterior()
  local interior = buildings.getInterior(gameState.interiorId)
  if not interior then return end

  local floorDef = floors.getFloor(gameState.currentFloor)
  local colors = floorDef and floorDef.colorScheme or {bg = {0.7, 0.7, 0.7}, accent = {0.5, 0.5, 0.5}, light = {1, 1, 1}}
  local lightLevel = floorDef and floorDef.lightLevel or 0.8

  -- Floor
  love.graphics.setColor(colors.bg[1] * 0.8 * lightLevel, colors.bg[2] * 0.8 * lightLevel, colors.bg[3] * 0.8 * lightLevel)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, interior.height * 32)

  -- Walls
  love.graphics.setColor(colors.bg[1] * 0.6, colors.bg[2] * 0.6, colors.bg[3] * 0.6)
  love.graphics.rectangle("fill", 0, 0, interior.width * 32, 32)
  love.graphics.rectangle("fill", 0, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", (interior.width - 1) * 32, 0, 32, interior.height * 32)
  love.graphics.rectangle("fill", 0, (interior.height - 1) * 32, interior.width * 32, 32)

  -- Exit door
  love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.6)
  love.graphics.rectangle("fill", interior.exitX * 32, interior.exitY * 32, 32, 32)

  -- Portals
  if interior.portals then
    for _, portal in ipairs(interior.portals) do
      local px = portal.x * 32
      local py = portal.y * 32
      local pulse = math.sin(gameState.animationTime * 3) * 0.2 + 0.8

      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.3 * pulse)
      love.graphics.circle("fill", px + 16, py + 16, 25)
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], pulse)
      love.graphics.circle("fill", px + 16, py + 16, 18)

      love.graphics.setColor(1, 1, 1)
      local font = love.graphics.getFont()
      local textW = font:getWidth(portal.name)
      love.graphics.print(portal.name, px + 16 - textW/2, py + 40)
    end
  end

  -- Interior name
  love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3])
  love.graphics.print(interior.name, 40, 40)
end

function M.drawElevator()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()

  -- Overlay
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Panel
  local panelW = 350
  local panelH = 400
  local panelX = screenW/2 - panelW/2
  local panelY = screenH/2 - panelH/2

  love.graphics.setColor(0.2, 0.22, 0.25)
  love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
  love.graphics.setColor(0.5, 0.55, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

  -- Title
  love.graphics.setColor(1, 1, 1)
  local title = "CITY TRANSIT"
  local font = love.graphics.getFont()
  local titleW = font:getWidth(title)
  love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

  -- Floor buttons
  local buttonY = panelY + 60
  for i, floorId in ipairs(elevatorState.floors) do
    local floorDef = floors.getFloor(floorId)
    local isSelected = (floorId == elevatorState.selectedFloor)
    local isCurrent = (floorId == gameState.currentFloor)

    -- Button background
    if isSelected then
      love.graphics.setColor(0.4, 0.5, 0.6)
    elseif isCurrent then
      love.graphics.setColor(0.3, 0.4, 0.45)
    else
      love.graphics.setColor(0.25, 0.28, 0.32)
    end
    love.graphics.rectangle("fill", panelX + 20, buttonY, panelW - 40, 45, 5, 5)

    -- Level indicator
    love.graphics.setColor(floorDef.colorScheme.accent[1], floorDef.colorScheme.accent[2], floorDef.colorScheme.accent[3])
    love.graphics.rectangle("fill", panelX + 25, buttonY + 5, 8, 35)

    -- Text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("L" .. floorId .. ": " .. floorDef.name, panelX + 45, buttonY + 8)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(floorDef.subtitle, panelX + 45, buttonY + 25)

    if isCurrent then
      love.graphics.setColor(0.5, 0.8, 0.5)
      love.graphics.print("[HERE]", panelX + panelW - 70, buttonY + 15)
    end

    buttonY = buttonY + 55
  end

  -- Instructions
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.print("UP/DOWN: Select   ENTER: Go   ESC: Close", panelX + 30, panelY + panelH - 35)
end

function M.drawUI()
  local screenW = love.graphics.getWidth()
  local screenH = love.graphics.getHeight()
  local floorDef = floors.getFloor(gameState.currentFloor)

  -- Floor indicator
  if gameState.location == "floor" and floorDef then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 10, 10, 220, 50, 5, 5)
    love.graphics.setColor(floorDef.colorScheme.accent[1], floorDef.colorScheme.accent[2], floorDef.colorScheme.accent[3])
    love.graphics.print("L" .. gameState.currentFloor .. ": " .. floorDef.name, 20, 17)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(floorDef.subtitle, 20, 35)
  elseif gameState.location == "interior" then
    local interior = buildings.getInterior(gameState.interiorId)
    if interior then
      love.graphics.setColor(0, 0, 0, 0.6)
      love.graphics.rectangle("fill", 10, 10, 250, 30, 5, 5)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(interior.name, 20, 17)
    end
  end

  -- Currency
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", screenW - 160, 10, 150, 30, 5, 5)
  love.graphics.setColor(0.9, 0.8, 0.4)
  love.graphics.print("Notes: " .. gameState.notes, screenW - 150, 17)

  -- Prompts
  if gameState.nearElevator and gameState.location == "floor" then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 100, screenH - 60, 200, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to use Transit", screenW/2 - 100, screenH - 50, 200, "center")
  elseif gameState.nearbyPortal then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to enter " .. gameState.nearbyPortal.name, screenW/2 - 120, screenH - 50, 240, "center")
  elseif gameState.nearbyNPC then
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 120, screenH - 60, 240, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press E to talk to " .. gameState.nearbyNPC.name, screenW/2 - 120, screenH - 50, 240, "center")
  end

  -- Dialogue
  if gameState.dialogueBox then
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.5, 0.55, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 50, screenH - 150, screenW - 100, 120, 10, 10)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.print(gameState.dialogueBox.npc, 70, screenH - 140)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(gameState.dialogueBox.text, 70, screenH - 115, screenW - 140, "left")
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Press E to close", 70, screenH - 50)
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

function M.keypressed(key)
  if gameState.paused then
    pauseMenu.keypressed(key)
    return
  end

  if elevatorState.active then
    if key == "up" then
      local idx = 1
      for i, f in ipairs(elevatorState.floors) do
        if f == elevatorState.selectedFloor then idx = i break end
      end
      if idx > 1 then
        elevatorState.selectedFloor = elevatorState.floors[idx - 1]
      end
    elseif key == "down" then
      local idx = 1
      for i, f in ipairs(elevatorState.floors) do
        if f == elevatorState.selectedFloor then idx = i break end
      end
      if idx < #elevatorState.floors then
        elevatorState.selectedFloor = elevatorState.floors[idx + 1]
      end
    elseif key == "return" or key == "space" then
      if elevatorState.selectedFloor ~= gameState.currentFloor then
        M.changeFloor(elevatorState.selectedFloor)
        audio.playPortal()
      else
        M.closeElevator()
      end
    elseif key == "escape" then
      M.closeElevator()
    end
    return
  end

  if key == "escape" then
    if gameState.dialogueBox then
      gameState.dialogueBox = nil
    else
      gameState.paused = true
    end
    return
  end

  if gameState.dialogueBox then
    if key == "e" or key == "escape" or key == "return" then
      gameState.dialogueBox = nil
    end
    return
  end

  if key == "e" then
    if gameState.nearElevator and gameState.location == "floor" then
      M.openElevator()
      audio.playPortal()
      return
    end

    if gameState.nearbyPortal then
      audio.playPortal()
      gameState.returnLocation = gameState.location
      gameState.returnFloor = gameState.currentFloor
      gameState.returnPosition = {
        gridX = gameState.player.gridX,
        gridY = gameState.player.gridY
      }
      if M.switchToGame then
        M.switchToGame(gameState.nearbyPortal.game)
      end
      return
    end

    if gameState.nearbyNPC then
      gameState.dialogueBox = {
        npc = gameState.nearbyNPC.name,
        text = gameState.nearbyNPC.dialogue
      }
      return
    end
  end
end

-- ═══════════════════════════════════════
-- RETURN FROM GAMES
-- ═══════════════════════════════════════

function M.returnFromGame()
  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil
    }
    gameState.fadeInFromStarfox = false
  end

  if gameState.returnLocation and gameState.returnLocation ~= "floor" then
    if gameState.returnFloor then
      gameState.currentFloor = gameState.returnFloor
    end
    M.enterBuilding(gameState.interiorId or gameState.returnLocation)
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
    end
  else
    if gameState.returnFloor then
      M.changeFloor(gameState.returnFloor)
    else
      M.changeFloor(gameState.currentFloor)
    end
  end
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.returnFloor = nil
end

return M
