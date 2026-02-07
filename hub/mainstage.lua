-- hub/mainstage.lua
-- Concert venue / music performance stage on Floor 3 (Residential Deck)
-- Features different musician types with animations:
-- String quartet, rock band, orchestra, rapper, EDM DJ
-- Pokemon Emerald-style pixel art characters with animated performances

local M = {}

M.active = false
M.currentAct = nil
M.time = 0
M.crowdEnergy = 0  -- 0-1, builds during performance
M.lightAngle = 0
M.beatTimer = 0
M.beatInterval = 0.5 -- BPM-based
M.onBeat = false

-- Performance types
local acts = {
  {
    name = "The Stellarions",
    type = "string_quartet",
    genre = "Classical",
    bpm = 80,
    description = "A refined string quartet performing cosmic concertos",
    members = {
      {instrument = "violin1", x = 0.3, y = 0.5, color = {0.9, 0.3, 0.3}},
      {instrument = "violin2", x = 0.4, y = 0.55, color = {0.9, 0.5, 0.3}},
      {instrument = "viola",   x = 0.6, y = 0.55, color = {0.5, 0.3, 0.9}},
      {instrument = "cello",   x = 0.7, y = 0.5, color = {0.3, 0.5, 0.9}},
    },
    stageColor = {0.6, 0.4, 0.2},
    lightColor = {1.0, 0.9, 0.6}
  },
  {
    name = "Hypernova",
    type = "rock_band",
    genre = "Rock",
    bpm = 130,
    description = "High-energy space rock that shakes the station",
    members = {
      {instrument = "guitar", x = 0.25, y = 0.5, color = {1.0, 0.2, 0.2}},
      {instrument = "bass",   x = 0.4, y = 0.55, color = {0.2, 0.6, 1.0}},
      {instrument = "drums",  x = 0.5, y = 0.6, color = {0.8, 0.8, 0.2}},
      {instrument = "vocals", x = 0.6, y = 0.45, color = {1.0, 0.4, 0.8}},
      {instrument = "synth",  x = 0.75, y = 0.55, color = {0.4, 1.0, 0.6}},
    },
    stageColor = {0.15, 0.05, 0.05},
    lightColor = {1.0, 0.2, 0.4}
  },
  {
    name = "Galactic Philharmonic",
    type = "orchestra",
    genre = "Orchestral",
    bpm = 72,
    description = "The station's premiere symphony orchestra",
    members = {}, -- Generated procedurally
    stageColor = {0.1, 0.08, 0.05},
    lightColor = {1.0, 0.95, 0.8}
  },
  {
    name = "MC Nebula",
    type = "rapper",
    genre = "Hip-Hop",
    bpm = 95,
    description = "Spitting bars about life among the stars",
    members = {
      {instrument = "mc", x = 0.5, y = 0.45, color = {0.9, 0.7, 0.2}},
      {instrument = "dj", x = 0.7, y = 0.55, color = {0.3, 0.8, 0.3}},
      {instrument = "hype", x = 0.3, y = 0.55, color = {0.8, 0.3, 0.8}},
    },
    stageColor = {0.05, 0.05, 0.15},
    lightColor = {0.5, 0.2, 1.0}
  },
  {
    name = "DJ Pulsar",
    type = "edm_dj",
    genre = "Electronic",
    bpm = 140,
    description = "Electrifying beats that light up the entire deck",
    members = {
      {instrument = "decks", x = 0.5, y = 0.5, color = {0.0, 1.0, 1.0}},
    },
    stageColor = {0.02, 0.02, 0.08},
    lightColor = {0.0, 0.8, 1.0}
  },
}

-- Generate orchestra members
do
  local orch = acts[3]
  local rows = {
    {y = 0.55, instruments = {"violin", "violin", "violin", "violin", "violin", "violin"}},
    {y = 0.6, instruments = {"viola", "viola", "cello", "cello"}},
    {y = 0.65, instruments = {"bass", "bass", "oboe", "flute", "clarinet"}},
    {y = 0.7, instruments = {"trumpet", "trombone", "horn", "tuba"}},
  }
  for _, row in ipairs(rows) do
    local count = #row.instruments
    for i, inst in ipairs(row.instruments) do
      table.insert(orch.members, {
        instrument = inst,
        x = 0.2 + (i - 1) * 0.6 / count,
        y = row.y,
        color = {0.3 + math.random() * 0.4, 0.3 + math.random() * 0.3, 0.3 + math.random() * 0.4}
      })
    end
  end
  -- Conductor
  table.insert(orch.members, {instrument = "conductor", x = 0.5, y = 0.48, color = {0.9, 0.9, 0.9}})
end

