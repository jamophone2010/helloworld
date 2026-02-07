local M = {}

local player = require("hub.player")
local portals = require("hub.portals")
local camera = require("hub.camera")
local audio = require("hub.audio")
local ui = require("hub.ui")
local buildings = require("hub.buildings")
local npc = require("hub.npc")
local currency = require("hub.currency")
local pauseMenu = require("hub.pause_menu")
local ships = require("starfox.ships")

local gameState = {}

M.switchToGame = nil
M.goToMainMenu = nil

function M.load()
  gameState.location = "outdoor" -- or interior name
  gameState.player = player.new(12 * 32 + 16, 18 * 32 + 16)
  gameState.camera = camera.new()
  gameState.nearbyPortal = nil
  gameState.nearbyNPC = nil
  gameState.collisionMap = buildings.createCollisionMap(gameState.location, false)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
  gameState.dialogueBox = nil
  gameState.lastKeyPress = 0
  gameState.returnLocation = nil -- Track where to return after a game
  gameState.returnPosition = nil -- Track exact position when entering game
  gameState.credits = 1000000 -- Global casino credits
  gameState.notes = currency.load() -- Persistent Notes currency
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false} -- Items to apply to StarFox
  gameState.paused = false -- Pause menu state
  gameState.playerName = "Player" -- Player's chosen name
  gameState.activeSlot = nil -- Which save slot is active (nil = new/unsaved game)
  gameState.timePlayed = 0 -- Total time played in seconds
  gameState.sessionStart = love.timer.getTime() -- When this session started
  gameState.highScores = {} -- High scores per StarFox level {levelId = score}
  gameState.selectedShip = "starwing" -- Currently selected ship for StarFox
  gameState.animationTime = 0 -- Global animation timer for casino effects
  gameState.hasMegaAntenna = false -- Dropped by Inner Ring Boss, unlocks Middle Ring
  gameState.hasPowerAmplifier = false -- Dropped by Middle Ring Boss, unlocks Outer Ring

  audio.load()
  ui.load()
  pauseMenu.load()
end

function M.getCredits()
  return gameState.credits
end

function M.setCredits(amount)
  gameState.credits = amount
end

function M.getNotes()
  return gameState.notes
end

function M.setNotes(amount)
  gameState.notes = amount
end

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

function M.getShopItems()
  return gameState.shopItems
end

function M.clearShopItems()
  gameState.shopItems = {lives = 0, bombs = 0, health = 0, laser = false}
end

function M.setPaused(paused)
  gameState.paused = paused
end

function M.getPlayerName()
  return gameState.playerName
end

function M.setPlayerName(name)
  gameState.playerName = name or "Player"
end

function M.getActiveSlot()
  return gameState.activeSlot
end

function M.setActiveSlot(slot)
  gameState.activeSlot = slot
end

function M.getTimePlayed()
  -- Return accumulated time plus current session time
  return gameState.timePlayed + (love.timer.getTime() - gameState.sessionStart)
end

function M.setTimePlayed(seconds)
  gameState.timePlayed = seconds or 0
  gameState.sessionStart = love.timer.getTime()
end

function M.getHighScores()
  return gameState.highScores
end

function M.setHighScores(scores)
  gameState.highScores = scores or {}
end

function M.getSelectedShip()
  return gameState.selectedShip or "starwing"
end

function M.setSelectedShip(id)
  gameState.selectedShip = id or "starwing"
  ships.setSelected(id or "starwing")
end

function M.updateHighScore(levelId, score)
  if score > (gameState.highScores[levelId] or 0) then
    gameState.highScores[levelId] = score
  end
end

function M.hasMegaAntenna()
  return gameState.hasMegaAntenna
end

function M.setMegaAntenna(value)
  gameState.hasMegaAntenna = value
end

function M.hasPowerAmplifier()
  return gameState.hasPowerAmplifier
end

function M.setPowerAmplifier(value)
  gameState.hasPowerAmplifier = value
end

