-- hub/tutorial.lua
-- New Game tutorial: Associate NPC guides player around Floor 4
-- Triggered after intro cutscene on first game start

local M = {}

local npc = require("hub.npc")

-- Tutorial state
M.active = false
M.phase = "inactive"
M.associateNPC = nil
M.timer = 0
M.dialogueText = ""
M.dialogueSpeaker = ""
M.dialogueVisible = false
M.choiceOptions = nil
M.selectedChoice = 1
M.exclamationVisible = false
M.exclamationTimer = 0
M.walkTarget = nil
M.questCompleteVisible = false
M.questCompleteTimer = 0
M.tourCount = 0  -- How many times the tour has been given

-- Dialogue queue for sentence-by-sentence display
local dialogueQueue = {}
local dialogueQueueIndex = 0

local function setDialogue(text)
  M.dialogueText = text
  dialogueQueue = {}
  dialogueQueueIndex = 0
end

local function setDialogueQueue(sentences)
  dialogueQueue = sentences
  dialogueQueueIndex = 1
  if #sentences > 0 then
    M.dialogueText = sentences[1]
  end
end

-- Advance to next sentence. Returns true if there was a next sentence.
local function advanceDialogueQueue()
  if dialogueQueueIndex > 0 and dialogueQueueIndex < #dialogueQueue then
    dialogueQueueIndex = dialogueQueueIndex + 1
    M.dialogueText = dialogueQueue[dialogueQueueIndex]
    return true
  end
  return false
end

local function isDialogueQueueDone()
  return dialogueQueueIndex <= 0 or dialogueQueueIndex >= #dialogueQueue
end

-- Saved tour state for resuming after elevator intercept
local savedTourPhase = nil

-- Walking path for the Associate (grid positions)
-- These get set based on actual floor layout
local tourStops = {}

-- Callback for when tutorial completes
M.onComplete = nil

function M.start(gameState)
  M.active = true
  M.phase = "associate_appears"
  M.timer = 0
  M.tourCount = 0
  M.questCompleteVisible = false
  M.dialogueVisible = false
  M.exclamationVisible = true
  M.exclamationTimer = 0

  -- Create Associate NPC near the player's starting position
  -- Player starts at elevator (17, 11) on Floor 4, Associate appears nearby
  M.associateNPC = {
    name = "Associate",
    x = 19,
    y = 11,
    gridX = 19,
    gridY = 11,
    targetX = 19,
    targetY = 11,
    dialogue = "",
    gender = "female",
    design = 1,
    width = 24,
    height = 24,
    direction = "left",
    moving = false,
    moveProgress = 0,
    wanderTimer = 999,
    canWander = false
  }

  -- Define tour stops on Floor 4:
  -- Mission Control door is at (28, 7)
  -- Hangar door is at (5, 7)
  -- Elevator is at (17, 11)
  tourStops = {
    {name = "Mission Control", x = 27, y = 8, doorX = 28, doorY = 7},
    {name = "Hangar", x = 6, y = 8, doorX = 5, doorY = 7},
    {name = "Elevator", x = 18, y = 11}
  }
end

function M.stop()
  M.active = false
  M.phase = "inactive"
  M.associateNPC = nil
  M.dialogueVisible = false
  M.exclamationVisible = false
  M.questCompleteVisible = false
end

-- Walk the Associate NPC toward a target grid position step by step
local walkQueue = {}
local walkingToTarget = false

local function buildPath(fromX, fromY, toX, toY)
  -- Simple path: move horizontally first, then vertically
  local path = {}
  local cx, cy = fromX, fromY

  -- Horizontal movement
  while cx ~= toX do
    if cx < toX then
      cx = cx + 1
      table.insert(path, {x = cx, y = cy, dir = "right"})
    else
      cx = cx - 1
      table.insert(path, {x = cx, y = cy, dir = "left"})
    end
  end

  -- Vertical movement
  while cy ~= toY do
    if cy < toY then
      cy = cy + 1
      table.insert(path, {x = cx, y = cy, dir = "down"})
    else
      cy = cy - 1
      table.insert(path, {x = cx, y = cy, dir = "up"})
    end
  end

  return path
end

local function startWalkTo(targetX, targetY)
  if not M.associateNPC then return end
  walkQueue = buildPath(M.associateNPC.gridX, M.associateNPC.gridY, targetX, targetY)
  walkingToTarget = true
end

