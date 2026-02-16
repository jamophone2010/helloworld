-- hub/prototype_event.lua
-- Story event: The Prototype breach on Deck 1
-- Triggered after tutorial completes and Associate walks into a building
-- Station shakes, red lights flash, cutscene transitions to Deck 1

local M = {}

local npc = require("hub.npc")
local prototype = require("starfox.prototype")

-- Event state
M.active = false
M.phase = "inactive"
M.timer = 0
M.shakeTimer = 0
M.shakeIntensity = 0
M.redFlashAlpha = 0
M.redFlashTimer = 0
M.fadeAlpha = 0

-- Dialogue system
M.dialogueVisible = false
M.dialogueSpeaker = ""
M.dialogueText = ""
M.dialogueQueue = {}
M.dialogueQueueIndex = 0
M.choiceOptions = nil
M.selectedChoice = 1

-- Quest notification
M.questNotifyVisible = false
M.questNotifyTimer = 0
M.questNotifyText = ""

-- NPCs for the Deck 1 cutscene
M.associateNPC = nil
M.directorNPC = nil
M.medicNPC = nil
M.engineer1NPC = nil
M.engineer2NPC = nil

-- Building where Associate entered (to reappear from)
M.associateBuildingDoorX = 0
M.associateBuildingDoorY = 0
M.associateRunning = false

-- Callback
M.onComplete = nil
M.changeFloor = nil  -- function(floorId) to change to Deck 1

-- ═══════════════════════════════════════
-- EVENT TRIGGER
-- ═══════════════════════════════════════

-- Called when the Associate walks into a building after the tutorial
-- doorX, doorY: the building door grid position the Associate entered
function M.start(doorX, doorY)
  if M.active then return end
  if prototype.questStarted then return end

  M.active = true
  M.phase = "waiting"
  M.timer = 0
  M.shakeTimer = 0
  M.shakeIntensity = 0
  M.redFlashAlpha = 0
  M.redFlashTimer = 0
  M.fadeAlpha = 0
  M.dialogueVisible = false
  M.questNotifyVisible = false
  M.associateBuildingDoorX = doorX
  M.associateBuildingDoorY = doorY
  M.associateRunning = false

  -- Create Associate NPC for reappearance
  M.associateNPC = {
    name = "Associate",
    x = doorX,
    y = doorY,
    gridX = doorX,
    gridY = doorY,
    targetX = doorX,
    targetY = doorY,
    dialogue = "",
    gender = "female",
    design = 1,
    width = 24,
    height = 24,
    direction = "down",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false
  }
end

function M.stop()
  M.active = false
  M.phase = "inactive"
  M.dialogueVisible = false
  M.questNotifyVisible = false
  M.associateNPC = nil
  M.directorNPC = nil
  M.medicNPC = nil
  M.engineer1NPC = nil
  M.engineer2NPC = nil
end

-- ═══════════════════════════════════════
-- DIALOGUE HELPERS
-- ═══════════════════════════════════════

local function setDialogue(speaker, text)
  M.dialogueSpeaker = speaker
  M.dialogueText = text
  M.dialogueVisible = true
  M.dialogueQueue = {}
  M.dialogueQueueIndex = 0
end

local function setDialogueQueue(speaker, sentences)
  M.dialogueSpeaker = speaker
  M.dialogueQueue = sentences
  M.dialogueQueueIndex = 1
  M.dialogueText = sentences[1]
  M.dialogueVisible = true
end

local function advanceDialogueQueue()
  if M.dialogueQueueIndex > 0 and M.dialogueQueueIndex < #M.dialogueQueue then
    M.dialogueQueueIndex = M.dialogueQueueIndex + 1
    M.dialogueText = M.dialogueQueue[M.dialogueQueueIndex]
    return true
  end
  return false
end

-- ═══════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════

