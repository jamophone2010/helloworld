-- menu/intro_cutscene.lua
-- New Game cutscene: wake up in Medical, meet Medic and Director
-- Replaces the old Star Wars-style intro crawl

local M = {}

local fonts = {}
local phase = "fade_to_black"      -- Current cutscene phase
local timer = 0                     -- General purpose timer
local playerName = ""               -- Entered by player during cutscene
local maxNameLength = 12
local cursorBlink = 0
local cursorVisible = true
local selectedOption = 1            -- For dialogue choices
local textRevealTimer = 0           -- Typewriter effect timer
local textRevealSpeed = 0.03        -- Seconds per character
local revealedChars = 0             -- How many chars revealed so far
local currentDialogueText = ""      -- Full text of current dialogue
local textFullyRevealed = false     -- Whether text is done revealing

-- NPC state
local medicX = 0
local medicY = 0
local directorX = 0
local directorY = 0
local directorVisible = false
local directorEntering = false
local directorEnterTimer = 0
local directorLeaving = false
local directorLeaveTimer = 0
local exclamationVisible = false
local exclamationTimer = 0

-- Eye opening effect
local eyeOpenProgress = 0           -- 0 = closed, 1 = fully open
local eyeOpenSpeed = 0.4            -- How fast eyes open

-- Angelic glow
local glowTimer = 0

-- Screen dimensions
local screenW = 1366
local screenH = 768

M.onComplete = nil                  -- Callback when cutscene finishes (passes playerName)

-- All cutscene phases in order:
-- 1. fade_to_black        - Screen fades to black
-- 2. eye_opening           - Black eye-shaped mask opens revealing medical room
-- 3. medic_greeting        - Medic says greeting
-- 4. name_entry            - Player types name
-- 5. medic_mission_ask     - Medic asks about mission
-- 6. mission_choice        - Player picks from 2 options
-- 7a. medic_knows          - "Great! Looks like you're ready..."
-- 7b. medic_explain_1      - Long explanation (first part)
-- 7c. director_exclamation - Director overhears, exclamation mark
-- 7d. director_enters      - Director walks in
-- 7e. director_speak_1     - "And that's where you come in..."
-- 7f. player_notes_q       - Player: "Notes?"
-- 7g. director_speak_2     - "Yeah, Notes. Music notes..."
-- 7h. player_swarm_q       - Player: "Swarm?"
-- 7i. director_speak_3     - "Pretty much, they're a root armada..."
-- 7j. player_answer        - Player picks Yes/Maybe/Too much trouble
-- 7k. director_spirit      - "That's the spirit!"
-- 7l. director_leaves      - Director walks out
-- 7m. medic_closing        - Medic's final words
-- 8. end_cutscene          - Fade out, transition to hub

-- Phase data
local phases = {}

-- Dialogue queue: allows showing one sentence at a time
local dialogueQueue = {}       -- Array of strings to show one at a time
local dialogueQueueIndex = 0   -- Current position in queue

local function setDialogue(text)
  currentDialogueText = text
  revealedChars = 0
  textRevealTimer = 0
  textFullyRevealed = false
  dialogueQueue = {}
  dialogueQueueIndex = 0
end

-- Set a multi-sentence dialogue (one bubble per sentence)
local function setDialogueQueue(sentences)
  dialogueQueue = sentences
  dialogueQueueIndex = 1
  if #sentences > 0 then
    currentDialogueText = sentences[1]
    revealedChars = 0
    textRevealTimer = 0
    textFullyRevealed = false
  end
end

-- Advance to next sentence in queue. Returns true if there was a next sentence.
local function advanceDialogueQueue()
  if dialogueQueueIndex > 0 and dialogueQueueIndex < #dialogueQueue then
    dialogueQueueIndex = dialogueQueueIndex + 1
    currentDialogueText = dialogueQueue[dialogueQueueIndex]
    revealedChars = 0
    textRevealTimer = 0
    textFullyRevealed = false
    return true
  end
  return false
end

local function isDialogueQueueDone()
  return dialogueQueueIndex <= 0 or dialogueQueueIndex >= #dialogueQueue
end

local function getRevealedText()
  if textFullyRevealed then return currentDialogueText end
  local chars = math.floor(revealedChars)
  if chars >= #currentDialogueText then
    textFullyRevealed = true
    return currentDialogueText
  end
  return currentDialogueText:sub(1, chars)
