-- hub/studio.lua
-- Sunset Sound-style recording studio on Floor 3 (Residential Deck)
-- DJ NPC manages the station's broadcast system
-- Players can select soundtrack, hear DJ dialogue, see listener feedback
-- Think: radio station + recording studio aesthetic

local M = {}

M.active = false
M.time = 0
M.selectedTrack = 1
M.dialogueIndex = 1
M.showingDialogue = false
M.dialogueTimer = 0
M.vinylAngle = 0
M.eqBars = {}
M.vuLevel = 0
M.broadcasting = false

-- Soundtrack catalog
M.tracks = {
  {id = "station_ambient", name = "Station Hum", artist = "Ambient Systems", genre = "Ambient", mood = "calm"},
  {id = "neon_nights", name = "Neon Nights", artist = "The Coruscant Drifters", genre = "Synthwave", mood = "chill"},
  {id = "hyperspace_funk", name = "Hyperspace Funk", artist = "Parsec Groove", genre = "Funk", mood = "upbeat"},
  {id = "void_echoes", name = "Void Echoes", artist = "Deep Space Collective", genre = "Ambient", mood = "eerie"},
  {id = "stellar_jazz", name = "Stellar Jazz", artist = "Blue Nebula Quartet", genre = "Jazz", mood = "smooth"},
  {id = "combat_ready", name = "Combat Ready", artist = "Afterburner", genre = "Electronic", mood = "intense"},
  {id = "casino_royale", name = "High Stakes", artist = "Lady Luck", genre = "Lounge", mood = "classy"},
  {id = "homeward_bound", name = "Homeward Bound", artist = "Stardust Symphony", genre = "Orchestral", mood = "nostalgic"},
}

-- DJ dialogue lines
M.dialogueLines = {
  "Welcome to Studio 3, the heartbeat of the station!",
  "We're broadcasting across all seven floors right now.",
  "Pick a track and I'll spin it for the whole station to hear.",
  "The crew's been requesting more synthwave lately...",
  "Nothing keeps morale up like good music during a long tour.",
  "This console? Custom-built. Best sound system in the quadrant.",
  "Between you and me, Floor 5's piano robot requests the jazz tracks a lot.",
  "We got listeners tuning in from three sectors away!",
  "The Mainstage next door handles live acts. I handle everything else.",
  "You want to know the secret? It's all about the bass frequencies in zero-G.",
}

-- Listener feedback messages (rotate periodically)
M.feedbackMessages = {
  {from = "Floor 2 - Casino", msg = "Great pick! The card tables are vibing."},
  {from = "Floor 4 - Hangar", msg = "Mechanics love this one, keep it going!"},
  {from = "Floor 1 - Warehouse", msg = "The loaders are moving faster now, haha."},
  {from = "Floor 5 - Lookout", msg = "Perfect soundtrack for stargazing."},
  {from = "Docked Ship - Wanderer", msg = "Can hear you on our comms. Nice."},
  {from = "Floor 3 - Hotel", msg = "Guests are complimenting the ambience!"},
  {from = "External - Sector 7", msg = "Picking up your signal out here. Sounds great."},
}
M.currentFeedback = 1
M.feedbackTimer = 0

-- Initialize EQ bars
for i = 1, 16 do
  M.eqBars[i] = 0
end

function M.enter()
  M.active = true
  M.time = 0
  M.dialogueIndex = 1
  M.showingDialogue = true
  M.dialogueTimer = 0
  M.feedbackTimer = 0
  M.currentFeedback = 1
end

function M.exit()
  M.active = false
end