local function updateWalk(dt)
  if not M.associateNPC or not walkingToTarget then return end

  if M.associateNPC.moving then
    -- Animate current step
    M.associateNPC.moveProgress = M.associateNPC.moveProgress + 100 * dt
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
    -- Start next step
    if #walkQueue > 0 then
      local step = table.remove(walkQueue, 1)
      M.associateNPC.direction = step.dir
      M.associateNPC.targetX = step.x
      M.associateNPC.targetY = step.y
      M.associateNPC.moving = true
      M.associateNPC.moveProgress = 0
    else
      walkingToTarget = false
    end
  end
end

function M.update(dt, gameState)
  if not M.active then return end

  M.timer = M.timer + dt
  updateWalk(dt)

  -- Exclamation mark animation
  if M.exclamationVisible then
    M.exclamationTimer = M.exclamationTimer + dt
  end

  -- Quest complete popup timer
  if M.questCompleteVisible then
    M.questCompleteTimer = M.questCompleteTimer + dt
    if M.questCompleteTimer >= 4.0 then
      M.questCompleteVisible = false
      M.stop()
      if M.onComplete then
        M.onComplete()
      end
    end
  end

  if M.phase == "associate_appears" then
    -- Exclamation mark appears, Associate walks to player
    if M.exclamationTimer >= 1.0 and not walkingToTarget and not M.dialogueVisible then
      M.exclamationVisible = false
      -- Walk toward the player
      local playerGridX = gameState.player.gridX
      local playerGridY = gameState.player.gridY
      -- Walk to one tile right of player
      startWalkTo(playerGridX + 1, playerGridY)
      M.phase = "associate_walking_to_player"
    end

  elseif M.phase == "associate_walking_to_player" then
    if not walkingToTarget and not M.associateNPC.moving then
      -- Arrived near player, face player
      M.associateNPC.direction = "left"
      M.phase = "associate_greet"
      M.timer = 0
      M.dialogueVisible = true
      M.dialogueSpeaker = "Associate"
      setDialogue("Hi! Want me to show you around?")
      M.choiceOptions = {"Sure!", "Nah, I'm good"}
      M.selectedChoice = 1
    end

  elseif M.phase == "associate_greet" then
    -- Waiting for player choice (handled in keypressed)

  elseif M.phase == "tour_walk_mission_control" then
    if not walkingToTarget and not M.associateNPC.moving then
      M.associateNPC.direction = "up"
      M.phase = "tour_explain_mission_control"
      M.timer = 0
      M.dialogueVisible = true
      M.dialogueSpeaker = "Associate"
      setDialogueQueue({
        "OK, so this building is Mission Control.",
        "This is where you can start missions or use the portal system to visit places you've visited before."
      })
      M.choiceOptions = nil
    end

  elseif M.phase == "tour_explain_mission_control" then
    -- Waiting for player to advance (keypressed)

  elseif M.phase == "tour_walk_hangar" then
    if not walkingToTarget and not M.associateNPC.moving then
      M.associateNPC.direction = "up"
      M.phase = "tour_explain_hangar"
      M.timer = 0
      M.dialogueVisible = true
      M.dialogueSpeaker = "Associate"
      setDialogueQueue({
        "This is the Hangar.",
        "In your travels across the universe you'll probably end up with more ships than just a Starwing.",
        "This is where you switch ships."
      })
      M.choiceOptions = nil
    end

  elseif M.phase == "tour_explain_hangar" then
    -- Waiting for player to advance (keypressed)

  elseif M.phase == "tour_walk_elevator" then
    if not walkingToTarget and not M.associateNPC.moving then
      M.associateNPC.direction = "down"
      M.phase = "tour_explain_elevator"
      M.timer = 0
      M.dialogueVisible = true
      M.dialogueSpeaker = "Associate"
      setDialogueQueue({
        "Last, but not least, here is the Elevator.",
        "This lets you access all the different decks of Hometown Station.",
        "Our Studio is on Deck 3, any Notes you can donate are very well appreciated.",
        "Alternatively, I've lost my fair share of Notes at the Casino on Deck 2...",
        "Anyway that's pretty much all there is to this place."
      })
      M.choiceOptions = nil
    end

  elseif M.phase == "tour_explain_elevator" then
    -- Waiting for player to advance (keypressed)

  elseif M.phase == "tour_questions" then
    -- Waiting for player choice (keypressed)

  elseif M.phase == "tour_complete" then
    -- "OK - best of luck!" then show quest complete
    -- Waiting for player to advance

  elseif M.phase == "tour_replay" then
    -- Restart tour
    M.startTour()

  -- ═══ Elevator intercept phases ═══
  elseif M.phase == "elevator_intercept_walk" then
    -- Associate is walking back to the player
    if not walkingToTarget and not M.associateNPC.moving then
      -- Face the player
      M.associateNPC.direction = "left"
      M.phase = "elevator_intercept_scold"
      M.timer = 0
      M.dialogueVisible = true
      M.dialogueSpeaker = "Associate"
      setDialogueQueue({
        "Hey! Where do you think you're going?",
        "Like, you said you wanted to do the tutorial..."
      })
      M.choiceOptions = nil
    end

  elseif M.phase == "elevator_intercept_scold" then
    -- Waiting for player to advance (keypressed)

  elseif M.phase == "elevator_intercept_choice" then
    -- Waiting for player choice (keypressed)

  elseif M.phase == "elevator_intercept_leave" then
    -- Associate walks into nearest building and disappears
    if not walkingToTarget and not M.associateNPC.moving then
      -- Associate has arrived at building door, remove them from the world
      M.associateNPC = nil
      M.dialogueVisible = false
      M.questCompleteVisible = true
      M.questCompleteTimer = 0
      M.phase = "quest_complete_display"
    end
  end