function M.update(dt, gameState)
  if not M.active then return end

  M.timer = M.timer + dt

  -- Red light flashing (during shake phases)
  if M.phase == "shaking" or M.phase == "associate_runs_out" then
    M.redFlashTimer = M.redFlashTimer + dt
    M.redFlashAlpha = math.abs(math.sin(M.redFlashTimer * 3)) * 0.25
  else
    M.redFlashAlpha = math.max(0, M.redFlashAlpha - dt * 2)
  end

  -- Screen shake
  if M.shakeIntensity > 0 then
    M.shakeTimer = M.shakeTimer + dt
  end

  -- Quest notification timer
  if M.questNotifyVisible then
    M.questNotifyTimer = M.questNotifyTimer + dt
    if M.questNotifyTimer >= 4.0 then
      M.questNotifyVisible = false
    end
  end

  -- Phase logic
  if M.phase == "waiting" then
    -- Brief pause after Associate enters building
    if M.timer >= 2.0 then
      M.phase = "shaking"
      M.timer = 0
      M.shakeIntensity = 4
    end

  elseif M.phase == "shaking" then
    -- Station shakes for a period, red lights flash
    -- Shake intensity varies
    M.shakeIntensity = 4 + math.sin(M.timer * 2) * 2

    if M.timer >= 5.0 then
      -- Associate reappears at building door, running
      M.phase = "associate_runs_out"
      M.timer = 0
      M.associateRunning = true
      -- Position Associate at the door they entered
      M.associateNPC.gridX = M.associateBuildingDoorX
      M.associateNPC.gridY = M.associateBuildingDoorY
      M.associateNPC.x = M.associateBuildingDoorX
      M.associateNPC.y = M.associateBuildingDoorY
      M.associateNPC.direction = "down"
      -- Make them run one tile out
      M.associateNPC.targetX = M.associateBuildingDoorX
      M.associateNPC.targetY = M.associateBuildingDoorY + 1
      M.associateNPC.moving = true
      M.associateNPC.moveProgress = 0
    end

  elseif M.phase == "associate_runs_out" then
    -- Animate Associate running out
    if M.associateNPC.moving then
      M.associateNPC.moveProgress = M.associateNPC.moveProgress + 150 * dt -- Faster than normal (running)
      if M.associateNPC.moveProgress >= 32 then
        M.associateNPC.x = M.associateNPC.targetX
        M.associateNPC.y = M.associateNPC.targetY
        M.associateNPC.gridX = M.associateNPC.targetX
        M.associateNPC.gridY = M.associateNPC.targetY
        M.associateNPC.moving = false
        M.associateNPC.moveProgress = 0
      else
        local t = M.associateNPC.moveProgress / 32
        local startX = M.associateNPC.gridX
        local startY = M.associateNPC.gridY
        M.associateNPC.x = startX + (M.associateNPC.targetX - startX) * t
        M.associateNPC.y = startY + (M.associateNPC.targetY - startY) * t
      end
    else
      -- Associate has stopped, show dialogue
      M.phase = "associate_speaks"
      M.timer = 0
      M.shakeIntensity = 2 -- Reduce shake
      setDialogue("Associate", "Breach on Deck 1! All hands on deck!")
    end

  elseif M.phase == "associate_speaks" then
    -- Waiting for player to dismiss dialogue (keypressed)

  elseif M.phase == "fade_to_black" then
    M.fadeAlpha = M.fadeAlpha + dt * 2
    if M.fadeAlpha >= 1.0 then
      M.fadeAlpha = 1.0
      M.phase = "transition_to_deck1"
      M.timer = 0
    end

  elseif M.phase == "transition_to_deck1" then
    -- Change to Deck 1 and set up the breach scene
    if M.timer >= 0.5 then
      M.setupDeck1Scene(gameState)
      M.phase = "fade_from_black"
      M.timer = 0
      M.shakeIntensity = 0
      M.redFlashAlpha = 0
    end

  elseif M.phase == "fade_from_black" then
    M.fadeAlpha = M.fadeAlpha - dt * 1.5
    if M.fadeAlpha <= 0 then
      M.fadeAlpha = 0
      M.phase = "deck1_director_paces"
      M.timer = 0
    end

  elseif M.phase == "deck1_director_paces" then
    -- Director paces back and forth briefly
    if M.directorNPC then
      M.animateDirectorPacing(dt)
    end
    if M.timer >= 3.0 then
      M.phase = "deck1_director_speaks1"
      M.timer = 0
      if M.directorNPC then
        M.directorNPC.moving = false
        M.directorNPC.direction = "down"
      end
      setDialogue("Director", "This is not good...the Prototype is gone.")
    end

  elseif M.phase == "deck1_director_speaks1" then
    -- Waiting for player to advance

  elseif M.phase == "deck1_player_speaks" then
    -- Player reacts
    -- Waiting for player to advance

  elseif M.phase == "deck1_director_speaks2" then
    -- Director explains the Prototype
    -- Waiting for player to advance through dialogue queue

  elseif M.phase == "quest_started" then
    -- Show quest notification
    if not M.questNotifyVisible then
      M.questNotifyVisible = true
      M.questNotifyTimer = 0
      M.questNotifyText = "Quest Started: The Prototype"
      prototype.questStarted = true
    end
    if M.timer >= 1.0 then
      M.phase = "deck1_director_speaks3"
      M.timer = 0
      setDialogueQueue("Director", {
        "Avoid engaging with the Prototype at all costs.",
        "Whoever stole it doesn't want Alliance types like us on their trail.",
        "Its lasers have EMP and immobilize their targets.",
        "Maybe that Deflector Shield on your Starwing might come in handy..."
      })
    end

  elseif M.phase == "deck1_director_speaks3" then
    -- Waiting for player to advance through final dialogue

  elseif M.phase == "event_complete" then
    -- Event is done
    if M.timer >= 1.0 then
      M.active = false
      M.phase = "inactive"
      if M.onComplete then
        M.onComplete()
      end
    end
  end
