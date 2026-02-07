-- hub/lookout.lua
-- Lookout observation deck on Floor 5
-- Skyfall Macau-inspired purple neon luxury lounge
-- Features: panoramic galaxy view, high scores, time played, piano robot NPC

local M = {}

M.active = false
M.time = 0
M.tab = "view" -- "view", "scores", "stats"
M.pianoNotes = {} -- animated falling piano notes
M.pianoTimer = 0
M.showingPianoDialogue = false
M.dialogueIndex = 1

-- Piano robot dialogue
M.pianoDialogue = {
  "♪ ... Ah, a visitor. Please, take in the view.",
  "I am Unit P-88. I've been playing for 4,327 station-cycles.",
  "Music is mathematics made audible. Space is mathematics made visible.",
  "The crew sometimes requests songs. I know 12,000 compositions.",
  "My personal favorite? Clair de Lune. It matches the starlight perfectly.",
  "Would you like to hear something? Just say the word... metaphorically.",
  "The high scores board is over there. Quite competitive, this crew.",
  "♪ ... Forgive me, I lose myself in the melody sometimes.",
}

function M.enter()
  M.active = true
  M.time = 0
  M.tab = "view"
  M.showingPianoDialogue = false
  M.dialogueIndex = 1
  M.pianoNotes = {}
end

function M.exit()
  M.active = false
end

function M.update(dt)
  if not M.active then return end
  M.time = M.time + dt

  -- Piano note particles
  M.pianoTimer = M.pianoTimer + dt
  if M.pianoTimer > 0.3 then
    M.pianoTimer = 0
    table.insert(M.pianoNotes, {
      x = 100 + math.random() * 200,
      y = 500,
      vy = -30 - math.random() * 40,
      vx = (math.random() - 0.5) * 20,
      alpha = 0.8,
      note = ({"♪", "♫", "♩", "♬"})[math.random(1, 4)],
      color = {0.6 + math.random() * 0.4, 0.3 + math.random() * 0.3, 0.8 + math.random() * 0.2}
    })
  end

  -- Update piano notes
  for i = #M.pianoNotes, 1, -1 do
    local note = M.pianoNotes[i]
    note.x = note.x + note.vx * dt
    note.y = note.y + note.vy * dt
    note.alpha = note.alpha - dt * 0.3
    if note.alpha <= 0 then
      table.remove(M.pianoNotes, i)
    end
  end
end

function M.keypressed(key)
  if not M.active then return false end

  if key == "escape" then
    if M.showingPianoDialogue then
      M.showingPianoDialogue = false
    else
      M.exit()
    end
    return true
  end

  if M.showingPianoDialogue then
    if key == "return" then
      M.dialogueIndex = M.dialogueIndex + 1
      if M.dialogueIndex > #M.pianoDialogue then
        M.showingPianoDialogue = false
      end
    end
    return true
  end

  if key == "left" then
    if M.tab == "scores" then M.tab = "view"
    elseif M.tab == "stats" then M.tab = "scores" end
    return true
  elseif key == "right" then
    if M.tab == "view" then M.tab = "scores"
    elseif M.tab == "scores" then M.tab = "stats" end
    return true
  elseif key == "return" or key == "p" then
    M.showingPianoDialogue = true
    M.dialogueIndex = 1
    return true
  end

  return false
end