end

function M.load()
  fonts.title = love.graphics.newFont(40)
  fonts.dialogue = love.graphics.newFont("fonts/Exo2-Regular.ttf", 18)
  fonts.name_input = love.graphics.newFont(28)
  fonts.npc_name = love.graphics.newFont(22)
  fonts.small = love.graphics.newFont(14)
  fonts.choice = love.graphics.newFont(16)
  fonts.tiny = love.graphics.newFont(12)
  fonts.exclamation = love.graphics.newFont(32)

  phase = "fade_to_black"
  timer = 0
  playerName = ""
  selectedOption = 1
  cursorBlink = 0
  cursorVisible = true
  eyeOpenProgress = 0
  glowTimer = 0
  directorVisible = false
  directorEntering = false
  directorLeaving = false
  exclamationVisible = false

  -- Medic position (center-ish, looking at player)
  medicX = screenW / 2
  medicY = screenH / 2 - 60

  -- Director starts off-screen right
  directorX = screenW + 50
  directorY = screenH / 2 - 40

  setDialogue("")
end

function M.update(dt)
  timer = timer + dt
  glowTimer = glowTimer + dt

  -- Typewriter text reveal
  if not textFullyRevealed and #currentDialogueText > 0 then
    textRevealTimer = textRevealTimer + dt
    revealedChars = revealedChars + dt / textRevealSpeed
    if revealedChars >= #currentDialogueText then
      revealedChars = #currentDialogueText
      textFullyRevealed = true
    end
  end

  -- Cursor blink for name entry
  cursorBlink = cursorBlink + dt
  if cursorBlink >= 0.5 then
    cursorBlink = 0
    cursorVisible = not cursorVisible
  end

  -- Phase-specific updates
  if phase == "fade_to_black" then
    -- 1.5 second fade to black
    if timer >= 1.5 then
      phase = "eye_opening"
      timer = 0
      eyeOpenProgress = 0
    end

  elseif phase == "eye_opening" then
    eyeOpenProgress = eyeOpenProgress + eyeOpenSpeed * dt
    if eyeOpenProgress >= 1 then
      eyeOpenProgress = 1
      -- Brief pause then medic speaks
      if timer >= 3.0 then
        phase = "medic_greeting"
        timer = 0
        setDialogueQueue({
          "Greetings!",
          "Glad to see you're finally awake.",
          "You were asleep for a long time...",
          "Tell me, what is your name?"
        })
      end
    end

  elseif phase == "medic_greeting" then
    -- Wait for player to press E/Enter after text is revealed
    -- (handled in keypressed)

  elseif phase == "name_entry" then
    -- Player types their name (handled in keypressed/textinput)

  elseif phase == "medic_mission_ask" then
    -- Wait for text, then show choices

  elseif phase == "mission_choice" then
    -- Player picks option (handled in keypressed)

  elseif phase == "medic_knows" then
    -- Wait for player to advance

  elseif phase == "medic_explain_1" then
    -- Wait for player to advance

  elseif phase == "director_exclamation" then
    exclamationTimer = exclamationTimer + dt
    if exclamationTimer >= 1.5 then
      phase = "director_enters"
      timer = 0
      directorEntering = true
      directorEnterTimer = 0
      exclamationVisible = false
    end

  elseif phase == "director_enters" then
    directorEnterTimer = directorEnterTimer + dt
    -- Walk director from right side to position
    local targetX = screenW / 2 + 100
    local progress = math.min(directorEnterTimer / 1.5, 1)
    directorX = screenW + 50 + (targetX - (screenW + 50)) * progress
    directorVisible = true
    if progress >= 1 then
      directorX = targetX
      phase = "director_speak_1"
      timer = 0
      setDialogueQueue({
        "And that's where you come in...",
        "Our scans have reported that the surrounding sectors may contain some of our missing notes."
      })
    end

  elseif phase == "director_speak_1" then
    -- Wait for player to advance

  elseif phase == "player_notes_q" then
    -- Brief auto-advance
    if timer >= 1.5 then
      phase = "director_speak_2"
      timer = 0
      setDialogueQueue({
        "Yeah, Notes.",
        "Music notes.",
        "If we can get enough notes, we can put our music back together and get back on the air!",
        "But ever since the Glitch, we've also had our hands full with The Swarm..."
      })
    end

  elseif phase == "player_swarm_q" then
    -- Brief auto-advance
    if timer >= 1.5 then
      phase = "director_speak_3"
      timer = 0
      setDialogueQueue({
        "Pretty much, they're a root armada determined to keep every single note for themselves.",
        "Wave after wave, the Swarm spreads only the sound of silence.",
        "But with that fancy Starwing of yours, you've got the best shot out of all of us to get our music back.",
        "So...whaddya say?",
        "Will you help us stop the Swarm and bring back music to the cosmos?"
      })
    end

  elseif phase == "director_speak_2" then
    -- Wait for player to advance

  elseif phase == "director_speak_3" then
    -- Wait for player to advance

  elseif phase == "player_answer" then
    -- Player picks Yes/Maybe/Too much trouble

  elseif phase == "director_spirit" then
    -- Wait for player to advance

  elseif phase == "director_leaves" then
    directorLeaveTimer = (directorLeaveTimer or 0) + dt
    local progress = math.min(directorLeaveTimer / 1.5, 1)
    directorX = (screenW / 2 + 100) + (screenW + 50 - (screenW / 2 + 100)) * progress
    if progress >= 1 then
      directorVisible = false
      phase = "medic_closing"
      timer = 0
      setDialogueQueue({
        "Yeah that's the Director.",
        "He's been going stir crazy without hearing from fans calling into his radio show.",
        "He's been trying to recruit anybody with a pulse to go fly missions to look for Notes.",
        "Can't say I blame him either, it's been way too quiet around here for a long time now...",
        "Anyway, I'll get you patched up and on your way.",
        "Good luck out there..."
      })
    end

  elseif phase == "medic_closing" then
    -- Wait for player to advance

  elseif phase == "end_cutscene" then
    if timer >= 1.5 then
      if M.onComplete then
        M.onComplete(playerName)
      end
    end
  end