function M.update(dt)
  -- Don't update game logic when paused
  if gameState.paused then
    return
  end

  -- Update animation timer
  gameState.animationTime = gameState.animationTime + dt

  player.update(gameState.player, dt, gameState.collisionMap)
  
  -- Check if running (Z key held)
  local isRunning = love.keyboard.isDown("z")
  player.setRunning(gameState.player, isRunning)
  
  -- Continuous movement with held keys
  local moved = false
  if love.keyboard.isDown("up") then
    moved = player.tryMove(gameState.player, "up", gameState.collisionMap) or moved
  elseif love.keyboard.isDown("down") then
    moved = player.tryMove(gameState.player, "down", gameState.collisionMap) or moved
  elseif love.keyboard.isDown("left") then
    moved = player.tryMove(gameState.player, "left", gameState.collisionMap) or moved
  elseif love.keyboard.isDown("right") then
    moved = player.tryMove(gameState.player, "right", gameState.collisionMap) or moved
  end
  
  camera.update(gameState.camera, gameState.player.x, gameState.player.y)

  -- Check for nearby portals
  gameState.nearbyPortal = portals.getNearbyPortal(gameState.player, gameState.currentPortals)
  
  -- Check for nearby NPCs
  gameState.nearbyNPC = nil
  for _, npc in ipairs(gameState.currentNPCs) do
    if math.abs(gameState.player.gridX - npc.x) <= 1 and 
       math.abs(gameState.player.gridY - npc.y) <= 1 then
      gameState.nearbyNPC = npc
      break
    end
  end
  
  -- Check if exiting building
  if gameState.location ~= "outdoor" then
    local interior = buildings.interiors[gameState.location]
    if interior and gameState.player.gridX == interior.exitX and gameState.player.gridY == interior.exitY then
      M.exitBuilding()
    end
  end
  
  -- Check if entering building (outdoor only)
  if gameState.location == "outdoor" then
    local building = buildings.getBuilding(gameState.player.gridX, gameState.player.gridY)
    if building then
      M.enterBuilding(building.interior)
    end
  end
end

function M.draw()
  ui.draw(gameState, gameState.animationTime)

  -- Draw pause menu if paused
  if gameState.paused then
    pauseMenu.draw()
  end
end

function M.keypressed(key)
  -- Handle pause menu
  if gameState.paused then
    pauseMenu.keypressed(key)
    return
  end
  
  if key == "escape" then
    gameState.paused = true
    return
  end
  
  if gameState.dialogueBox then
    gameState.dialogueBox = nil
    return
  end
  
  if key == "e" then
    -- Check for building entry (outdoor only)
    if gameState.location == "outdoor" then
      local building = buildings.getBuilding(gameState.player.gridX, gameState.player.gridY)
      if building then
        M.enterBuilding(building.interior)
        audio.playPortal()
        return
      end
    end
    
    -- Check for portal entry
    local enteredPortal = portals.getEnteredPortal(gameState.player, gameState.currentPortals)
    if enteredPortal then
      audio.playPortal()
      gameState.returnLocation = gameState.location
      gameState.returnPosition = {
        gridX = gameState.player.gridX,
        gridY = gameState.player.gridY
      }
      if M.switchToGame then
        M.switchToGame(enteredPortal.game)
      end
      return
    end
    
    -- Check for NPC dialogue
    if gameState.nearbyNPC then
      gameState.dialogueBox = {
        npc = gameState.nearbyNPC.name,
        text = gameState.nearbyNPC.dialogue
      }
      return
    end
  end
end

function M.enterBuilding(interiorName)
  gameState.location = interiorName
  local interior = buildings.interiors[interiorName]
  
  if interior then
    gameState.player.gridX = interior.exitX
    gameState.player.gridY = interior.exitY - 1
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.collisionMap = buildings.createCollisionMap(interiorName, true)
    gameState.currentPortals = interior.portals
    
    -- Setup NPCs
    gameState.currentNPCs = {}
    if interior.npcs then
      for _, npcData in ipairs(interior.npcs) do
        table.insert(gameState.currentNPCs, npc.new(npcData.name, npcData.x, npcData.y, npcData.dialogue))
      end
    end
  end
end

function M.exitBuilding()
  gameState.location = "outdoor"
  gameState.player.gridX = 12
  gameState.player.gridY = 18
  gameState.player.x = gameState.player.gridX * 32 + 16
  gameState.player.y = gameState.player.gridY * 32 + 16
  gameState.player.targetX = gameState.player.x
  gameState.player.targetY = gameState.player.y
  gameState.collisionMap = buildings.createCollisionMap("outdoor", false)
  gameState.currentPortals = nil
  gameState.currentNPCs = {}
end

function M.returnFromGame()
  if gameState.returnLocation and gameState.returnLocation ~= "outdoor" then
    M.enterBuilding(gameState.returnLocation)
    -- Restore exact position if available
    if gameState.returnPosition then
      gameState.player.gridX = gameState.returnPosition.gridX
      gameState.player.gridY = gameState.returnPosition.gridY
      gameState.player.x = gameState.player.gridX * 32 + 16
      gameState.player.y = gameState.player.gridY * 32 + 16
      gameState.player.targetX = gameState.player.x
      gameState.player.targetY = gameState.player.y
    end
  else
    gameState.location = "outdoor"
    gameState.player.gridX = 12
    gameState.player.gridY = 18
    gameState.player.x = gameState.player.gridX * 32 + 16
    gameState.player.y = gameState.player.gridY * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.collisionMap = buildings.createCollisionMap("outdoor", false)
    gameState.currentPortals = nil
    gameState.currentNPCs = {}
  end
  gameState.returnLocation = nil
  gameState.returnPosition = nil
end

return M
