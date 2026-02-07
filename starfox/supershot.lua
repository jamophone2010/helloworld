local M = {}

local abilities = nil  -- lazy-loaded to avoid circular deps

local function getAbilities()
  if not abilities then
    abilities = require("starfox.abilities")
  end
  return abilities
end

-- Tracking state
local killStreak = 0
local lastKillTime = 0
local maxStreak = 0  -- highest streak in the current run
local STREAK_WINDOW = 1.0  -- seconds between kills to keep streak alive

-- Medal display state
local activeMedal = nil
local medalDisplayTime = 0
local showingMaxStreak = false  -- showing max after streak expired
local maxStreakTimer = 0
local MEDAL_DURATION = 3.0  -- how long the medal stays on screen after streak expires
local medalFadeStart = 2.0  -- when to start fading out

-- Medal definitions (threshold -> medal info)
local medals = {
  { threshold = 5,  label = "Supershot!",  color = {0.0, 0.8, 1.0},   rimColor = {0.2, 0.6, 0.9} },
  { threshold = 10, label = "Megashot!",   color = {1.0, 0.8, 0.0},   rimColor = {0.9, 0.6, 0.0} },
  { threshold = 15, label = "Gigashot!!",  color = {1.0, 0.3, 0.0},   rimColor = {0.8, 0.2, 0.0} },
  { threshold = 20, label = "Ubershot!!",  color = {1.0, 0.0, 0.4},   rimColor = {0.8, 0.0, 0.3} },
  { threshold = 30, label = "Terashot!!!", color = {0.6, 0.0, 1.0},   rimColor = {0.4, 0.0, 0.8} },
}

-- Medal bonus notes for victory screen
local medalBonusNotes = {
  [10] = 2,   -- Megashot
  [15] = 4,   -- Gigashot
  [20] = 8,   -- Ubershot
  [30] = 16,  -- Terashot
}

-- Earned medals during this level (for victory screen)
local earnedMedals = {}

-- Fonts (lazy-loaded)
local fonts = {}

local function ensureFonts()
  if not fonts.medal then
    fonts.medal = love.graphics.newFont(22)
    fonts.medalSmall = love.graphics.newFont(13)
  end
end

function M.reset()
  killStreak = 0
  lastKillTime = 0
  maxStreak = 0
  activeMedal = nil
  medalDisplayTime = 0
  showingMaxStreak = false
  maxStreakTimer = 0
  earnedMedals = {}
end

--- Call this every time the player scores a kill.
function M.registerKill()
  local now = love.timer.getTime()

  if (now - lastKillTime) <= STREAK_WINDOW then
    killStreak = killStreak + 1
  else
    -- Starting a new streak - clear old medal display
    killStreak = 1
    activeMedal = nil
    medalDisplayTime = 0
    maxStreak = 0
  end
  lastKillTime = now

  -- Update max streak
  if killStreak > maxStreak then
    maxStreak = killStreak
  end

  -- If we were showing max streak, clear it and start fresh
  if showingMaxStreak then
    showingMaxStreak = false
    maxStreakTimer = 0
  end

  -- Check if we hit a medal threshold (update activeMedal to highest reached)
  for i = #medals, 1, -1 do
    if killStreak == medals[i].threshold then
      activeMedal = medals[i]
      medalDisplayTime = 0
      break
    end
  end
end

function M.update(dt)
  local now = love.timer.getTime()

  -- Check if streak expired
  if killStreak > 0 and (now - lastKillTime) > STREAK_WINDOW then
    -- Streak just expired - start showing max streak if we had a medal-worthy streak
    if maxStreak >= 5 and activeMedal then
      showingMaxStreak = true
      maxStreakTimer = 0
      -- Record the highest medal achieved in this streak for victory screen
      if medalBonusNotes[activeMedal.threshold] then
        table.insert(earnedMedals, activeMedal)
      end
      -- Feed abilities special gauge with medal bonus
      local ab = getAbilities()
      if ab then
        ab.registerMedal(activeMedal.threshold)
      end
    end
    killStreak = 0
  end

  -- Handle medal display timers
  if showingMaxStreak then
    maxStreakTimer = maxStreakTimer + dt
    if maxStreakTimer >= MEDAL_DURATION then
      showingMaxStreak = false
      maxStreakTimer = 0
      activeMedal = nil
      medalDisplayTime = 0
      maxStreak = 0
    end
  elseif activeMedal then
    -- Increment medal display time during active streak
    medalDisplayTime = medalDisplayTime + dt
  end