end

-- ═══════════════════════════════════════
-- DECK 1 SCENE SETUP
-- ═══════════════════════════════════════

function M.setupDeck1Scene(gameState)
  -- Transition to Deck 1
  if M.changeFloor then
    M.changeFloor(1)
  end

  -- Create NPCs for the scene
  -- Position them near the Loading Bay area (which is the hangar where the breach happened)
  -- Loading Bay building is at x=2, y=14, w=8, h=4, doorX=5, doorY=17

  M.associateNPC = {
    name = "Associate",
    x = 8, y = 10,
    gridX = 8, gridY = 10,
    targetX = 8, targetY = 10,
    dialogue = "",
    gender = "female",
    design = 1,
    width = 24, height = 24,
    direction = "left",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false
  }

  M.directorNPC = {
    name = "Director",
    x = 10, y = 9,
    gridX = 10, gridY = 9,
    targetX = 10, targetY = 9,
    dialogue = "",
    gender = "male",
    design = 5,
    width = 24, height = 24,
    direction = "down",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false,
    -- Pacing state
    paceDir = 1,
    paceTimer = 0,
    paceStartX = 9,
    paceEndX = 13,
  }

  M.medicNPC = {
    name = "Medic",
    x = 12, y = 10,
    gridX = 12, gridY = 10,
    targetX = 12, targetY = 10,
    dialogue = "",
    gender = "female",
    design = 2,
    width = 24, height = 24,
    direction = "left",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false
  }

  M.engineer1NPC = {
    name = "Engineer",
    x = 6, y = 11,
    gridX = 6, gridY = 11,
    targetX = 6, targetY = 11,
    dialogue = "",
    gender = "male",
    design = 3,
    width = 24, height = 24,
    direction = "right",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false,
    hardHat = true
  }

  M.engineer2NPC = {
    name = "Engineer",
    x = 14, y = 11,
    gridX = 14, gridY = 11,
    targetX = 14, targetY = 11,
    dialogue = "",
    gender = "male",
    design = 4,
    width = 24, height = 24,
    direction = "left",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false,
    hardHat = true
  }

  -- Position the player near the group
  if gameState and gameState.player then
    gameState.player.gridX = 10
    gameState.player.gridY = 11
    gameState.player.x = 10 * 32 + 16
    gameState.player.y = 11 * 32 + 16
    gameState.player.targetX = gameState.player.x
    gameState.player.targetY = gameState.player.y
    gameState.player.direction = "up"
  end
