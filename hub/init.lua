-- hub/init.lua (REWRITTEN)
-- Multi-floor space station hub with elevator system
-- Replaces the old outdoor town with a 7-floor neon Coruscant station

local M = {}

local player = require("hub.player")
local camera = require("hub.camera")
local audio = require("hub.audio")
local ui = require("hub.ui")
local buildings = require("hub.buildings")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")
local floors = require("hub.floors")
local elevator = require("hub.elevator")
local spaceships = require("hub.spaceships")
local tutorial = require("hub.tutorial")
local prototypeEvent = require("hub.prototype_event")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil

function M.load()
  gameState.currentFloor = gameState.currentFloor or 2   -- Use saved floor or default to Floor 2
  gameState.location = "floor" -- "floor" or interior id like "casino"
  gameState.interiorId = nil   -- Which interior we're in (nil = on floor)

  -- Player starts at elevator center on Floor 2
  local floorDef = floors.getFloor(gameState.currentFloor)
  local startX = floorDef.elevatorPos.x * 32 + 16
  local startY = floorDef.elevatorPos.y * 32 + 16
  gameState.player = player.new(startX, startY)
  gameState.camera = camera.new()

  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil  -- NEW: nearby building door
  gameState.nearElevator = false    -- NEW: near elevator pad
  gameState.collisionMap = floors.createFloorCollisionMap(gameState.currentFloor)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.lastKeyPress = 0
  gameState.buildingEntryCooldown = 0  -- Prevent immediate re-entry
  gameState.transition = nil  -- {phase, timer, duration, callback, color} for fade transitions
  gameState.returnLocation = nil
  gameState.returnPosition = nil
  gameState.returnFloor = nil       -- NEW: track floor when entering game
  gameState.fadeInFromStarfox = false  -- NEW: trigger fade-in if returning from starfox
  gameState.credits = 1000
  gameState.notes = currency.load()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false}
  gameState.paused = false
  gameState.playerName = "Player"
  gameState.activeSlot = nil
  gameState.timePlayed = 0
  gameState.sessionStart = love.timer.getTime()
  gameState.highScores = {}
  gameState.visitedPortalLevels = {}
  gameState.selectedShip = "starwing"
  gameState.animationTime = 0
  gameState.hasMegaAntenna = false
  gameState.hasPowerAmplifier = false

  -- NEW: Multi-floor state (preserve if set before load, e.g. from save data)
  gameState.purchasedShips = gameState.purchasedShips or {starwing = true}
  gameState.unlockedQuests = gameState.unlockedQuests or {}
  gameState.elevatorActive = false               -- Is elevator UI showing

  -- Setup NPCs for starting floor
  M.setupFloorNPCs(gameState.currentFloor)

  audio.load()
  ui.load()
  pauseMenu.load()
  elevator.load()

  -- Elevator callback
  elevator.onFloorChange = function(newFloor)
    M.changeFloor(newFloor)
  end
  
  -- Start with fade-in if returning from starfox
  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil,
      color = {1, 1, 1}  -- White fade
    }
    gameState.fadeInFromStarfox = false
  end
end

-- ═══════════════════════════════════════
-- GETTERS / SETTERS (same API as before)
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
function M.clearShopItems() gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false, scan = false} end
function M.setPaused(paused) gameState.paused = paused end
function M.getPlayerName() return gameState.playerName end
function M.setPlayerName(name) gameState.playerName = name or "Player" end
function M.getActiveSlot() return gameState.activeSlot end
function M.setActiveSlot(slot) gameState.activeSlot = slot end

function M.getTimePlayed()
  return gameState.timePlayed + (love.timer.getTime() - gameState.sessionStart)
end

function M.setFadeInFromStarfox(enable)
  gameState.fadeInFromStarfox = enable
end

function M.setTimePlayed(seconds)
  gameState.timePlayed = seconds or 0
  gameState.sessionStart = love.timer.getTime()
end

function M.getHighScores() return gameState.highScores end
function M.setHighScores(scores) gameState.highScores = scores or {} end

function M.getSelectedShip() return gameState.selectedShip or "starwing" end
function M.setSelectedShip(id)
  gameState.selectedShip = id or "starwing"
  ships.setSelected(id or "starwing")
end