function M.enter(actIndex)
  actIndex = actIndex or math.random(1, #acts)
  M.currentAct = acts[actIndex]
  M.active = true
  M.time = 0
  M.crowdEnergy = 0
  M.beatTimer = 0
  M.beatInterval = 60 / M.currentAct.bpm
end

function M.exit()
  M.active = false
  M.currentAct = nil
end

function M.update(dt)
  if not M.active or not M.currentAct then return end

  M.time = M.time + dt
  M.beatTimer = M.beatTimer + dt
  M.onBeat = false

  if M.beatTimer >= M.beatInterval then
    M.beatTimer = M.beatTimer - M.beatInterval
    M.onBeat = true
  end

  -- Build crowd energy over time
  M.crowdEnergy = math.min(1, M.crowdEnergy + dt * 0.02)

  -- Stage light rotation
  M.lightAngle = M.lightAngle + dt * 1.5
end

function M.keypressed(key)
  if not M.active then return false end

  if key == "escape" or key == "return" then
    M.exit()
    return true
  end

  return false
end

-- Draw a Pokemon Emerald-style pixel musician
local function drawMusician(member, stageX, stageY, stageW, stageH, time)
  local mx = stageX + member.x * stageW
  local my = stageY + member.y * stageH
  local r, g, b = member.color[1], member.color[2], member.color[3]

  -- Animation bobbing
  local bob = math.sin(time * 3 + member.x * 10) * 3
  local sway = math.sin(time * 2 + member.x * 5) * 2

  -- Body (pixel-art style: 8x12 sprite-like)
  local px = math.floor(mx + sway)
  local py = math.floor(my + bob)

  -- Shadow
  love.graphics.setColor(0, 0, 0, 0.3)
  love.graphics.ellipse("fill", px, py + 14, 8, 3)

  -- Legs
  love.graphics.setColor(r * 0.4, g * 0.4, b * 0.4)
  love.graphics.rectangle("fill", px - 4, py + 8, 3, 6)
  love.graphics.rectangle("fill", px + 1, py + 8, 3, 6)

  -- Body
  love.graphics.setColor(r, g, b)
  love.graphics.rectangle("fill", px - 5, py - 2, 10, 10)

  -- Head
  love.graphics.setColor(0.9, 0.75, 0.6)
  love.graphics.rectangle("fill", px - 4, py - 8, 8, 7)

  -- Hair
  love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5)
  love.graphics.rectangle("fill", px - 4, py - 9, 8, 3)

  -- Instrument indicator (simple shapes based on type)
  love.graphics.setColor(0.8, 0.7, 0.5)
  local inst = member.instrument
  if inst == "violin" or inst == "violin1" or inst == "violin2" or inst == "viola" then
    -- Bow arm motion
    local bowAngle = math.sin(time * 4 + mx) * 0.3
    love.graphics.push()
    love.graphics.translate(px + 6, py)
    love.graphics.rotate(bowAngle)
    love.graphics.rectangle("fill", 0, -8, 2, 16)
    love.graphics.pop()
    love.graphics.setColor(0.6, 0.3, 0.1)
    love.graphics.rectangle("fill", px - 8, py - 4, 4, 8)
  elseif inst == "cello" or inst == "bass" then
    love.graphics.setColor(0.5, 0.25, 0.1)
    love.graphics.rectangle("fill", px - 8, py - 6, 6, 14)
  elseif inst == "guitar" then
    love.graphics.setColor(0.7, 0.3, 0.1)
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.rotate(0.3)
    love.graphics.rectangle("fill", -3, -10, 6, 16)
    love.graphics.circle("fill", 0, 8, 5)
    love.graphics.pop()
  elseif inst == "drums" then
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.ellipse("fill", px - 8, py + 4, 6, 4)
    love.graphics.ellipse("fill", px + 8, py + 4, 6, 4)
    love.graphics.ellipse("fill", px, py + 2, 5, 3)
    -- Drum sticks
    local stickAngle = math.sin(time * 8) * 0.4
    love.graphics.setColor(0.8, 0.7, 0.5)
    love.graphics.push()
    love.graphics.translate(px + 5, py - 2)
    love.graphics.rotate(stickAngle)
    love.graphics.rectangle("fill", 0, 0, 2, 10)
    love.graphics.pop()
  elseif inst == "vocals" or inst == "mc" then
    -- Microphone
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", px + 6, py - 6, 2, 8)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.circle("fill", px + 7, py - 7, 3)
  elseif inst == "decks" then
    -- DJ turntables
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", px - 20, py, 40, 8)
    -- Platters
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.circle("fill", px - 10, py + 4, 7)
    love.graphics.circle("fill", px + 10, py + 4, 7)
    -- Spinning records
    local spin = time * 6
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.arc("fill", px - 10, py + 4, 5, spin, spin + 2)
    love.graphics.arc("fill", px + 10, py + 4, 5, spin + 1, spin + 3)
  elseif inst == "conductor" then
    -- Baton
    local batonAngle = math.sin(time * 3) * 0.6
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.push()
    love.graphics.translate(px + 6, py - 4)
    love.graphics.rotate(batonAngle)
    love.graphics.rectangle("fill", 0, 0, 2, 14)
    love.graphics.pop()
  elseif inst == "dj" then
    -- Turntable
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", px - 10, py + 2, 20, 6)
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.circle("fill", px, py + 5, 5)
  elseif inst == "hype" then
    -- Arms up pose
    love.graphics.setColor(r, g, b)
    local armWave = math.sin(time * 6) * 0.3
    love.graphics.push()
    love.graphics.translate(px - 5, py - 2)
    love.graphics.rotate(-1 + armWave)
    love.graphics.rectangle("fill", 0, 0, 2, 8)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.translate(px + 5, py - 2)
    love.graphics.rotate(1 - armWave)
    love.graphics.rectangle("fill", 0, 0, 2, 8)
    love.graphics.pop()
  end