end

function M.draw()
  if not activeMedal then return end
  ensureFonts()

  local screenW = love.graphics.getWidth()
  local alpha = 1.0
  local displayTime = showingMaxStreak and maxStreakTimer or medalDisplayTime

  if displayTime > medalFadeStart then
    alpha = 1.0 - ((displayTime - medalFadeStart) / (MEDAL_DURATION - medalFadeStart))
  end

  -- Slide-in from the right
  local slideIn = showingMaxStreak and 1.0 or math.min(medalDisplayTime / 0.25, 1.0)
  local offsetX = (1.0 - slideIn) * 120

  local medal = activeMedal
  local r, g, b = medal.color[1], medal.color[2], medal.color[3]
  local rr, rg, rb = medal.rimColor[1], medal.rimColor[2], medal.rimColor[3]

  -- Progressive scaling and animation based on medal tier
  local scale = 1.0
  local pulseAmount = 0
  local glowIntensity = 1.0
  local shakeX = 0
  local shakeY = 0
  
  if medal.threshold == 5 then
    scale = 1.0
    pulseAmount = math.sin(displayTime * 8) * 2
  elseif medal.threshold == 10 then
    scale = 1.075
    pulseAmount = math.sin(displayTime * 10) * 3
    glowIntensity = 1.0 + math.sin(displayTime * 12) * 0.3
  elseif medal.threshold == 15 then
    scale = 1.15
    pulseAmount = math.sin(displayTime * 12) * 4
    glowIntensity = 1.0 + math.sin(displayTime * 15) * 0.5
    shakeX = math.sin(displayTime * 20) * 1.5
    shakeY = math.cos(displayTime * 25) * 1.5
  elseif medal.threshold == 20 then
    scale = 1.25
    pulseAmount = math.sin(displayTime * 15) * 5
    glowIntensity = 1.0 + math.sin(displayTime * 20) * 0.7
    shakeX = math.sin(displayTime * 30) * 2.5
    shakeY = math.cos(displayTime * 35) * 2.5
  elseif medal.threshold == 25 then
    scale = 1.375
    pulseAmount = math.sin(displayTime * 20) * 7
    glowIntensity = 1.0 + math.sin(displayTime * 25) * 1.0
    shakeX = math.sin(displayTime * 40) * 3.5
    shakeY = math.cos(displayTime * 45) * 3.5
  end

  local baseX = screenW - 210 * scale + offsetX + shakeX
  local baseY = 55 + shakeY
  
  local panelWidth = 200 * scale
  local panelHeight = 44 * scale
  local cornerRadius = 8 * scale

  -- Extra glow layers for higher tiers
  if medal.threshold >= 10 then
    local glowLayers = 2
    if medal.threshold >= 20 then glowLayers = 4 end
    if medal.threshold >= 25 then glowLayers = 6 end
    for i = 1, glowLayers do
      local glowSize = i * 8 * scale
      love.graphics.setColor(r, g, b, (0.1 * glowIntensity * alpha) / i)
      love.graphics.rectangle("fill", baseX - glowSize/2, baseY - glowSize/2, 
        panelWidth + glowSize, panelHeight + glowSize, cornerRadius + glowSize/2, cornerRadius + glowSize/2)
    end
  end

  -- Background panel (dark, rounded feel)
  love.graphics.setColor(0, 0, 0, 0.55 * alpha)
  love.graphics.rectangle("fill", baseX, baseY, panelWidth, panelHeight, cornerRadius, cornerRadius)

  -- Border glow
  love.graphics.setColor(rr, rg, rb, (0.6 * glowIntensity) * alpha)
  love.graphics.setLineWidth(2 * scale)
  love.graphics.rectangle("line", baseX, baseY, panelWidth, panelHeight, cornerRadius, cornerRadius)
  love.graphics.setLineWidth(1)

  -- Medal icon (small star-burst circle)
  local iconX = baseX + 24 * scale
  local iconY = baseY + 22 * scale
  local iconScale = scale + (pulseAmount * 0.01)

  -- Extra glow rings for higher tiers
  if medal.threshold >= 15 then
    local glowRings = 2
    if medal.threshold >= 20 then glowRings = 3 end
    if medal.threshold >= 25 then glowRings = 5 end
    for i = 1, glowRings do
      local ringRadius = (16 + i * 6) * iconScale
      love.graphics.setColor(r, g, b, (0.15 * glowIntensity * alpha) / i)
      love.graphics.circle("fill", iconX, iconY, ringRadius)
    end
  end

  -- Outer glow ring
  love.graphics.setColor(r, g, b, (0.25 * glowIntensity) * alpha)
  love.graphics.circle("fill", iconX, iconY, 16 * iconScale)

  -- Medal disc
  love.graphics.setColor(rr, rg, rb, (0.9 * glowIntensity) * alpha)
  love.graphics.circle("fill", iconX, iconY, 12 * iconScale)

  -- Inner highlight
  love.graphics.setColor(r, g, b, alpha)
  love.graphics.circle("fill", iconX, iconY, 9 * iconScale)

  -- Star shape on medal (simple 4-point star)
  love.graphics.setColor(1, 1, 1, 0.9 * alpha)
  local sz = 5 * iconScale
  love.graphics.polygon("fill",
    iconX, iconY - sz,
    iconX + sz * 0.3, iconY - sz * 0.3,
    iconX + sz, iconY,
    iconX + sz * 0.3, iconY + sz * 0.3,
    iconX, iconY + sz,
    iconX - sz * 0.3, iconY + sz * 0.3,
    iconX - sz, iconY,
    iconX - sz * 0.3, iconY - sz * 0.3
  )

  -- Medal rim
  love.graphics.setColor(1, 1, 1, (0.5 * glowIntensity) * alpha)
  love.graphics.circle("line", iconX, iconY, 12 * iconScale)

  -- Medal label text with scaling
  local textScale = scale
  love.graphics.push()
  love.graphics.translate(baseX + 44 * scale, baseY + 4 * scale)
  love.graphics.scale(textScale, textScale)
  love.graphics.setFont(fonts.medal)
  love.graphics.setColor(r, g, b, alpha)
  love.graphics.print(medal.label, 0, 0)
  love.graphics.pop()

  -- Streak count subtitle with scaling
  love.graphics.push()
  love.graphics.translate(baseX + 44 * scale, baseY + 26 * scale)
  love.graphics.scale(textScale, textScale)
  love.graphics.setFont(fonts.medalSmall)
  love.graphics.setColor(0.8, 0.8, 0.8, 0.7 * alpha)
  local displayStreak = showingMaxStreak and maxStreak or killStreak
  love.graphics.print(displayStreak .. " hits", 0, 0)
  love.graphics.pop()
end

function M.getStreak()
  return killStreak
end

--- Returns the list of medals earned this level (only those with bonus notes).
function M.getEarnedMedals()
  return earnedMedals
end

--- Returns medals grouped by type with counts. E.g. {{medal=..., count=3}, ...}
function M.getGroupedEarnedMedals()
  local groups = {}
  local groupMap = {}
  for _, medal in ipairs(earnedMedals) do
    if groupMap[medal.threshold] then
      groupMap[medal.threshold].count = groupMap[medal.threshold].count + 1
    else
      local entry = { medal = medal, count = 1 }
      groupMap[medal.threshold] = entry
      table.insert(groups, entry)
    end
  end
  return groups
end

--- Returns the total bonus notes from all earned medals.
function M.getTotalBonusNotes()
  local total = 0
  for _, medal in ipairs(earnedMedals) do
    total = total + (medalBonusNotes[medal.threshold] or 0)
  end
  return total
end

--- Returns the medals table (for drawing icons on victory screen).
function M.getMedals()
  return medals
end

--- Returns the bonus notes for a given medal threshold.
function M.getMedalBonusNotes(threshold)
  return medalBonusNotes[threshold] or 0
end

return M