end

function M.animateDirectorPacing(dt)
  local dir = M.directorNPC
  if not dir then return end

  dir.paceTimer = dir.paceTimer + dt

  if not dir.moving then
    -- Start next pace step
    local nextX = dir.gridX + dir.paceDir
    if nextX > dir.paceEndX then
      dir.paceDir = -1
      dir.direction = "left"
      nextX = dir.gridX - 1
    elseif nextX < dir.paceStartX then
      dir.paceDir = 1
      dir.direction = "right"
      nextX = dir.gridX + 1
    end
    dir.targetX = nextX
    dir.targetY = dir.gridY
    dir.moving = true
    dir.moveProgress = 0
    dir.direction = dir.paceDir == 1 and "right" or "left"
  else
    dir.moveProgress = dir.moveProgress + 80 * dt
    if dir.moveProgress >= 32 then
      dir.x = dir.targetX
      dir.y = dir.targetY
      dir.gridX = dir.targetX
      dir.gridY = dir.targetY
      dir.moving = false
      dir.moveProgress = 0
    else
      local t = dir.moveProgress / 32
      local startX = dir.gridX
      dir.x = startX + (dir.targetX - startX) * t
    end
  end
end

-- ═══════════════════════════════════════
-- INPUT
-- ═══════════════════════════════════════

function M.keypressed(key)
  if not M.active then return false end

  if M.phase == "associate_speaks" then
    if key == "return" or key == "e" then
      M.dialogueVisible = false
      M.phase = "fade_to_black"
      M.timer = 0
      return true
    end

  elseif M.phase == "deck1_director_speaks1" then
    if key == "return" or key == "e" then
      M.dialogueVisible = false
      M.phase = "deck1_player_speaks"
      M.timer = 0
      setDialogue(M.playerName or "Player", "Prototype? ...")
      return true
    end

  elseif M.phase == "deck1_player_speaks" then
    if key == "return" or key == "e" then
      M.dialogueVisible = false
      M.phase = "deck1_director_speaks2"
      M.timer = 0
      setDialogueQueue("Director", {
        "The Prototype was an advanced, experimental starfighter we bought from Leucadia Labs.",
        "I was hoping maybe you'd be the one to fly it someday.",
        "At least we put a tracking beacon on it.",
        "I'll put the beacon on your minimap."
      })
      return true
    end

  elseif M.phase == "deck1_director_speaks2" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = false
        M.phase = "quest_started"
        M.timer = 0
      end
      return true
    end

  elseif M.phase == "deck1_director_speaks3" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = false
        M.phase = "event_complete"
        M.timer = 0
      end
      return true
    end
  end

  return false
end

function M.isBlockingInput()
  if not M.active then return false end
  return true  -- Event blocks all other hub input
end

-- ═══════════════════════════════════════
-- DRAWING
-- ═══════════════════════════════════════