end

-- Draw stage lights
local function drawStageLights(stageX, stageY, stageW, stageH, lightColor, time, energy)
  -- Spotlight beams from above
  local numLights = 4
  for i = 1, numLights do
    local baseAngle = M.lightAngle + i * math.pi * 2 / numLights
    local lx = stageX + stageW * (0.2 + 0.6 * (i - 1) / (numLights - 1))
    local targetX = stageX + stageW/2 + math.cos(baseAngle) * stageW * 0.3
    local targetY = stageY + stageH * 0.6

    local lr, lg, lb = lightColor[1], lightColor[2], lightColor[3]

    -- Beam cone
    local beamWidth = 30 + energy * 20
    love.graphics.setColor(lr, lg, lb, 0.04 + energy * 0.03)
    love.graphics.polygon("fill",
      lx, stageY - 20,
      targetX - beamWidth, targetY,
      targetX + beamWidth, targetY
    )

    -- Source point
    love.graphics.setColor(lr, lg, lb, 0.6)
    love.graphics.circle("fill", lx, stageY - 20, 4)
  end

  -- EDM strobe effect
  if energy > 0.7 and M.onBeat then
    love.graphics.setColor(lightColor[1], lightColor[2], lightColor[3], 0.08)
    love.graphics.rectangle("fill", stageX, stageY, stageW, stageH)
  end
end

-- Draw audience silhouettes
local function drawAudience(stageX, stageY, stageW, stageH, energy, time)
  local audienceY = stageY + stageH * 0.8
  local numPeople = 20

  for i = 1, numPeople do
    local px = stageX + (i - 0.5) * stageW / numPeople
    local py = audienceY + math.sin(i * 1.7) * 5
    local bounce = math.sin(time * 4 + i * 0.8) * energy * 4

    -- Head
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.circle("fill", px, py - bounce - 4, 4)
    -- Body
    love.graphics.rectangle("fill", px - 3, py - bounce, 6, 8)

    -- Raised arms for high energy moments
    if energy > 0.5 and math.sin(time * 3 + i * 2) > 0.3 then
      love.graphics.rectangle("fill", px - 5, py - bounce - 10, 2, 8)
      love.graphics.rectangle("fill", px + 3, py - bounce - 10, 2, 8)
    end
  end
end

function M.draw()
  if not M.active or not M.currentAct then return end
  local act = M.currentAct

  local screenW, screenH = love.graphics.getDimensions()
  local stageX = screenW * 0.1
  local stageY = screenH * 0.1
  local stageW = screenW * 0.8
  local stageH = screenH * 0.75

  -- Dark background
  love.graphics.setColor(0, 0, 0, 0.95)
  love.graphics.rectangle("fill", 0, 0, screenW, screenH)

  -- Stage floor
  local sr, sg, sb = act.stageColor[1], act.stageColor[2], act.stageColor[3]
  love.graphics.setColor(sr, sg, sb)
  love.graphics.rectangle("fill", stageX, stageY + stageH * 0.35, stageW, stageH * 0.65)

  -- Stage back wall
  love.graphics.setColor(sr * 0.5, sg * 0.5, sb * 0.5)
  love.graphics.rectangle("fill", stageX, stageY, stageW, stageH * 0.35)

  -- Stage lights
  drawStageLights(stageX, stageY, stageW, stageH, act.lightColor, M.time, M.crowdEnergy)

  -- Musicians
  for _, member in ipairs(act.members) do
    drawMusician(member, stageX, stageY, stageW, stageH, M.time)
  end

  -- Audience
  drawAudience(stageX, stageY, stageW, stageH, M.crowdEnergy, M.time)

  -- Act name (neon sign style)
  love.graphics.setColor(act.lightColor[1], act.lightColor[2], act.lightColor[3], 0.9)
  local font = love.graphics.getFont()
  love.graphics.printf(act.name, stageX, stageY + stageH + 20, stageW, "center")
  love.graphics.setColor(1, 1, 1, 0.5)
  love.graphics.printf(act.genre, stageX, stageY + stageH + 40, stageW, "center")

  -- Instructions
  love.graphics.setColor(0.5, 0.5, 0.6, 0.6)
  love.graphics.printf("Press ENTER or ESC to leave", 0, screenH - 40, screenW, "center")
end

function M.getActs()
  return acts
end

return M