end

function M.startTour()
  M.tourCount = M.tourCount + 1
  M.dialogueVisible = false
  M.phase = "tour_walk_mission_control"
  -- Walk to Mission Control
  startWalkTo(tourStops[1].x, tourStops[1].y)
end

function M.keypressed(key)
  if not M.active then return false end

  if M.phase == "associate_greet" then
    if M.choiceOptions then
      if key == "up" then
        M.selectedChoice = M.selectedChoice - 1
        if M.selectedChoice < 1 then M.selectedChoice = #M.choiceOptions end
        return true
      elseif key == "down" then
        M.selectedChoice = M.selectedChoice + 1
        if M.selectedChoice > #M.choiceOptions then M.selectedChoice = 1 end
        return true
      elseif key == "return" or key == "e" then
        if M.selectedChoice == 1 then
          -- "Sure!" - start tour
          M.dialogueVisible = false
          M.choiceOptions = nil
          M.startTour()
        else
          -- "Nah, I'm good" - skip tutorial
          M.dialogueVisible = true
          M.dialogueSpeaker = "Associate"
          setDialogue("OK - best of luck!")
          M.choiceOptions = nil
          M.phase = "tour_skipped"
        end
        return true
      end
    end

  elseif M.phase == "tour_skipped" then
    if key == "return" or key == "e" then
      -- Show quest complete and end
      M.dialogueVisible = false
      M.questCompleteVisible = true
      M.questCompleteTimer = 0
      M.phase = "quest_complete_display"
    end
    return true

  elseif M.phase == "tour_explain_mission_control" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = false
        M.phase = "tour_walk_hangar"
        startWalkTo(tourStops[2].x, tourStops[2].y)
      end
      return true
    end

  elseif M.phase == "tour_explain_hangar" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = false
        M.phase = "tour_walk_elevator"
        startWalkTo(tourStops[3].x, tourStops[3].y)
      end
      return true
    end

  elseif M.phase == "tour_explain_elevator" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = true
        M.dialogueSpeaker = "Associate"
        setDialogue("Any questions for me?")
        M.choiceOptions = {"Nope - I'm all set, thanks!", "Could you show me the tour again?"}
        M.selectedChoice = 1
        M.phase = "tour_questions"
      end
      return true
    end

  elseif M.phase == "tour_questions" then
    if M.choiceOptions then
      if key == "up" then
        M.selectedChoice = M.selectedChoice - 1
        if M.selectedChoice < 1 then M.selectedChoice = #M.choiceOptions end
        return true
      elseif key == "down" then
        M.selectedChoice = M.selectedChoice + 1
        if M.selectedChoice > #M.choiceOptions then M.selectedChoice = 1 end
        return true
      elseif key == "return" or key == "e" then
        if M.selectedChoice == 1 then
          -- "Nope - all set"
          M.dialogueVisible = true
          M.dialogueSpeaker = "Associate"
          setDialogue("OK - best of luck!")
          M.choiceOptions = nil
          M.phase = "tour_complete"
        else
          -- "Show me the tour again"
          M.dialogueVisible = false
          M.choiceOptions = nil
          M.phase = "tour_replay"
        end
        return true
      end
    end

  elseif M.phase == "tour_complete" then
    if key == "return" or key == "e" then
      M.dialogueVisible = false
      M.questCompleteVisible = true
      M.questCompleteTimer = 0
      M.phase = "quest_complete_display"
    end
    return true

  elseif M.phase == "elevator_intercept_scold" then
    if key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        M.dialogueVisible = true
        M.dialogueSpeaker = "Associate"
        setDialogue("So...do you want to continue the tour or not?")
        M.choiceOptions = {"Oh yeah...I remember now. Go on...", "Actually, I think I'm good."}
        M.selectedChoice = 1
        M.phase = "elevator_intercept_choice"
      end
      return true
    end

  elseif M.phase == "elevator_intercept_choice" then
    if M.choiceOptions then
      if key == "up" then
        M.selectedChoice = M.selectedChoice - 1
        if M.selectedChoice < 1 then M.selectedChoice = #M.choiceOptions end
        return true
      elseif key == "down" then
        M.selectedChoice = M.selectedChoice + 1
        if M.selectedChoice > #M.choiceOptions then M.selectedChoice = 1 end
        return true
      elseif key == "return" or key == "e" then
        if M.selectedChoice == 1 then
          -- "Oh yeah...I remember now. Go on..." - resume tour
          M.dialogueVisible = false
          M.choiceOptions = nil
          -- Resume from saved tour phase
          if savedTourPhase then
            M.phase = savedTourPhase
            savedTourPhase = nil
            -- Walk back to where the tour was
            if M.phase == "tour_walk_mission_control" then
              startWalkTo(tourStops[1].x, tourStops[1].y)
            elseif M.phase == "tour_walk_hangar" then
              startWalkTo(tourStops[2].x, tourStops[2].y)
            elseif M.phase == "tour_walk_elevator" then
              startWalkTo(tourStops[3].x, tourStops[3].y)
            else
              -- Default: restart tour from beginning
              M.startTour()
            end
          else
            M.startTour()
          end
        else
          -- "Actually, I think I'm good." - Associate leaves
          M.dialogueVisible = true
          M.dialogueSpeaker = "Associate"
          setDialogue("OK, suit yourself.")
          M.choiceOptions = nil
          M.phase = "elevator_intercept_goodbye"
        end
        return true
      end
    end

  elseif M.phase == "elevator_intercept_goodbye" then
    if key == "return" or key == "e" then
      -- Associate walks into nearest building and disappears
      M.dialogueVisible = false
      -- Walk toward the Mission Control building (closest) and disappear
      startWalkTo(tourStops[1].doorX or tourStops[1].x, tourStops[1].doorY or tourStops[1].y)
      M.phase = "elevator_intercept_leave"
      return true
    end

  elseif M.phase == "quest_complete_display" then
    -- Can't skip, auto-dismisses
    return true
  end

  return false