function M.updateHighScore(levelId, score)
  if score > (gameState.highScores[levelId] or 0) then
    gameState.highScores[levelId] = score
  end
end

function M.getVisitedPortalLevels() return gameState.visitedPortalLevels or {} end
function M.setVisitedPortalLevels(levels) gameState.visitedPortalLevels = levels or {} end
function M.markPortalLevelVisited(levelId)
  if not gameState.visitedPortalLevels then
    gameState.visitedPortalLevels = {}
  end
  gameState.visitedPortalLevels[levelId] = true
end

function M.hasMegaAntenna() return gameState.hasMegaAntenna end
function M.setMegaAntenna(value) gameState.hasMegaAntenna = value end
function M.hasPowerAmplifier() return gameState.hasPowerAmplifier end
function M.setPowerAmplifier(value) gameState.hasPowerAmplifier = value end

-- NEW: Multi-floor getters/setters
function M.getPurchasedShips() return gameState.purchasedShips end
function M.setPurchasedShips(ships_table) gameState.purchasedShips = ships_table or {starwing = true} end
function M.getCurrentFloor() return gameState.currentFloor end
function M.setCurrentFloor(floor) gameState.currentFloor = floor or 2 end
function M.getUnlockedQuests() return gameState.unlockedQuests end
function M.setUnlockedQuests(quests) gameState.unlockedQuests = quests or {} end

-- ═══════════════════════════════════════
-- FLOOR MANAGEMENT
-- ═══════════════════════════════════════

function M.setupFloorNPCs(floorId)
  gameState.currentNPCs = {}
  local floorDef = floors.getFloor(floorId)
  if floorDef and floorDef.npcs then
    for _, npcData in ipairs(floorDef.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
    end
  end
  -- Add tutorial Associate NPC if tutorial is active on this floor
  if tutorial.active and tutorial.getAssociateNPC() then
    table.insert(gameState.currentNPCs, tutorial.getAssociateNPC())
  end
end

function M.startTutorial()
  -- Start the Associate NPC tutorial on Floor 4
  tutorial.start(gameState)
  -- Add Associate to current NPCs
  if tutorial.getAssociateNPC() then
    table.insert(gameState.currentNPCs, tutorial.getAssociateNPC())
  end
  tutorial.onComplete = function()
    -- Tutorial finished, remove Associate from NPCs
    if tutorial.getAssociateNPC() then
      for i, n in ipairs(gameState.currentNPCs) do
        if n == tutorial.getAssociateNPC() then
          table.remove(gameState.currentNPCs, i)
          break
        end
      end
    end
    -- After tutorial, start the Prototype breach event
    -- Associate walks into a building; use a nearby building door as the entry point
    local floorDef = floors.getFloor(gameState.currentFloor)
    local doorX, doorY = 10, 5  -- Default fallback
    if floorDef and floorDef.buildings then
      for _, b in ipairs(floorDef.buildings) do
        if b.doorX and b.doorY then
          doorX, doorY = b.doorX, b.doorY
          break
        end
      end
    end
    M.startPrototypeEvent(doorX, doorY)
  end
end

function M.startPrototypeEvent(doorX, doorY)
  local prototype = require("starfox.prototype")
  if prototype.questStarted then return end

  prototypeEvent.changeFloor = function(floorId)
    M.changeFloor(floorId)
    -- Add event NPCs to the floor
    if prototypeEvent.associateNPC then
      table.insert(gameState.currentNPCs, prototypeEvent.associateNPC)
    end
    if prototypeEvent.directorNPC then
      table.insert(gameState.currentNPCs, prototypeEvent.directorNPC)
    end
    if prototypeEvent.medicNPC then
      table.insert(gameState.currentNPCs, prototypeEvent.medicNPC)
    end
    if prototypeEvent.engineer1NPC then
      table.insert(gameState.currentNPCs, prototypeEvent.engineer1NPC)
    end
    if prototypeEvent.engineer2NPC then
      table.insert(gameState.currentNPCs, prototypeEvent.engineer2NPC)
    end
  end

  prototypeEvent.playerName = gameState.playerName

  prototypeEvent.onComplete = function()
    -- Event finished, set up the quest in game state
    gameState.unlockedQuests["the_prototype"] = true
  end

  prototypeEvent.start(doorX, doorY)
end

function M.changeFloor(newFloor)
  gameState.currentFloor = newFloor
  gameState.location = "floor"
  gameState.interiorId = nil

  local floorDef = floors.getFloor(newFloor)
  if floorDef then
    -- Position player at elevator center
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

  -- Reset spaceships when changing floors
  spaceships.reset()
  gameState.elevatorActive = false
end

function M.enterBuilding(buildingId)
  local interior = buildings.getInterior(buildingId)
  if not interior then return end

  gameState.interiorId = buildingId

  -- Store current position (door location) for exit
  gameState.returnPosition = {gridX = gameState.player.gridX, gridY = gameState.player.gridY}

  -- Special locations use their own game module
  if buildingId == "casino" then
    gameState.location = "casino"
  else
    gameState.location = "interior"
  end

  -- Position player at exit (they entered from outside)
  gameState.player.gridX = interior.exitX
  gameState.player.gridY = interior.exitY - 1
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y

  gameState.collisionMap = buildings.createInteriorCollisionMap(buildingId)
  gameState.currentPortals = interior.portals

  -- Setup interior NPCs
  gameState.currentNPCs = {}
  if interior.npcs then
    for _, npcData in ipairs(interior.npcs) do
      table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue, npcData.gender, npcData))
    end
  end