-- Draw the panoramic galaxy view
local function drawPanorama(screenW, screenH, time)
  -- Deep space background with purple/blue tint (Skyfall Macau)
  love.graphics.setColor(0.03, 0.01, 0.06)
  love.graphics.rectangle("fill", 0, 60, screenW, screenH - 120)

  -- Galaxy spiral
  local cx, cy = screenW/2, screenH/2 - 40
  for i = 0, 300 do
    local angle = i * 0.12 + time * 0.05
    local radius = i * 2
    local sx = cx + math.cos(angle) * radius
    local sy = cy + math.sin(angle) * radius * 0.35
    local alpha = 0.04 * (1 - i / 300)
    if sx > 0 and sx < screenW and sy > 60 and sy < screenH - 60 then
      love.graphics.setColor(0.5, 0.3, 0.8, alpha)
      love.graphics.circle("fill", sx, sy, 4)
    end
  end

  -- Stars
  for i = 1, 100 do
    local sx = (math.sin(i * 7.3) * 0.5 + 0.5) * screenW
    local sy = 60 + (math.cos(i * 11.7) * 0.5 + 0.5) * (screenH - 120)
    local twinkle = 0.3 + 0.7 * math.abs(math.sin(time * (1 + i * 0.05) + i))
    love.graphics.setColor(0.8, 0.85, 1.0, twinkle * 0.6)
    love.graphics.circle("fill", sx, sy, 0.5 + twinkle)
  end

  -- Distant planet
  local planetX = screenW * 0.75
  local planetY = screenH * 0.35
  -- Atmosphere glow
  love.graphics.setColor(0.2, 0.4, 0.8, 0.08)
  love.graphics.circle("fill", planetX, planetY, 65)
  love.graphics.setColor(0.1, 0.2, 0.4, 0.15)
  love.graphics.circle("fill", planetX, planetY, 50)
  -- Planet body
  love.graphics.setColor(0.08, 0.15, 0.3)
  love.graphics.circle("fill", planetX, planetY, 40)
  -- Terminator line
  love.graphics.setColor(0.05, 0.1, 0.2)
  love.graphics.arc("fill", planetX, planetY, 40, math.pi * 0.6, math.pi * 1.4)
  -- Ring
  love.graphics.setColor(0.4, 0.35, 0.5, 0.2)
  love.graphics.ellipse("line", planetX, planetY, 70, 15)
end

-- Draw high scores board
local function drawHighScores(screenW, screenH, highScores)
  local boardX = screenW * 0.15
  local boardY = 100
  local boardW = screenW * 0.7
  local boardH = screenH * 0.6

  -- Board background
  love.graphics.setColor(0.03, 0.02, 0.05, 0.9)
  love.graphics.rectangle("fill", boardX, boardY, boardW, boardH, 6)

  -- Neon border
  love.graphics.setColor(0.6, 0.2, 0.8, 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boardX, boardY, boardW, boardH, 6)
  love.graphics.setLineWidth(1)

  -- Title
  love.graphics.setColor(0.8, 0.4, 1.0)
  love.graphics.printf("★ HIGH SCORES ★", boardX, boardY + 15, boardW, "center")

  -- Column headers
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.print("RANK", boardX + 30, boardY + 50)
  love.graphics.print("LEVEL", boardX + 100, boardY + 50)
  love.graphics.print("SCORE", boardX + boardW - 150, boardY + 50)

  -- Separator line
  love.graphics.setColor(0.6, 0.2, 0.8, 0.3)
  love.graphics.line(boardX + 20, boardY + 68, boardX + boardW - 20, boardY + 68)

  -- Score entries
  local levelNames = {"Corneria", "Meteo", "Sector Y"}
  if highScores then
    local rank = 0
    for levelId = 1, 3 do
      local score = highScores[levelId]
      if score and score > 0 then
        rank = rank + 1
        local entryY = boardY + 80 + (rank - 1) * 35

        -- Rank medal colors
        local medalColors = {{1, 0.85, 0.2}, {0.75, 0.75, 0.8}, {0.8, 0.5, 0.2}}
        local mc = medalColors[rank] or {0.5, 0.5, 0.5}

        love.graphics.setColor(mc[1], mc[2], mc[3])
        love.graphics.print("#" .. rank, boardX + 30, entryY)

        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(levelNames[levelId] or ("Level " .. levelId), boardX + 100, entryY)

        love.graphics.setColor(0.8, 0.8, 1.0)
        love.graphics.printf(tostring(score), boardX + boardW - 200, entryY, 150, "right")
      end
    end

    if rank == 0 then
      love.graphics.setColor(0.5, 0.5, 0.6)
      love.graphics.printf("No scores yet. Complete missions to earn your place!", boardX + 40, boardY + 100, boardW - 80, "center")
    end
  end