end

function M.draw(time, cameraX, cameraY)
  if not M.active then return end

  time = time or 0
  local screenW, screenH = love.graphics.getDimensions()

  -- Draw exclamation mark above Associate (in world space, need camera offset)
  if M.exclamationVisible and M.associateNPC then
    local ax = M.associateNPC.x * 32 + 16
    local ay = M.associateNPC.y * 32 - 20
    local bounce = math.abs(math.sin(M.exclamationTimer * 6)) * 8

    -- Transform to screen space using camera
    local drawX = ax - (cameraX or 0) + screenW / 2
    local drawY = ay - (cameraY or 0) + screenH / 2

    -- No speech bubble, just the exclamation mark (Pokemon-style)
    love.graphics.setColor(1, 0.9, 0.2, 1)
    local excFont = love.graphics.newFont(24)
    love.graphics.setFont(excFont)
    love.graphics.print("!", drawX - 4, drawY - bounce - 16)
  end

  -- Draw dialogue box
  if M.dialogueVisible then
    M.drawDialogueBox(screenW, screenH, time)
  end

  -- Draw choice menu
  if M.choiceOptions then
    M.drawChoices(screenW, screenH)
  end

  -- Draw quest complete popup
  if M.questCompleteVisible then
    M.drawQuestComplete(screenW, screenH, time)
  end
end

function M.drawDialogueBox(screenW, screenH, time)
  local boxX = 80
  local boxY = screenH - 200
  local boxW = screenW - 160
  local boxH = 150

  -- Box background
  love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6)

  -- Neon border
  love.graphics.setColor(0.0, 0.7, 1.0, 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6)

  -- Speaker name
  local nameFont = love.graphics.newFont(22)
  love.graphics.setFont(nameFont)
  love.graphics.setColor(0.0, 0.9, 1.0)
  love.graphics.print(M.dialogueSpeaker, boxX + 20, boxY + 12)

  -- Dialogue text
  local textFont = love.graphics.newFont(16)
  love.graphics.setFont(textFont)
  love.graphics.setColor(0.9, 0.9, 0.95)
  love.graphics.printf(M.dialogueText, boxX + 20, boxY + 45, boxW - 40, "left")

  -- Advance hint
  if not M.choiceOptions then
    local pulse = 0.4 + 0.4 * math.sin((time or 0) * 3)
    local hintFont = love.graphics.newFont(12)
    love.graphics.setFont(hintFont)
    love.graphics.setColor(0.5, 0.5, 0.6, pulse)
    love.graphics.print("Press ENTER to continue", boxX + 20, boxY + boxH - 25)
  end