function M.update(dt)
  if not M.active then return end

  M.time = M.time + dt
  M.vinylAngle = M.vinylAngle + dt * 3

  -- Animate EQ bars
  for i = 1, 16 do
    if M.broadcasting then
      local target = 0.2 + 0.6 * math.abs(math.sin(M.time * (3 + i * 0.5) + i * 0.7))
      M.eqBars[i] = M.eqBars[i] + (target - M.eqBars[i]) * dt * 8
    else
      M.eqBars[i] = M.eqBars[i] * (1 - dt * 3)
    end
  end

  -- VU meter
  if M.broadcasting then
    M.vuLevel = 0.4 + 0.4 * math.sin(M.time * 5) + 0.1 * math.sin(M.time * 13)
  else
    M.vuLevel = M.vuLevel * (1 - dt * 5)
  end

  -- Rotate listener feedback
  M.feedbackTimer = M.feedbackTimer + dt
  if M.feedbackTimer > 6 then
    M.feedbackTimer = 0
    M.currentFeedback = (M.currentFeedback % #M.feedbackMessages) + 1
  end

  -- Dialogue auto-advance
  if M.showingDialogue then
    M.dialogueTimer = M.dialogueTimer + dt
  end
end

function M.keypressed(key)
  if not M.active then return false end

  if key == "escape" then
    M.exit()
    return true
  end

  if key == "up" then
    M.selectedTrack = M.selectedTrack - 1
    if M.selectedTrack < 1 then M.selectedTrack = #M.tracks end
    return true
  elseif key == "down" then
    M.selectedTrack = M.selectedTrack + 1
    if M.selectedTrack > #M.tracks then M.selectedTrack = 1 end
    return true
  elseif key == "return" then
    if M.showingDialogue then
      M.dialogueIndex = M.dialogueIndex + 1
      if M.dialogueIndex > #M.dialogueLines then
        M.showingDialogue = false
      end
      M.dialogueTimer = 0
    else
      -- Select track / toggle broadcast
      M.broadcasting = true
    end
    return true
  elseif key == "tab" then
    M.showingDialogue = not M.showingDialogue
    M.dialogueIndex = 1
    return true
  end

  return false
end

function M.draw()
  if not M.active then return end

  local screenW, screenH = love.graphics.getDimensions()

  -- Studio background (dark, warm wood-panel aesthetic)
  love.graphics.setColor(0.06, 0.04, 0.03)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Wood paneling texture effect
  for y = 0, screenH, 8 do
    love.graphics.setColor(0.08 + math.sin(y * 0.1) * 0.01, 0.05, 0.03, 0.3)
    love.graphics.rectangle("fill", 0, y, screenW, 4)
  end

  -- === LEFT SIDE: DJ Booth ===
  local boothX = 40
  local boothY = 60
  local boothW = screenW * 0.35
  local boothH = screenH * 0.5

  -- DJ Console
  love.graphics.setColor(0.1, 0.1, 0.12)
  love.graphics.rectangle("fill", boothX, boothY + boothH * 0.4, boothW, boothH * 0.6, 4)

  -- Vinyl turntable
  love.graphics.setColor(0.08, 0.08, 0.1)
  love.graphics.circle("fill", boothX + boothW * 0.3, boothY + boothH * 0.6, 50)
  love.graphics.setColor(0.05, 0.05, 0.05)
  love.graphics.circle("fill", boothX + boothW * 0.3, boothY + boothH * 0.6, 45)

  -- Record grooves
  for r = 10, 40, 5 do
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.circle("line", boothX + boothW * 0.3, boothY + boothH * 0.6, r)
  end

  -- Spinning label
  love.graphics.push()
  love.graphics.translate(boothX + boothW * 0.3, boothY + boothH * 0.6)
  love.graphics.rotate(M.vinylAngle)
  love.graphics.setColor(0.8, 0.2, 0.2)
  love.graphics.circle("fill", 0, 0, 12)
  love.graphics.setColor(0.2, 0.2, 0.2)
  love.graphics.circle("fill", 0, 0, 3)
  love.graphics.pop()

  -- Tone arm
  love.graphics.setColor(0.6, 0.6, 0.6)
  local armAngle = M.broadcasting and -0.3 or -0.8
  love.graphics.push()
  love.graphics.translate(boothX + boothW * 0.5, boothY + boothH * 0.45)
  love.graphics.rotate(armAngle)
  love.graphics.rectangle("fill", 0, 0, 3, 50)
  love.graphics.pop()

  -- EQ visualizer
  local eqX = boothX + boothW * 0.6
  local eqY = boothY + boothH * 0.5
  local eqW = boothW * 0.35
  local eqBarW = eqW / 16 - 2
  for i = 1, 16 do
    local barH = M.eqBars[i] * 80
    local hue = (i - 1) / 16
    local r = 0.2 + hue * 0.8
    local g = 0.8 - hue * 0.6
    local b = 0.3
    love.graphics.setColor(r, g, b, 0.8)
    love.graphics.rectangle("fill",
      eqX + (i-1) * (eqBarW + 2),
      eqY + 80 - barH,
      eqBarW, barH)
  end

  -- VU Meter
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", boothX + 10, boothY + boothH * 0.42, 80, 30, 3)
  love.graphics.setColor(0.0, 0.8, 0.0, 0.8)
  if M.vuLevel > 0.7 then
    love.graphics.setColor(1.0, 0.3, 0.0, 0.8)
  end
  love.graphics.rectangle("fill", boothX + 14, boothY + boothH * 0.42 + 8, 72 * M.vuLevel, 14)
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.print("VU", boothX + 15, boothY + boothH * 0.42 + 2)

  -- DJ Character (Pokemon Emerald style)
  local djX = boothX + boothW * 0.3
  local djY = boothY + boothH * 0.25
  local djBob = math.sin(M.time * 3) * 3

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", djX, djY + 20 + djBob, 12, 4)

  -- Body
  love.graphics.setColor(0.2, 0.2, 0.3)
  love.graphics.rectangle("fill", djX - 8, djY + djBob, 16, 16)

  -- Head
  love.graphics.setColor(0.9, 0.75, 0.6)
  love.graphics.rectangle("fill", djX - 6, djY - 10 + djBob, 12, 10)

  -- Headphones
  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.arc("line", djX, djY - 10 + djBob, 8, math.pi, 0)
  love.graphics.circle("fill", djX - 8, djY - 6 + djBob, 4)
  love.graphics.circle("fill", djX + 8, djY - 6 + djBob, 4)

  -- Sunglasses
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("fill", djX - 5, djY - 7 + djBob, 10, 3)

  -- "ON AIR" light
  if M.broadcasting then
    local onAirPulse = 0.6 + 0.4 * math.sin(M.time * 4)
    love.graphics.setColor(1.0, 0.0, 0.0, onAirPulse)
    love.graphics.circle("fill", boothX + boothW - 30, boothY + 10, 6)
    love.graphics.setColor(1.0, 0.2, 0.2, onAirPulse)
    love.graphics.print("ON AIR", boothX + boothW - 60, boothY + 3)
  end

  -- === RIGHT SIDE: Track List ===
  local listX = screenW * 0.45
  local listY = 60
  local listW = screenW * 0.5
  local listH = screenH * 0.55

  -- Panel background
  love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
  love.graphics.rectangle("fill", listX, listY, listW, listH, 4)

  -- Title
  love.graphics.setColor(0.0, 0.8, 1.0)
  love.graphics.printf("═══ BROADCAST CATALOG ═══", listX, listY + 10, listW, "center")

  -- Track list
  for i, track in ipairs(M.tracks) do
    local ty = listY + 40 + (i - 1) * 28
    local isSelected = i == M.selectedTrack

    if isSelected then
      -- Selection highlight
      love.graphics.setColor(0.0, 0.4, 0.6, 0.3)
      love.graphics.rectangle("fill", listX + 8, ty - 2, listW - 16, 26, 2)
      love.graphics.setColor(0.0, 0.8, 1.0, 0.8)
      love.graphics.print("►", listX + 12, ty + 2)
    end

    -- Track name
    love.graphics.setColor(isSelected and 1 or 0.7, isSelected and 1 or 0.7, isSelected and 1 or 0.7)
    love.graphics.print(track.name, listX + 30, ty + 2)

    -- Artist
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print(track.artist, listX + 200, ty + 2)

    -- Genre tag
    love.graphics.setColor(0.3, 0.6, 0.8, 0.7)
    love.graphics.print("[" .. track.genre .. "]", listX + listW - 100, ty + 2)
  end

  -- === BOTTOM: Listener Feedback ===
  local feedY = screenH * 0.72
  love.graphics.setColor(0.05, 0.05, 0.08, 0.9)
  love.graphics.rectangle("fill", 40, feedY, screenW - 80, 80, 4)

  love.graphics.setColor(0.0, 0.8, 0.4)
  love.graphics.print("LISTENER FEEDBACK", 60, feedY + 8)

  if M.broadcasting then
    local fb = M.feedbackMessages[M.currentFeedback]
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.print(fb.from .. ":", 60, feedY + 30)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(fb.msg, 60, feedY + 50)
  else
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("Select a track and press ENTER to start broadcasting", 60, feedY + 35)
  end

  -- === DIALOGUE BOX ===
  if M.showingDialogue then
    local dlgY = screenH - 130
    love.graphics.setColor(0.0, 0.0, 0.05, 0.95)
    love.graphics.rectangle("fill", 40, dlgY, screenW - 80, 100, 6)
    love.graphics.setColor(0.0, 0.6, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, dlgY, screenW - 80, 100, 6)
    love.graphics.setLineWidth(1)

    -- DJ name
    love.graphics.setColor(0.0, 0.9, 1.0)
    love.graphics.print("DJ Orbit:", 60, dlgY + 10)

    -- Dialogue text (typewriter effect)
    local line = M.dialogueLines[M.dialogueIndex] or ""
    local visibleChars = math.min(#line, math.floor(M.dialogueTimer * 40))
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(string.sub(line, 1, visibleChars), 60, dlgY + 35)

    love.graphics.setColor(0.5, 0.5, 0.6, 0.5 + 0.5 * math.sin(M.time * 3))
    love.graphics.print("ENTER to continue  |  TAB to toggle dialogue  |  ESC to exit", 60, dlgY + 70)
  end

  -- Controls hint
  love.graphics.setColor(0.4, 0.4, 0.5, 0.6)
  love.graphics.printf("↑↓ Select Track  |  ENTER Broadcast  |  TAB Talk to DJ  |  ESC Exit", 0, screenH - 22, screenW, "center")
end

return M