end

-- Draw player stats
local function drawStats(screenW, screenH, timePlayed, credits, notes)
  local statX = screenW * 0.2
  local statY = 100
  local statW = screenW * 0.6

  -- Background
  love.graphics.setColor(0.03, 0.02, 0.05, 0.9)
  love.graphics.rectangle("fill", statX, statY, statW, 300, 6)
  love.graphics.setColor(0.6, 0.2, 0.8, 0.7)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", statX, statY, statW, 300, 6)
  love.graphics.setLineWidth(1)

  love.graphics.setColor(0.8, 0.4, 1.0)
  love.graphics.printf("PILOT STATISTICS", statX, statY + 15, statW, "center")

  love.graphics.setColor(0.6, 0.2, 0.8, 0.3)
  love.graphics.line(statX + 20, statY + 40, statX + statW - 20, statY + 40)

  -- Time played
  local hours = math.floor((timePlayed or 0) / 3600)
  local mins = math.floor(((timePlayed or 0) % 3600) / 60)
  local secs = math.floor((timePlayed or 0) % 60)
  love.graphics.setColor(0.7, 0.7, 0.8)
  love.graphics.print("Time in Service:", statX + 40, statY + 60)
  love.graphics.setColor(0.0, 0.8, 1.0)
  love.graphics.print(string.format("%02d:%02d:%02d", hours, mins, secs), statX + 200, statY + 60)

  -- Credits
  love.graphics.setColor(0.7, 0.7, 0.8)
  love.graphics.print("Credits:", statX + 40, statY + 95)
  love.graphics.setColor(0.2, 0.8, 0.2)
  love.graphics.print(tostring(credits or 0) .. " Cr", statX + 200, statY + 95)

  -- Notes
  love.graphics.setColor(0.7, 0.7, 0.8)
  love.graphics.print("Notes:", statX + 40, statY + 130)
  love.graphics.setColor(0.8, 0.8, 0.2)
  love.graphics.print(tostring(notes or 0) .. " ♪", statX + 200, statY + 130)
end

-- Draw the piano robot
local function drawPianoRobot(x, y, time)
  -- Piano
  love.graphics.setColor(0.05, 0.05, 0.05)
  love.graphics.rectangle("fill", x - 40, y + 5, 80, 30, 3)
  -- White keys
  for k = 0, 7 do
    love.graphics.setColor(0.9, 0.9, 0.85)
    love.graphics.rectangle("fill", x - 38 + k * 10, y + 7, 9, 18)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", x - 38 + k * 10, y + 7, 9, 18)
  end
  -- Black keys
  for k = 0, 6 do
    if k ~= 2 and k ~= 5 then
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.rectangle("fill", x - 34 + k * 10, y + 7, 6, 11)
    end
  end

  -- Robot body (sitting at piano)
  local bob = math.sin(time * 2) * 2

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", x, y + 38, 14, 4)

  -- Torso
  love.graphics.setColor(0.4, 0.4, 0.5)
  love.graphics.rectangle("fill", x - 8, y - 10 + bob, 16, 18, 2)

  -- Head
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.rectangle("fill", x - 6, y - 22 + bob, 12, 12, 3)

  -- Eyes (glowing)
  local eyeGlow = 0.5 + 0.5 * math.sin(time * 3)
  love.graphics.setColor(0.2, 0.6, 1.0, eyeGlow)
  love.graphics.circle("fill", x - 3, y - 17 + bob, 2)
  love.graphics.circle("fill", x + 3, y - 17 + bob, 2)

  -- Arms (reaching to piano keys, animated)
  local armAngle = math.sin(time * 4) * 0.15
  love.graphics.setColor(0.35, 0.35, 0.45)
  love.graphics.push()
  love.graphics.translate(x - 8, y - 4 + bob)
  love.graphics.rotate(-0.5 + armAngle)
  love.graphics.rectangle("fill", 0, 0, 3, 15)
  love.graphics.pop()
  love.graphics.push()
  love.graphics.translate(x + 8, y - 4 + bob)
  love.graphics.rotate(0.5 - armAngle)
  love.graphics.rectangle("fill", -3, 0, 3, 15)
  love.graphics.pop()

  -- Antenna
  love.graphics.setColor(0.4, 0.4, 0.5)
  love.graphics.line(x, y - 22 + bob, x, y - 30 + bob)
  love.graphics.setColor(0.8, 0.2, 0.2, 0.6 + 0.4 * math.sin(time * 5))
  love.graphics.circle("fill", x, y - 31 + bob, 2)