end

function M.drawChoices(screenW, screenH)
  local choiceW = 400
  local choiceX = screenW / 2 - choiceW / 2
  local choiceY = screenH - 200 - #M.choiceOptions * 35 - 10
  local choiceFont = love.graphics.newFont(16)
  love.graphics.setFont(choiceFont)

  for i, choice in ipairs(M.choiceOptions) do
    local y = choiceY + (i - 1) * 35

    if i == M.selectedChoice then
      love.graphics.setColor(0.1, 0.2, 0.35, 0.95)
      love.graphics.rectangle("fill", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.3, 0.7, 1.0, 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.3, 0.7, 1.0)
      love.graphics.print("▶ " .. choice, choiceX + 15, y + 6)
    else
      love.graphics.setColor(0.05, 0.05, 0.1, 0.85)
      love.graphics.rectangle("fill", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.6, 0.6, 0.7)
      love.graphics.print("  " .. choice, choiceX + 15, y + 6)
    end
  end
end

function M.drawQuestComplete(screenW, screenH, time)
  -- Small window at top center: "Welcome to Hometown" miniquest completed
  local boxW = 350
  local boxH = 50
  local boxX = screenW / 2 - boxW / 2
  local boxY = 50

  -- Slide in from top
  local slideProgress = math.min(M.questCompleteTimer / 0.5, 1)
  local actualY = -boxH + (boxY + boxH) * slideProgress

  -- Fade out near end
  local alpha = 1
  if M.questCompleteTimer > 3.0 then
    alpha = 1 - (M.questCompleteTimer - 3.0) / 1.0
  end
  alpha = math.max(0, alpha)

  -- Background
  love.graphics.setColor(0.05, 0.15, 0.05, 0.9 * alpha)
  love.graphics.rectangle("fill", boxX, actualY, boxW, boxH, 6)

  -- Border
  love.graphics.setColor(0.2, 0.8, 0.3, 0.8 * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, actualY, boxW, boxH, 6)

  -- Star icon
  love.graphics.setColor(1.0, 0.9, 0.3, alpha)
  local starFont = love.graphics.newFont(20)
  love.graphics.setFont(starFont)
  love.graphics.print("★", boxX + 15, actualY + 13)

  -- Text
  local titleFont = love.graphics.newFont(14)
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.3, 0.9, 0.4, alpha)
  love.graphics.print("Miniquest Complete!", boxX + 45, actualY + 8)

  local subtitleFont = love.graphics.newFont(12)
  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(0.8, 0.9, 0.8, alpha)
  love.graphics.print("Welcome to Hometown", boxX + 45, actualY + 28)
end

-- Get the Associate NPC object for rendering in the hub's NPC list
function M.getAssociateNPC()
  return M.associateNPC
end

-- Called when player tries to use the elevator during the tutorial
function M.onElevatorAttempt(gameState)
  if not M.active then return false end
  -- Only intercept during tour phases (not during greeting or quest complete)
  if M.phase:find("tour_") or M.phase:find("associate_greet") then
    -- Save current tour phase so we can resume
    if M.phase:find("tour_walk_") then
      savedTourPhase = M.phase
    elseif M.phase:find("tour_explain_") then
      -- If explaining, resume from the next walk phase
      if M.phase == "tour_explain_mission_control" then
        savedTourPhase = "tour_walk_hangar"
      elseif M.phase == "tour_explain_hangar" then
        savedTourPhase = "tour_walk_elevator"
      elseif M.phase == "tour_explain_elevator" then
        savedTourPhase = "tour_walk_elevator"
      end
    else
      savedTourPhase = nil  -- Will restart tour
    end

    -- Stop any current walk
    walkQueue = {}
    walkingToTarget = false
    M.associateNPC.moving = false

    -- Associate walks back to the player
    local playerGridX = gameState.player.gridX
    local playerGridY = gameState.player.gridY
    startWalkTo(playerGridX + 1, playerGridY)
    M.phase = "elevator_intercept_walk"
    M.dialogueVisible = false
    M.choiceOptions = nil
    return true
  end
  return false
end

-- Check if tutorial is blocking normal hub input
function M.isBlockingInput()
  if not M.active then return false end
  return M.dialogueVisible or M.choiceOptions ~= nil or M.questCompleteVisible
      or M.phase:find("elevator_intercept")
end

return M