end

function M.draw()
  screenW, screenH = love.graphics.getDimensions()

  if phase == "fade_to_black" then
    -- Fade from whatever was before to black
    local alpha = math.min(timer / 1.0, 1)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    return
  end

  -- Draw the medical room background
  M.drawMedicalRoom()

  -- Draw Medic NPC (angelic, glowing)
  M.drawMedic()

  -- Draw Director NPC if visible
  if directorVisible then
    M.drawDirector()
  end

  -- Draw exclamation mark if visible
  if exclamationVisible then
    M.drawExclamation()
  end

  -- Draw eye opening mask on top
  if phase == "eye_opening" and eyeOpenProgress < 1 then
    M.drawEyeMask()
  end

  -- Draw dialogue / UI based on phase
  if phase == "medic_greeting" then
    M.drawDialogueBox("Medic", getRevealedText(), {0.8, 0.9, 1.0})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "name_entry" then
    M.drawDialogueBox("Medic", "Tell me, what is your name?", {0.8, 0.9, 1.0})
    M.drawNameEntry()

  elseif phase == "medic_mission_ask" then
    M.drawDialogueBox("Medic", getRevealedText(), {0.8, 0.9, 1.0})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "mission_choice" then
    M.drawDialogueBox("Medic", "Now, tell me...what is your mission?", {0.8, 0.9, 1.0})
    M.drawChoices({
      'Yeah, I know...to defeat the Swarm and bring music back to the galaxy',
      'Mission??'
    })

  elseif phase == "medic_knows" then
    M.drawDialogueBox("Medic", getRevealedText(), {0.8, 0.9, 1.0})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "medic_explain_1" then
    M.drawDialogueBox("Medic", getRevealedText(), {0.8, 0.9, 1.0})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "director_exclamation" then
    M.drawDialogueBox("Medic", "...we don't have any music.", {0.8, 0.9, 1.0})

  elseif phase == "director_enters" then
    -- No dialogue during walk-in

  elseif phase == "director_speak_1" then
    M.drawDialogueBox("Director", getRevealedText(), {1.0, 0.85, 0.5})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "player_notes_q" then
    M.drawDialogueBox(playerName ~= "" and playerName or "You", "Notes?", {0.6, 0.8, 1.0})

  elseif phase == "director_speak_2" then
    M.drawDialogueBox("Director", getRevealedText(), {1.0, 0.85, 0.5})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "player_swarm_q" then
    M.drawDialogueBox(playerName ~= "" and playerName or "You", "Swarm?", {0.6, 0.8, 1.0})

  elseif phase == "director_speak_3" then
    M.drawDialogueBox("Director", getRevealedText(), {1.0, 0.85, 0.5})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "player_answer" then
    M.drawDialogueBox("Director", "...whaddya say? Will you help us stop the Swarm and bring back music to the cosmos?", {1.0, 0.85, 0.5})
    M.drawChoices({
      "Yes",
      "Maybe...",
      "Sounds like too much trouble"
    })

  elseif phase == "director_spirit" then
    M.drawDialogueBox("Director", getRevealedText(), {1.0, 0.85, 0.5})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "director_leaves" then
    -- Director walking away, no dialogue

  elseif phase == "medic_closing" then
    M.drawDialogueBox("Medic", getRevealedText(), {0.8, 0.9, 1.0})
    if textFullyRevealed then
      M.drawAdvanceHint()
    end

  elseif phase == "end_cutscene" then
    -- Fade to black
    local alpha = math.min(timer / 1.0, 1)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  end