end

function M.draw(highScores, timePlayed, credits, notes)
  if not M.active then return end

  local screenW, screenH = love.graphics.getDimensions()

  -- Deep purple/black background (Skyfall Macau)
  love.graphics.setColor(0.02, 0.01, 0.04)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Tab bar at top
  local tabs = {
    {id = "view", label = "PANORAMA"},
    {id = "scores", label = "HIGH SCORES"},
    {id = "stats", label = "PILOT STATS"},
  }
  for i, t in ipairs(tabs) do
    local tx = (i - 1) * (screenW / 3)
    local tw = screenW / 3
    local isActive = M.tab == t.id

    if isActive then
      love.graphics.setColor(0.15, 0.05, 0.2, 0.8)
      love.graphics.rectangle("fill", tx, 0, tw, 50)
      love.graphics.setColor(0.6, 0.2, 0.8)
    else
      love.graphics.setColor(0.05, 0.02, 0.08, 0.8)
      love.graphics.rectangle("fill", tx, 0, tw, 50)
      love.graphics.setColor(0.3, 0.15, 0.4)
    end
    love.graphics.printf(t.label, tx, 16, tw, "center")

    -- Tab separator
    love.graphics.setColor(0.4, 0.15, 0.5, 0.5)
    love.graphics.line(tx + tw, 5, tx + tw, 45)
  end

  -- Tab content
  if M.tab == "view" then
    drawPanorama(screenW, screenH, M.time)
  elseif M.tab == "scores" then
    drawHighScores(screenW, screenH, highScores)
  elseif M.tab == "stats" then
    drawStats(screenW, screenH, timePlayed, credits, notes)
  end

  -- Piano robot (always visible in the corner)
  drawPianoRobot(150, screenH - 120, M.time)

  -- Piano note particles
  for _, note in ipairs(M.pianoNotes) do
    love.graphics.setColor(note.color[1], note.color[2], note.color[3], note.alpha)
    love.graphics.print(note.note, note.x, note.y)
  end

  -- Piano robot interaction prompt
  if not M.showingPianoDialogue then
    love.graphics.setColor(0.5, 0.5, 0.6, 0.5 + 0.3 * math.sin(M.time * 2))
    love.graphics.print("Press P to talk to Unit P-88", 60, screenH - 55)
  end

  -- Piano dialogue
  if M.showingPianoDialogue then
    local dlgY = screenH - 130
    love.graphics.setColor(0.02, 0.01, 0.04, 0.95)
    love.graphics.rectangle("fill", 40, dlgY, screenW - 80, 100, 6)
    love.graphics.setColor(0.5, 0.2, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, dlgY, screenW - 80, 100, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.4, 0.7, 1.0)
    love.graphics.print("Unit P-88:", 60, dlgY + 10)

    local line = M.pianoDialogue[M.dialogueIndex] or ""
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(line, 60, dlgY + 35)

    love.graphics.setColor(0.5, 0.5, 0.6, 0.5 + 0.5 * math.sin(M.time * 3))
    love.graphics.print("ENTER to continue  |  ESC to close", 60, dlgY + 70)
  end

  -- Controls
  love.graphics.setColor(0.4, 0.3, 0.5, 0.6)
  love.graphics.printf("←→ Switch Tab  |  P Talk to P-88  |  ESC Exit", 0, screenH - 22, screenW, "center")
end

return M