end

function M.exitBuilding()
  -- Start fade-out transition, then return to floor
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
  -- Return to the current floor
  gameState.location = "floor"
  local buildingId = gameState.interiorId
  gameState.interiorId = nil
  gameState.buildingEntryCooldown = 0.5  -- 0.5 second cooldown to prevent re-entry

  local floorDef = floors.getFloor(gameState.currentFloor)
  if floorDef then
    -- Use stored door position if available, spawn one tile below (in front of) the door
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY + 1  -- One tile below door
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
      gameState.returnPosition = nil
    else
      -- Fallback: find the building door and spawn one tile below
      if floorDef.buildings then
        for _, b in ipairs(floorDef.buildings) do
          if b.interior == buildingId then
            gameState.player.gridX = b.doorX
            gameState.player.gridY = b.doorY + 1  -- One tile below door
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
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt)
  if gameState.paused then
    pauseMenu.update(dt)
    return
  end

  -- Update animation time
  gameState.animationTime = gameState.animationTime + dt

  -- Update tutorial if active
  if tutorial.active then
    tutorial.update(dt, gameState)
  end

  -- Update prototype event if active
  if prototypeEvent.active then
    prototypeEvent.update(dt, gameState)
  end

  -- Update elevator if active
  if gameState.elevatorActive then
    elevator.update(dt)
    if elevator.getState() == "closed" then
      gameState.elevatorActive = false
    end
    return  -- Don't update player movement while elevator is active
  end

  -- Update spaceships (for window animation)
  spaceships.update(dt)

  -- Update player
  player.update(gameState.player, dt, gameState.collisionMap)

  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)

  -- Update NPCs (wandering behavior)
  for _, npcObj in ipairs(gameState.currentNPCs) do
    npc.update(npcObj, dt, gameState.collisionMap, gameState.currentNPCs, gameState.player)
  end

  -- Continuous movement
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

  -- Update building transition
  if gameState.transition then
    gameState.transition.timer = gameState.transition.timer + dt
    if gameState.transition.phase == "out" then
      -- Fading to black
      if gameState.transition.timer >= gameState.transition.duration then
        -- Execute the actual enter/exit
        if gameState.transition.callback then
          gameState.transition.callback()
        end
        -- Switch to fade-in phase
        gameState.transition.phase = "in"
        gameState.transition.timer = 0
      end
    elseif gameState.transition.phase == "in" then
      -- Fading back from black
      if gameState.transition.timer >= gameState.transition.duration then
        gameState.transition = nil
      end
    end
    return  -- Don't update player/proximity during transition
  end

  -- Update building entry cooldown
  if gameState.buildingEntryCooldown > 0 then
    gameState.buildingEntryCooldown = gameState.buildingEntryCooldown - dt
    if gameState.buildingEntryCooldown < 0 then
      gameState.buildingEntryCooldown = 0
    end
  end

  -- Reset proximity flags
  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.nearBuildingDoor = nil
  gameState.nearElevator = false

  if gameState.location == "floor" then
    -- Check nearby building doors (only if cooldown expired and no transition)
    local floorDef = floors.getFloor(gameState.currentFloor)
    if floorDef and floorDef.buildings and gameState.buildingEntryCooldown <= 0 and not gameState.transition then
      for _, b in ipairs(floorDef.buildings) do
        if gameState.player.gridX == b.doorX and gameState.player.gridY == b.doorY then
          gameState.nearBuildingDoor = b
          -- Start fade-out transition, then enter building
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

    -- Check elevator proximity
    if floors.isOnElevator(gameState.currentFloor, gameState.player.gridX, gameState.player.gridY) then
      gameState.nearElevator = true
    end

    -- Check auto-enter building (walk onto door tile)
    -- (only if pressing E, not auto)
  else
    -- Inside a building
    -- Check for nearby portals
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

    -- Check for nearby NPCs
    for _, npcObj in ipairs(gameState.currentNPCs) do
      local npcGridX = npcObj.gridX or npcObj.x
      local npcGridY = npcObj.gridY or npcObj.y
      if math.abs(gameState.player.gridX - npcGridX) <= 1 and
         math.abs(gameState.player.gridY - npcGridY) <= 1 then
        gameState.nearbyNPC = npcObj
        break
      end
    end

    -- Check building exit
    if gameState.interiorId then
      if buildings.isAtExit(gameState.player.gridX, gameState.player.gridY, gameState.interiorId) then
        M.exitBuilding()
      end
    end
  end

  -- Floor NPCs proximity (when on floor, not in building)
  if gameState.location == "floor" then
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
end