end

-- ═══════════════════════════════════════
-- DRAWING HELPERS
-- ═══════════════════════════════════════

function M.drawMedicalRoom()
  -- Dark medical bay background
  love.graphics.setColor(0.05, 0.06, 0.1)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Floor tiles
  for x = 0, math.ceil(screenW / 32) do
    for y = math.floor(screenH * 0.6 / 32), math.ceil(screenH / 32) do
      local shade = 0.08 + 0.02 * ((x + y) % 2)
      love.graphics.setColor(shade, shade, shade + 0.02)
      love.graphics.rectangle("fill", x * 32, y * 32, 31, 31)
    end
  end

  -- Walls
  love.graphics.setColor(0.08, 0.08, 0.14)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH * 0.4)

  -- Wall accent line
  love.graphics.setColor(0.1, 0.3, 0.5, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.line(0, screenH * 0.4, screenW, screenH * 0.4)

  -- Medical cross on wall
  local crossX = screenW / 2
  local crossY = screenH * 0.2
  love.graphics.setColor(0.8, 0.1, 0.1, 0.6)
  love.graphics.rectangle("fill", crossX - 5, crossY - 15, 10, 30)
  love.graphics.rectangle("fill", crossX - 15, crossY - 5, 30, 10)

  -- Subtle blue ambient lights on ceiling
  for i = 1, 5 do
    local lx = screenW * i / 6
    local pulse = 0.3 + 0.15 * math.sin(glowTimer * 1.2 + i)
    love.graphics.setColor(0.2, 0.4, 0.8, pulse)
    love.graphics.circle("fill", lx, 20, 8)
    love.graphics.setColor(0.2, 0.4, 0.8, pulse * 0.3)
    love.graphics.circle("fill", lx, 20, 25)
  end

  -- Medical bed (patient's POV - we see the foot of the bed)
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", screenW / 2 - 80, screenH * 0.7, 160, 20, 4)
  love.graphics.setColor(0.2, 0.22, 0.3)
  love.graphics.rectangle("fill", screenW / 2 - 75, screenH * 0.72, 150, 15, 3)

  -- Door on the right side
  love.graphics.setColor(0.12, 0.12, 0.18)
  love.graphics.rectangle("fill", screenW - 100, screenH * 0.2, 50, screenH * 0.2 + 50)
  love.graphics.setColor(0.2, 0.3, 0.4, 0.5)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", screenW - 100, screenH * 0.2, 50, screenH * 0.2 + 50)
end

function M.drawMedic()
  local mx, my = medicX, medicY
  local t = glowTimer

  -- Body idle bob
  local bob = math.sin(t * 1.5) * 1

  -- Shadow
  love.graphics.setColor(0.3, 0.3, 0.35, 0.2)
  love.graphics.ellipse("fill", mx, my + 22, 12, 5)

  -- Feet (white nursing shoes)
  love.graphics.setColor(0.9, 0.9, 0.92)
  love.graphics.rectangle("fill", mx - 6, my + 16 + bob, 5, 5)
  love.graphics.rectangle("fill", mx + 1, my + 16 + bob, 5, 5)

  -- Legs (navy scrub pants)
  love.graphics.setColor(0.15, 0.2, 0.4)
  love.graphics.rectangle("fill", mx - 5, my + 8 + bob, 10, 9)

  -- Scrub top (teal/medical blue)
  love.graphics.setColor(0.2, 0.6, 0.65)
  love.graphics.rectangle("fill", mx - 8, my - 8 + bob, 16, 17)

  -- V-neck detail
  love.graphics.setColor(0.15, 0.5, 0.55)
  love.graphics.polygon("fill", mx - 2, my - 8 + bob, mx + 2, my - 8 + bob, mx, my - 4 + bob)

  -- Pocket on scrub top
  love.graphics.setColor(0.18, 0.55, 0.6)
  love.graphics.rectangle("fill", mx + 2, my - 3 + bob, 5, 5)
  -- Pen in pocket
  love.graphics.setColor(0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", mx + 4, my - 5 + bob, 1, 5)

  -- Arms (scrub sleeves)
  love.graphics.setColor(0.2, 0.6, 0.65)
  love.graphics.rectangle("fill", mx - 11, my - 6 + bob, 4, 8)
  love.graphics.rectangle("fill", mx + 7, my - 6 + bob, 4, 8)

  -- Forearms (skin)
  love.graphics.setColor(0.88, 0.75, 0.65)
  love.graphics.rectangle("fill", mx - 11, my + 1 + bob, 4, 5)
  love.graphics.rectangle("fill", mx + 7, my + 1 + bob, 4, 5)

  -- Hands
  love.graphics.setColor(0.88, 0.75, 0.65)
  love.graphics.rectangle("fill", mx - 11, my + 5 + bob, 4, 3)
  love.graphics.rectangle("fill", mx + 7, my + 5 + bob, 4, 3)

  -- Clipboard in hand
  love.graphics.setColor(0.6, 0.5, 0.35)
  love.graphics.rectangle("fill", mx + 8, my + 2 + bob, 6, 8, 1)
  love.graphics.setColor(0.9, 0.88, 0.82)
  love.graphics.rectangle("fill", mx + 9, my + 3 + bob, 4, 6, 1)

  -- Head
  love.graphics.setColor(0.9, 0.78, 0.66)
  love.graphics.rectangle("fill", mx - 6, my - 20 + bob, 12, 12)

  -- Hair (brown, tied back in a bun)
  love.graphics.setColor(0.35, 0.22, 0.12)
  love.graphics.rectangle("fill", mx - 7, my - 23 + bob, 14, 6)
  love.graphics.rectangle("fill", mx - 7, my - 19 + bob, 2, 4)
  love.graphics.rectangle("fill", mx + 5, my - 19 + bob, 2, 4)
  -- Bun
  love.graphics.setColor(0.35, 0.22, 0.12)
  love.graphics.circle("fill", mx, my - 24 + bob, 5)

  -- Eyes (warm brown, looking at player)
  love.graphics.setColor(0.95, 0.95, 0.97)
  love.graphics.rectangle("fill", mx - 4, my - 16 + bob, 3, 3)
  love.graphics.rectangle("fill", mx + 1, my - 16 + bob, 3, 3)
  love.graphics.setColor(0.35, 0.22, 0.12)
  love.graphics.rectangle("fill", mx - 3, my - 15 + bob, 2, 2)
  love.graphics.rectangle("fill", mx + 2, my - 15 + bob, 2, 2)

  -- Friendly smile
  love.graphics.setColor(0.75, 0.45, 0.45)
  love.graphics.rectangle("fill", mx - 2, my - 11 + bob, 4, 1)

  -- Name badge / ID lanyard
  love.graphics.setColor(0.3, 0.3, 0.35)
  love.graphics.setLineWidth(1)
  love.graphics.line(mx - 2, my - 8 + bob, mx - 2, my - 4 + bob)
  love.graphics.setColor(0.9, 0.9, 0.92)
  love.graphics.rectangle("fill", mx - 5, my - 3 + bob, 6, 4, 1)
  love.graphics.setColor(0.85, 0.15, 0.15)
  love.graphics.rectangle("fill", mx - 4, my - 2 + bob, 1, 2)
end

function M.drawDirector()
  local dx, dy = directorX, directorY
  local t = glowTimer
  local bob = math.sin(t * 1.5 + 1) * 1

  -- Walking animation if entering or leaving
  local footOffset = 0
  if directorEntering or directorLeaving then
    footOffset = math.sin(t * 10) * 2
  end

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.ellipse("fill", dx, dy + 22, 12, 5)

  -- Feet
  love.graphics.setColor(0.2, 0.2, 0.25)
  love.graphics.rectangle("fill", dx - 6, dy + 16 + bob + footOffset, 5, 5)
  love.graphics.rectangle("fill", dx + 1, dy + 16 + bob - footOffset, 5, 5)

  -- Legs
  love.graphics.setColor(0.15, 0.15, 0.25)
  love.graphics.rectangle("fill", dx - 5, dy + 8 + bob, 10, 9)

  -- Body (dark blue uniform/jacket)
  love.graphics.setColor(0.12, 0.18, 0.35)
  love.graphics.rectangle("fill", dx - 8, dy - 8 + bob, 16, 17)

  -- Rank stripes
  love.graphics.setColor(0.8, 0.7, 0.2, 0.8)
  love.graphics.rectangle("fill", dx + 5, dy - 6 + bob, 2, 4)
  love.graphics.rectangle("fill", dx + 5, dy - 1 + bob, 2, 4)

  -- Arms
  love.graphics.setColor(0.12, 0.18, 0.35)
  love.graphics.rectangle("fill", dx - 11, dy - 6 + bob, 4, 12)
  love.graphics.rectangle("fill", dx + 7, dy - 6 + bob, 4, 12)

  -- Hands
  love.graphics.setColor(0.75, 0.6, 0.5)
  love.graphics.rectangle("fill", dx - 11, dy + 5 + bob, 4, 3)
  love.graphics.rectangle("fill", dx + 7, dy + 5 + bob, 4, 3)

  -- Head
  love.graphics.setColor(0.78, 0.63, 0.52)
  love.graphics.rectangle("fill", dx - 6, dy - 20 + bob, 12, 12)

  -- Hair (short, dark)
  love.graphics.setColor(0.15, 0.12, 0.1)
  love.graphics.rectangle("fill", dx - 7, dy - 23 + bob, 14, 6)

  -- Eyes
  love.graphics.setColor(0.15, 0.15, 0.2)
  love.graphics.rectangle("fill", dx - 4, dy - 16 + bob, 3, 2)
  love.graphics.rectangle("fill", dx + 1, dy - 16 + bob, 3, 2)
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", dx - 3, dy - 16 + bob, 1, 1)
  love.graphics.rectangle("fill", dx + 2, dy - 16 + bob, 1, 1)

  -- Mouth
  love.graphics.setColor(0.6, 0.4, 0.4)
  love.graphics.rectangle("fill", dx - 2, dy - 11 + bob, 4, 1)
end

function M.drawExclamation()
  -- Pokemon-style exclamation mark (no speech bubble, just the mark)
  local ex = screenW - 75  -- near the door
  local ey = screenH * 0.2 - 30
  local bounce = math.abs(math.sin(exclamationTimer * 6)) * 8

  love.graphics.setColor(1, 0.9, 0.2, 1)
  love.graphics.setFont(fonts.exclamation)
  love.graphics.print("!", ex, ey - bounce)
end

function M.drawEyeMask()
  -- Draw a black eye-shaped mask that opens from center
  -- When eyeOpenProgress = 0, screen is all black
  -- When eyeOpenProgress = 1, fully open
  local cx = screenW / 2
  local cy = screenH / 2

  -- The opening is an ellipse that grows
  local maxRadX = screenW * 0.8
  local maxRadY = screenH * 0.5
  local radX = maxRadX * eyeOpenProgress
  local radY = maxRadY * eyeOpenProgress

  -- Use stencil to mask everything outside the eye shape
  love.graphics.stencil(function()
    -- Eye shape: two arcs forming an almond/eye
    local segments = 60
    local points = {}

    -- Top lid curve
    for i = 0, segments do
      local t = i / segments
      local angle = math.pi * t
      local x = cx + radX * math.cos(angle)
      local y = cy - radY * math.sin(angle) * math.sin(math.pi * t)
      table.insert(points, x)
      table.insert(points, y)
    end

    -- Bottom lid curve (reverse)
    for i = segments, 0, -1 do
      local t = i / segments
      local angle = math.pi * t
      local x = cx + radX * math.cos(angle)
      local y = cy + radY * math.sin(angle) * math.sin(math.pi * t)
      table.insert(points, x)
      table.insert(points, y)
    end

    if #points >= 6 then
      love.graphics.polygon("fill", points)
    end
  end, "replace", 1)

  -- Draw black everywhere EXCEPT inside the eye (stencil = 0)
  love.graphics.setStencilTest("equal", 0)
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)
  love.graphics.setStencilTest()

  -- Draw eyelid edges
  if eyeOpenProgress > 0.05 and eyeOpenProgress < 0.95 then
    love.graphics.setColor(0.02, 0.02, 0.04, 0.8)
    love.graphics.setLineWidth(4)

    -- Top eyelid edge
    local topPoints = {}
    local segments = 60
    for i = 0, segments do
      local t = i / segments
      local angle = math.pi * t
      local x = cx + radX * math.cos(angle)
      local y = cy - radY * math.sin(angle) * math.sin(math.pi * t)
      table.insert(topPoints, x)
      table.insert(topPoints, y)
    end
    if #topPoints >= 4 then
      love.graphics.line(topPoints)
    end

    -- Bottom eyelid edge
    local botPoints = {}
    for i = 0, segments do
      local t = i / segments
      local angle = math.pi * t
      local x = cx + radX * math.cos(angle)
      local y = cy + radY * math.sin(angle) * math.sin(math.pi * t)
      table.insert(botPoints, x)
      table.insert(botPoints, y)
    end
    if #botPoints >= 4 then
      love.graphics.line(botPoints)
    end
  end
end

function M.drawDialogueBox(speaker, text, color)
  color = color or {1, 1, 1}
  local boxX = 80
  local boxY = screenH - 200
  local boxW = screenW - 160
  local boxH = 150

  -- Box background
  love.graphics.setColor(0.02, 0.02, 0.06, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6)

  -- Neon border
  love.graphics.setColor(color[1], color[2], color[3], 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6)
  -- Glow
  love.graphics.setColor(color[1], color[2], color[3], 0.15)
  love.graphics.setLineWidth(6)
  love.graphics.rectangle("line", boxX - 2, boxY - 2, boxW + 4, boxH + 4, 8)
  love.graphics.setLineWidth(1)

  -- Speaker name
  love.graphics.setFont(fonts.npc_name)
  love.graphics.setColor(color[1], color[2], color[3], 1)
  love.graphics.print(speaker, boxX + 20, boxY + 12)

  -- Dialogue text
  love.graphics.setFont(fonts.dialogue)
  love.graphics.setColor(0.9, 0.9, 0.95)
  love.graphics.printf(text, boxX + 20, boxY + 45, boxW - 40, "left")
end

function M.drawAdvanceHint()
  local pulse = 0.4 + 0.4 * math.sin(glowTimer * 3)
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.5, 0.5, 0.6, pulse)
  love.graphics.printf("Press ENTER to continue", 0, screenH - 55, screenW, "center")
end

function M.drawNameEntry()
  local boxX = screenW / 2 - 200
  local boxY = screenH / 2 + 40
  local boxW = 400
  local boxH = 50

  -- Input box
  love.graphics.setColor(0.08, 0.08, 0.14, 0.95)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 4)
  love.graphics.setColor(0.3, 0.6, 0.9, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 4)

  -- Name text
  love.graphics.setFont(fonts.name_input)
  love.graphics.setColor(1, 1, 1)
  local displayText = playerName
  if cursorVisible then
    displayText = displayText .. "_"
  end
  love.graphics.printf(displayText, boxX + 15, boxY + 10, boxW - 30, "center")

  -- Character count
  love.graphics.setFont(fonts.tiny)
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.printf(#playerName .. "/" .. maxNameLength, boxX, boxY + boxH + 5, boxW, "right")

  -- Hint
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.printf("Type your name, then press ENTER", 0, boxY + boxH + 25, screenW, "center")

  if #playerName == 0 then
    love.graphics.setColor(0.7, 0.4, 0.4)
    love.graphics.printf("Name cannot be empty", 0, boxY + boxH + 45, screenW, "center")
  end
end

function M.drawChoices(choices)
  local choiceY = screenH - 200 - #choices * 35 - 10
  local choiceW = 600
  local choiceX = screenW / 2 - choiceW / 2

  for i, choice in ipairs(choices) do
    local y = choiceY + (i - 1) * 35

    if i == selectedOption then
      -- Selected highlight
      love.graphics.setColor(0.1, 0.2, 0.35, 0.95)
      love.graphics.rectangle("fill", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.3, 0.7, 1.0, 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", choiceX, y, choiceW, 30, 4)

      -- Arrow
      love.graphics.setColor(0.3, 0.7, 1.0)
      love.graphics.setFont(fonts.choice)
      love.graphics.print("▶ " .. choice, choiceX + 15, y + 6)
    else
      love.graphics.setColor(0.05, 0.05, 0.1, 0.85)
      love.graphics.rectangle("fill", choiceX, y, choiceW, 30, 4)
      love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", choiceX, y, choiceW, 30, 4)

      love.graphics.setColor(0.6, 0.6, 0.7)
      love.graphics.setFont(fonts.choice)
      love.graphics.print("  " .. choice, choiceX + 15, y + 6)
    end
  end
end

function M.keypressed(key)
  -- Phase-specific key handling

  if phase == "medic_greeting" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "name_entry"
        timer = 0
      end
    end

  elseif phase == "name_entry" then
    if key == "return" then
      if #playerName > 0 then
        phase = "medic_mission_ask"
        timer = 0
        setDialogueQueue({
          "Thanks, " .. playerName .. "!",
          "Now, tell me...what is your mission?"
        })
      end
    elseif key == "backspace" then
      if #playerName > 0 then
        playerName = playerName:sub(1, -2)
      end
    end

  elseif phase == "medic_mission_ask" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "mission_choice"
        timer = 0
        selectedOption = 1
      end
    end

  elseif phase == "mission_choice" then
    if key == "up" then
      selectedOption = selectedOption - 1
      if selectedOption < 1 then selectedOption = 2 end
    elseif key == "down" then
      selectedOption = selectedOption + 1
      if selectedOption > 2 then selectedOption = 1 end
    elseif key == "return" or key == "e" then
      if selectedOption == 1 then
        -- "Yeah, I know..."
        phase = "medic_knows"
        timer = 0
        setDialogueQueue({
          "Great!",
          "Looks like you're ready to rock and roll.",
          "I'll get you patched up and back on your way to the flight deck."
        })
      else
        -- "Mission??"
        phase = "medic_explain_1"
        timer = 0
        setDialogueQueue({
          "OK, I can help fill you in.",
          "So...you're at Hometown Station.",
          "This station used to broadcast all kinds of music to the whole galaxy.",
          "But one year ago, there was an event we now call the Glitch.",
          "It felt like everything was in suspended animation...",
          "No one here remembers how it happened, but when the Studio checked their radio equipment, it was all fried.",
          "And all our music was blanked, files, vinyl...even the sheet music.",
          "Since then, Engineering got the station back up, but our signal only reaches a few sectors away.",
          "And yeah, we don't have any music."
        })
      end
    end

  elseif phase == "medic_knows" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "end_cutscene"
        timer = 0
      end
    end

  elseif phase == "medic_explain_1" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        -- Director overhears
        phase = "director_exclamation"
        timer = 0
        exclamationVisible = true
        exclamationTimer = 0
      end
    end

  elseif phase == "director_speak_1" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "player_notes_q"
        timer = 0
        setDialogue("Notes?")
      end
    end

  elseif phase == "director_speak_2" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "player_swarm_q"
        timer = 0
        setDialogue("Swarm?")
      end
    end

  elseif phase == "director_speak_3" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "player_answer"
        timer = 0
        selectedOption = 1
      end
    end

  elseif phase == "player_answer" then
    if key == "up" then
      selectedOption = selectedOption - 1
      if selectedOption < 1 then selectedOption = 3 end
    elseif key == "down" then
      selectedOption = selectedOption + 1
      if selectedOption > 3 then selectedOption = 1 end
    elseif key == "return" or key == "e" then
      -- No matter what player says:
      phase = "director_spirit"
      timer = 0
      setDialogueQueue({
        "That's the spirit!",
        "An associate will greet you on Deck 4 when you leave Medical to give you the grand tour.",
        "Best of luck, pilot!"
      })
    end

  elseif phase == "director_spirit" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        -- Director leaves
        phase = "director_leaves"
        timer = 0
        directorLeaving = true
        directorLeaveTimer = 0
      end
    end

  elseif phase == "medic_closing" then
    if not textFullyRevealed then
      textFullyRevealed = true
      revealedChars = #currentDialogueText
    elseif key == "return" or key == "e" then
      if not advanceDialogueQueue() then
        phase = "end_cutscene"
        timer = 0
      end
    end
  end
end

function M.textinput(text)
  if phase == "name_entry" then
    if #playerName < maxNameLength then
      if text:match("^[%w ]$") then
        playerName = playerName .. text
      end
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not used
end

return M