function M.draw(time, cameraX, cameraY)
  if not M.active then return end

  local screenW, screenH = love.graphics.getDimensions()

  -- Screen shake offset
  local shakeX, shakeY = 0, 0
  if M.shakeIntensity > 0 then
    shakeX = (math.random() - 0.5) * M.shakeIntensity * 2
    shakeY = (math.random() - 0.5) * M.shakeIntensity * 2
  end

  -- Apply shake (note: this should be applied to the camera in the hub draw, but we'll overlay)
  if shakeX ~= 0 or shakeY ~= 0 then
    love.graphics.push()
    love.graphics.translate(shakeX, shakeY)
  end

  -- Draw event NPCs (only on Deck 1 scene)
  if M.phase:find("deck1_") or M.phase == "quest_started" or M.phase == "event_complete" then
    -- NPCs are drawn by the hub's normal NPC rendering
    -- But we need to draw the breach in the Loading Bay
    M.drawBreach(cameraX, cameraY, screenW, screenH, time)
  end

  -- Draw Associate running (during shake phase on original floor)
  if M.phase == "associate_runs_out" and M.associateNPC then
    -- Associate is drawn by the hub NPC system (we add them to the NPC list)
  end

  if shakeX ~= 0 or shakeY ~= 0 then
    love.graphics.pop()
  end

  -- Red flash overlay
  if M.redFlashAlpha > 0 then
    love.graphics.setColor(1, 0, 0, M.redFlashAlpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  -- Fade overlay
  if M.fadeAlpha > 0 then
    love.graphics.setColor(0, 0, 0, M.fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end

  -- Dialogue box
  if M.dialogueVisible then
    M.drawDialogueBox(screenW, screenH, time)
  end

  -- Quest notification
  if M.questNotifyVisible then
    M.drawQuestNotification(screenW, screenH, time)
  end
end

function M.drawBreach(cameraX, cameraY, screenW, screenH, time)
  -- Draw a blast hole in the Loading Bay area
  -- Loading Bay is at x=2, y=14, w=8, h=4
  -- The breach is a hole blasted outward from one of the loading docks

  local breachX = 5 * 32 + 16 - (cameraX or 0) + screenW / 2
  local breachY = 16 * 32 + 16 - (cameraY or 0) + screenH / 2

  -- Scorch marks
  love.graphics.setColor(0.3, 0.15, 0.0, 0.6)
  love.graphics.circle("fill", breachX, breachY, 40)

  -- Hole
  love.graphics.setColor(0.02, 0.02, 0.05, 0.9)
  love.graphics.circle("fill", breachX, breachY, 25)

  -- Sparks
  love.graphics.setColor(1, 0.7, 0.2, 0.5 + 0.3 * math.sin((time or 0) * 8))
  for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2 + (time or 0) * 3
    local r = 22 + math.sin(angle * 3 + (time or 0) * 5) * 5
    love.graphics.circle("fill", breachX + math.cos(angle) * r, breachY + math.sin(angle) * r, 2)
  end

  -- Debris
  love.graphics.setColor(0.4, 0.3, 0.2, 0.7)
  for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2
    local r = 28 + math.sin(i * 1.3) * 8
    love.graphics.rectangle("fill",
      breachX + math.cos(angle) * r - 3,
      breachY + math.sin(angle) * r - 2,
      6, 4)
  end

  -- "Space dock breach" sign
  love.graphics.setColor(1, 0.3, 0.3, 0.8)
  local warningFont = love.graphics.newFont(10)
  love.graphics.setFont(warningFont)
  love.graphics.printf("⚠ BREACH", breachX - 30, breachY - 40, 60, "center")
end

function M.drawDialogueBox(screenW, screenH, time)
  local boxX = 80
  local boxY = screenH - 200
  local boxW = screenW - 160
  local boxH = 150

  -- Box background
  love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6)

  -- Border color depends on speaker
  local borderColor = {0.0, 0.7, 1.0, 0.7}
  if M.dialogueSpeaker == "Associate" then
    borderColor = {0.0, 0.7, 1.0, 0.7}
  elseif M.dialogueSpeaker == "Director" then
    borderColor = {1.0, 0.7, 0.0, 0.7}
  else
    borderColor = {0.5, 0.5, 0.6, 0.7}
  end

  love.graphics.setColor(borderColor)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6)

  -- Speaker name
  local nameFont = love.graphics.newFont(22)
  love.graphics.setFont(nameFont)
  if M.dialogueSpeaker == "Director" then
    love.graphics.setColor(1.0, 0.8, 0.2)
  elseif M.dialogueSpeaker == "Associate" then
    love.graphics.setColor(0.0, 0.9, 1.0)
  else
    love.graphics.setColor(0.8, 0.8, 0.9)
  end
  love.graphics.print(M.dialogueSpeaker, boxX + 20, boxY + 12)

  -- Text
  local textFont = love.graphics.newFont("fonts/Exo2-Regular.ttf", 16)
  love.graphics.setFont(textFont)
  love.graphics.setColor(0.9, 0.9, 0.95)
  love.graphics.printf(M.dialogueText, boxX + 20, boxY + 45, boxW - 40, "left")

  -- Advance hint
  local pulse = 0.4 + 0.4 * math.sin((time or 0) * 3)
  local hintFont = love.graphics.newFont(12)
  love.graphics.setFont(hintFont)
  love.graphics.setColor(0.5, 0.5, 0.6, pulse)
  love.graphics.print("Press ENTER to continue", boxX + 20, boxY + boxH - 25)
end

function M.drawQuestNotification(screenW, screenH, time)
  local boxW = 350
  local boxH = 50
  local boxX = screenW / 2 - boxW / 2
  local boxY = 50

  -- Slide in from top
  local slideProgress = math.min(M.questNotifyTimer / 0.5, 1)
  local actualY = -boxH + (boxY + boxH) * slideProgress

  -- Fade out near end
  local alpha = 1
  if M.questNotifyTimer > 3.0 then
    alpha = 1 - (M.questNotifyTimer - 3.0) / 1.0
  end
  alpha = math.max(0, alpha)

  -- Background
  love.graphics.setColor(0.05, 0.05, 0.15, 0.9 * alpha)
  love.graphics.rectangle("fill", boxX, actualY, boxW, boxH, 6)

  -- Border (gold)
  love.graphics.setColor(1.0, 0.8, 0.2, 0.8 * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, actualY, boxW, boxH, 6)

  -- Quest icon
  love.graphics.setColor(1.0, 0.8, 0.2, alpha)
  local iconFont = love.graphics.newFont(20)
  love.graphics.setFont(iconFont)
  love.graphics.print("⚔", boxX + 15, actualY + 13)

  -- Quest text
  local titleFont = love.graphics.newFont(14)
  love.graphics.setFont(titleFont)
  love.graphics.setColor(1.0, 0.8, 0.2, alpha)
  love.graphics.print("Quest Started", boxX + 45, actualY + 8)

  local subtitleFont = love.graphics.newFont(12)
  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(0.9, 0.9, 0.95, alpha)
  love.graphics.print(M.questNotifyText, boxX + 45, actualY + 28)
end

-- Get the screen shake offset for the hub camera
function M.getShakeOffset()
  if not M.active or M.shakeIntensity <= 0 then
    return 0, 0
  end
  return (math.random() - 0.5) * M.shakeIntensity * 2,
         (math.random() - 0.5) * M.shakeIntensity * 2
end

-- Get NPCs for the Deck 1 scene (to inject into the hub NPC list)
function M.getDeck1NPCs()
  local npcs = {}
  if M.associateNPC then table.insert(npcs, M.associateNPC) end
  if M.directorNPC then table.insert(npcs, M.directorNPC) end
  if M.medicNPC then table.insert(npcs, M.medicNPC) end
  if M.engineer1NPC then table.insert(npcs, M.engineer1NPC) end
  if M.engineer2NPC then table.insert(npcs, M.engineer2NPC) end
  return npcs
end

-- Set player name for dialogue
function M.setPlayerName(name)
  M.playerName = name
end

return M