-- ═══════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════

function M.draw()
  ui.draw(gameState, gameState.animationTime)

  -- Draw elevator overlay
  if gameState.elevatorActive then
    elevator.draw()
  end

  -- Draw pause menu if paused
  if gameState.paused then
    pauseMenu.draw()
  end

  -- Draw tutorial overlay if active
  if tutorial.active then
    tutorial.draw(gameState.animationTime, gameState.camera.x, gameState.camera.y)
  end

  -- Draw prototype event overlay if active
  if prototypeEvent.active then
    prototypeEvent.draw(gameState.animationTime, gameState.camera.x, gameState.camera.y)
  end

  -- Draw building transition fade overlay
  if gameState.transition then
    local alpha = 0
    if gameState.transition.phase == "out" then
      alpha = gameState.transition.timer / gameState.transition.duration
    elseif gameState.transition.phase == "in" then
      alpha = 1 - gameState.transition.timer / gameState.transition.duration
    end
    alpha = math.max(0, math.min(1, alpha))
    local color = gameState.transition.color or {0, 0, 0}
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

function M.textinput(text)
  if gameState.paused then
    pauseMenu.textinput(text)
  end
end

function M.keypressed(key)
  -- Handle tutorial input first
  if tutorial.active then
    if tutorial.keypressed(key) then
      return  -- Tutorial consumed the input
    end
    -- If tutorial is blocking (dialogue/choices visible), don't process other input
    if tutorial.isBlockingInput() then
      return
    end
  end

  -- Handle prototype event input
  if prototypeEvent.active then
    if prototypeEvent.keypressed(key) then
      return
    end
    if prototypeEvent.isBlockingInput() then
      return
    end
  end

  -- Handle pause menu
  if gameState.paused then
    pauseMenu.keypressed(key)
    return
  end

  -- Handle elevator
  if gameState.elevatorActive then
    elevator.keypressed(key)
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
    -- Elevator - check tutorial intercept first
    if gameState.nearElevator and gameState.location == "floor" then
      if tutorial.active and tutorial.onElevatorAttempt(gameState) then
        return  -- Tutorial intercepted the elevator
      end
      gameState.elevatorActive = true
      elevator.open(gameState.currentFloor, gameState.unlockedQuests)
      audio.playPortal()
      return
    end

    -- Portal interaction (inside buildings)
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

    -- NPC dialogue
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
  -- Set up fade-in if returning from starfox
  if gameState.fadeInFromStarfox then
    gameState.transition = {
      phase = "in",
      timer = 0,
      duration = 0.5,
      callback = nil,
      color = {1, 1, 1}  -- White fade
    }
    gameState.fadeInFromStarfox = false
  end

  if gameState.returnLocation and gameState.returnLocation ~= "floor" then
    -- Was inside a building - re-enter it
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
    -- Was on a floor
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
