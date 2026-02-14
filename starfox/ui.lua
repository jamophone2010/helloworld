local M = {}
local screen = require("starfox.screen")
local terrain = require("starfox.terrain")
local weapons = require("starfox.weapons")
local enemies = require("starfox.enemies")
local turrets = require("starfox.turrets")
local boss = require("starfox.boss")
local particles = require("starfox.particles")
local wingmen = require("starfox.wingmen")
local hud = require("starfox.hud")
local levelselect = require("starfox.levelselect")
local capitalship = require("starfox.capitalship")
local mothership = require("starfox.mothership")
local allies = require("starfox.allies")
local portals = require("starfox.portals")
local bolse = require("starfox.bolse")
local rival = require("starfox.rival")
local maze = require("starfox.maze")
local venomboss = require("starfox.venomboss")
local sectorzboss = require("starfox.sectorzboss")
local wardenboss = require("starfox.wardenboss")
local sentinelboss = require("starfox.sentinelboss")
local dynamoboss = require("starfox.dynamoboss")
local megalith = require("starfox.megalith")
local sphereboss = require("starfox.sphereboss")
local machineboss = require("starfox.machineboss")
local synesthesia = require("starfox.synesthesia")
local bossexplosion = require("starfox.bossexplosion")
local supershot = require("starfox.supershot")
local abilities = require("starfox.abilities")
local ships = require("starfox.ships")
local raid = require("starfox.raid")

local fonts = {}
local currentLevelId = 1

-- Victory screen animation state
local victoryState = {
  active = false,
  timer = 0,
  enemiesDefeated = 0,
  totalEnemies = 0,
  baseNotesEarned = 0,
  -- Counting animation
  displayedEnemies = 0,
  displayedNotes = 0,
  countSpeed = 1,
  countPhase = "counting",  -- "counting", "medals_pause", "medals", "done"
  -- Medal bonus phase (now grouped)
  groupedMedals = {},
  medalIndex = 0,
  medalTimer = 0,
  medalBonusDisplayed = 0,
  medalSlideIn = 0,
  medalShowTimes = {},  -- tracks when each medal row was fully shown (for decay)
  -- Visual effects
  lastNoteThreshold = 0,
  notePulse = 0,
  noteFlashTimer = 0,
}

function M.setLevelId(levelId)
  currentLevelId = levelId
end

function M.isSectorX()
  return currentLevelId == 8
end

function M.load()
  fonts.large = love.graphics.newFont(36)
  fonts.xlarge = love.graphics.newFont(52)
  fonts.normal = love.graphics.newFont(20)
  fonts.small = love.graphics.newFont(14)
  hud.load()
end

-- Level intro sequence:
-- 0.0s - 1.0s: White fade-in + warp lines top-to-bottom phasing out
-- 0.5s - 2.5s: IntroTitle fades in
-- 2.5s - 4.5s: IntroTitle fades out
-- 4.5s: Playing begins
function M.drawIntro(timer, levelName, levelId, enemyCount)
  -- Phase 1: Warp lines going top to bottom, phasing out over 1 second
  if timer < 1.0 then
    local lineAlpha = 1.0 - timer -- fade from 1 to 0 over 1s
    local time = love.timer.getTime()
    for i = 1, 40 do
      local speed = 300 + i * 40
      local x = screen.WIDTH / 2 + math.sin(i * 0.7 + time * 2) * (150 + i * 3)
      local y = (timer * speed * 2 + i * 30) % (screen.HEIGHT + 100) - 50
      local streakLen = 20 + i * 1.5
      local alpha = lineAlpha * (0.3 + (i / 40) * 0.5)
      love.graphics.setColor(0.6, 0.8, 1, alpha)
      love.graphics.setLineWidth(1 + (i / 40) * 2)
      love.graphics.line(x, y, x + math.sin(i * 0.3) * 3, y + streakLen)
    end
    love.graphics.setLineWidth(1)
  end

  -- White overlay fading out over 1 second
  if timer < 1.0 then
    local whiteAlpha = 1.0 - timer
    love.graphics.setColor(1, 1, 1, whiteAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
  end

  -- IntroTitle overlay
  -- Fades in: 0.5s to 2.5s (alpha ramps 0->1 over 0.5s, holds until 2.5s)
  -- Fades out: 2.5s to 4.5s
  local titleAlpha = 0
  if timer >= 0.5 and timer < 1.0 then
    -- Fade in (0.5s to 1.0s)
    titleAlpha = (timer - 0.5) / 0.5
  elseif timer >= 1.0 and timer < 2.5 then
    -- Fully visible
    titleAlpha = 1.0
  elseif timer >= 2.5 and timer < 4.5 then
    -- Fade out (2.5s to 4.5s)
    titleAlpha = 1.0 - (timer - 2.5) / 2.0
  end

  if titleAlpha > 0 then
    -- Semi-transparent dark backdrop for readability
    love.graphics.setColor(0, 0, 0, 0.4 * titleAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

    -- Split stage name into words for stacking
    local words = {}
    for word in levelName:gmatch("%S+") do
      table.insert(words, word)
    end

    -- Calculate vertical layout
    -- Line 1: "Stage #X:" (small text)
    -- Line 2 (+3): Stage name words (xlarge text, stacked)
    -- Last line: "Enemies Detected = X" (smaller, blue)
    local centerY = 300
    local stageLineH = 24
    local nameLineH = 60
    local enemyLineH = 24
    local totalH = stageLineH + #words * nameLineH + 20 + enemyLineH
    local startY = centerY - totalH / 2

    -- Line 1: Stage number
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0.8, 0.8, 0.9, titleAlpha)
    love.graphics.printf("Stage #" .. levelId .. ":", 0, startY, screen.WIDTH, "center")
    startY = startY + stageLineH + 8

    -- Line 2 (+3): Stage name - each word stacked
    love.graphics.setFont(fonts.xlarge)
    love.graphics.setColor(1, 1, 1, titleAlpha)
    for _, word in ipairs(words) do
      love.graphics.printf(word, 0, startY, screen.WIDTH, "center")
      startY = startY + nameLineH
    end
    startY = startY + 12

    -- Last line: Enemy count (blue, smaller)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.4, 0.7, 1, titleAlpha)
    love.graphics.printf("Enemies Detected = " .. enemyCount, 0, startY, screen.WIDTH, "center")
  end
end

function M.drawBackground()
  if raid.isActive() then
    -- Raid level: PCB motherboard background handled by raid.draw()
    -- Just set a dark base color for the board substrate
    love.graphics.setBackgroundColor(0.02, 0.03, 0.05)
    return
  elseif M.isSectorX() then
    -- Sector X: Pure dark void, no stars
    love.graphics.setBackgroundColor(0, 0, 0)
  else
    love.graphics.setBackgroundColor(0.02, 0.02, 0.1)

    for _, star in ipairs(terrain.stars) do
      local alpha = 0.3 + (star.speed / 80) * 0.7
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.circle("fill", star.x, star.y, star.size)
    end
  end
end

function M.drawPortals()
  for _, portal in ipairs(portals.portals) do
    local pulse = math.abs(math.sin(portal.pulse)) * 0.3 + 0.7

    -- Outer ring glow
    love.graphics.setColor(0.3, 0.6, 1, 0.3 * pulse)
    love.graphics.circle("fill", portal.x, portal.y, portal.radius + 10)

    -- Outer ring
    love.graphics.setColor(0.4, 0.7, 1, pulse)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", portal.x, portal.y, portal.radius)

    -- Inner ring
    love.graphics.setColor(0.6, 0.9, 1, pulse)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", portal.x, portal.y, portal.innerRadius)

    -- Center sparkle
    love.graphics.setColor(1, 1, 1, pulse * 0.8)
    love.graphics.circle("fill", portal.x, portal.y, 5)

    -- Rotating accent lines
    for i = 0, 3 do
      local angle = portal.rotation + (i * math.pi / 2)
      local x1 = portal.x + math.cos(angle) * portal.innerRadius
      local y1 = portal.y + math.sin(angle) * portal.innerRadius
      local x2 = portal.x + math.cos(angle) * portal.radius
      local y2 = portal.y + math.sin(angle) * portal.radius
      love.graphics.setColor(0.5, 0.8, 1, pulse * 0.6)
      love.graphics.line(x1, y1, x2, y2)
    end

    love.graphics.setLineWidth(1)
  end
end

function M.drawPlayer(player, introTimer)
  -- During intro (2.5s onwards), animate ship gradually entering from bottom
  local yOffset = 0
  if introTimer then
    if introTimer < 2.5 then
      -- Off-screen at bottom
      yOffset = 700
    elseif introTimer < 4.5 then
      -- Slide in over 2 seconds (from 2.5s to 4.5s)
      local slideProgress = (introTimer - 2.5) / 2.0
      yOffset = 700 * (1.0 - slideProgress)
    else
      -- Clamp to 0 once fully transitioned
      yOffset = 0
    end
  end

  -- Only flash when invulnerable but NOT barrel rolling and NOT ability-invulnerable
  if player.invulnerable and not player.barrelRolling and not abilities.active and math.floor(love.timer.getTime() * 10) % 2 == 0 then
    return
  end

  -- Get player draw alpha (for Phantom phase cloak)
  local playerAlpha = abilities.getPlayerAlpha()

  -- Dodge trail effect
  if player.dodging then
    for i = 1, 3 do
      local alpha = 0.3 - (i * 0.08)
      local offset = i * 25 * (player.dodgeDirection == "left" and 1 or -1)
      love.graphics.push()
      love.graphics.translate(player.x + offset, player.y)
      love.graphics.setColor(0.3, 0.5, 1, alpha)
      love.graphics.polygon("fill", 0, -20, -15, 15, 15, 15)
      love.graphics.pop()
    end
  end

  love.graphics.push()
  love.graphics.translate(player.x, player.y + yOffset)

  -- Barrel roll shield (semicircle in front)
  if player.barrelRolling then
    -- Glow effect (narrow radius)
    for i = 3, 1, -1 do
      local glowRadius = 35 + i * 2
      local alpha = 0.15 * (4 - i) / 3
      love.graphics.setColor(0.3, 0.8, 1, alpha)
      love.graphics.setLineWidth(3)
      love.graphics.arc("line", "open", 0, 0, glowRadius, -math.pi/2 - math.pi/3, -math.pi/2 + math.pi/3)
    end

    -- Main shield arc (no radial lines)
    love.graphics.setColor(0.5, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", 0, 0, 35, -math.pi/2 - math.pi/3, -math.pi/2 + math.pi/3)
    love.graphics.setLineWidth(1)
  end

  love.graphics.setColor(0.3, 0.5, 1, playerAlpha)
  love.graphics.polygon("fill", 0, -20, -15, 15, 15, 15)

  love.graphics.setColor(0.5, 0.7, 1, playerAlpha)
  love.graphics.polygon("fill", -25, 10, -15, 5, -15, 15, -25, 15)
  love.graphics.polygon("fill", 25, 10, 15, 5, 15, 15, 25, 15)

  love.graphics.setColor(1, 1, 1, playerAlpha)
  love.graphics.polygon("line", 0, -20, -15, 15, 15, 15)

  if player.charging and player.chargeLevel > 0.2 then
    local size = 5 + player.chargeLevel * 15
    love.graphics.setColor(0.3, 0.8, 1, 0.5 + player.chargeLevel * 0.5)
    love.graphics.circle("fill", 0, -20, size)
  end

  -- Paladin charge indicator (green/shield color)
  if weapons.paladinCharging and weapons.paladinChargeLevel > 0.1 then
    local time = love.timer.getTime()
    local pulse = 0.6 + 0.4 * math.sin(time * 15)
    local size = 10 + weapons.paladinChargeLevel * 40

    -- Outer glow rings
    for i = 3, 1, -1 do
      local ringSize = size * (1 + i * 0.3)
      local ringAlpha = (0.2 / i) * pulse
      love.graphics.setColor(0.3, 1, 0.5, ringAlpha * playerAlpha)
      love.graphics.circle("fill", 0, -25, ringSize)
    end

    -- Main charge orb
    love.graphics.setColor(0.4, 1, 0.6, (0.6 + weapons.paladinChargeLevel * 0.4) * pulse * playerAlpha)
    love.graphics.circle("fill", 0, -25, size)

    -- Bright core
    love.graphics.setColor(1, 1, 1, 0.8 * pulse * playerAlpha)
    love.graphics.circle("fill", 0, -25, size * 0.5)
  end

  -- EMP stun effect: crackling electricity around ship
  if player.stunned then
    local time = love.timer.getTime()
    -- Blue-white electric arcs around ship
    for i = 1, 6 do
      local angle = (time * 8 + i * math.pi / 3) % (math.pi * 2)
      local r = 20 + math.sin(time * 12 + i) * 8
      local ex = math.cos(angle) * r
      local ey = math.sin(angle) * r
      local ex2 = math.cos(angle + 0.5) * (r * 0.6)
      local ey2 = math.sin(angle + 0.5) * (r * 0.6)
      love.graphics.setColor(0.3, 0.6, 1, 0.7 + math.sin(time * 20 + i) * 0.3)
      love.graphics.setLineWidth(2)
      love.graphics.line(ex, ey, ex2, ey2)
      -- Small spark at end
      love.graphics.setColor(0.8, 0.9, 1, 0.9)
      love.graphics.circle("fill", ex, ey, 2)
    end
    -- Pulsing blue overlay
    local stunPulse = 0.15 + 0.1 * math.sin(time * 10)
    love.graphics.setColor(0.2, 0.4, 1, stunPulse)
    love.graphics.circle("fill", 0, 0, 25)
    love.graphics.setLineWidth(1)
  end

  love.graphics.pop()
end

function M.drawWingmen()
  -- Wingmen are not drawn on screen
  return
end

function M.drawLasers()
  local abilities = require("starfox.abilities")
  local isLancerActive = abilities.isMultiLockActive()
  
  -- Draw Spartan Laser beam first (so it appears behind regular lasers)
  if weapons.spartanLaserBeam and weapons.spartanLaserBeam.active then
    local beam = weapons.spartanLaserBeam
    local alpha = 0.3 + (beam.fireTime / 5.0) * 0.5 -- Fade in as it charges
    local currentWidth = beam.width or 10
    local endY = beam.actualEndY or 0  -- End at boss surface or top of screen
    local beamLength = beam.y - endY
    
    -- Draw bloom glow at impact point
    if beam.actualEndY and beam.actualEndY > 0 then
      local bloomAlpha = 0.11 + (beam.fireTime / 5.0) * 0.11
      local bloomSize = 22.5 + beam.fireTime * 7.5
      
      -- Multiple layers for soft bloom
      for i = 3, 1, -1 do
        local size = bloomSize * i * 0.7
        local layerAlpha = bloomAlpha / (i * 1.5)
        love.graphics.setColor(1, 0.8, 0.3, layerAlpha)
        love.graphics.circle("fill", beam.x, beam.actualEndY, size)
      end
    end
    
    -- Draw outer glow
    love.graphics.setColor(1, 0, 0, alpha * 0.3)
    love.graphics.rectangle("fill", beam.x - currentWidth, endY, currentWidth * 2, beamLength)
    
    -- Draw main beam
    love.graphics.setColor(1, 0.2, 0, alpha)
    love.graphics.rectangle("fill", beam.x - currentWidth/2, endY, currentWidth, beamLength)
    
    -- Draw core beam
    love.graphics.setColor(1, 0.8, 0.8, alpha + 0.3)
    love.graphics.rectangle("fill", beam.x - currentWidth/4, endY, currentWidth/2, beamLength)
  end
  
  for _, laser in ipairs(weapons.lasers) do
    local r, g, b = 0, 1, 0
    if laser.owner == "player" then
      if laser.charged then
        r, g, b = 0.3, 0.8, 1
      else
        r, g, b = 0, 1, 0
      end
    elseif laser.owner == "ally" then
      if laser.converted then
        r, g, b = 0.6, 0.1, 1.0  -- Purple for Mistral converted wingmen
      else
        r, g, b = 0.3, 0.8, 1
      end
    elseif laser.owner == "prototype_emp" then
      r, g, b = 0.3, 0.5, 1.0  -- Blue for EMP projectiles
    elseif laser.owner == "prototype" then
      r, g, b = 1.0, 0.6, 0.0  -- Orange for Prototype lasers
    else
      r, g, b = 1, 0.3, 0.3
    end

    -- Sector X: Laser illumination with 400px exponential gradient (4x steeper decay)
    if M.isSectorX() then
      -- Draw gradient glow rings (400px radius, steep exponential falloff)
      for i = 40, 1, -1 do
        local radius = i * 10  -- 10, 20, 30, ... 400
        local t = (41 - i) / 40  -- 0.025 to 1.0 (center to edge)
        local alpha = math.exp(-10 * (1 - (0.7 * t^2))) * 0.7 + 0.0037  -- gradient steepness
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.circle("fill", laser.x, laser.y, radius)
      end
    end

    -- Draw the laser itself
    if laser.owner == "player" and isLancerActive then
      -- Fancy animation for Lancer special: pulsing glow and spiral trail
      local time = love.timer.getTime()
      local pulse = 0.7 + 0.3 * math.sin(time * 10 + laser.y * 0.1)

      -- Outer glow
      for i = 3, 1, -1 do
        local glowSize = i * 4
        local glowAlpha = (0.4 / i) * pulse
        love.graphics.setColor(0.2, 0.8, 1, glowAlpha)
        love.graphics.rectangle("fill", laser.x - (laser.width + glowSize)/2, laser.y - (laser.height + glowSize)/2, laser.width + glowSize, laser.height + glowSize)
      end

      -- Spiral trail particles
      for j = 0, 3 do
        local offset = (time * 5 + laser.y * 0.05 + j * math.pi/2) % (math.pi * 2)
        local spiralX = laser.x + math.cos(offset) * 8
        local spiralY = laser.y + j * 3
        love.graphics.setColor(0.4, 0.9, 1, 0.6 * pulse)
        love.graphics.circle("fill", spiralX, spiralY, 2)
      end

      -- Main laser (brighter during Lancer special)
      love.graphics.setColor(0.3, 1, 1, pulse)
      love.graphics.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2, laser.width, laser.height)

      -- Core bright center
      love.graphics.setColor(1, 1, 1, 0.8 * pulse)
      love.graphics.rectangle("fill", laser.x - laser.width/4, laser.y - laser.height/2, laser.width/2, laser.height)
    else
      love.graphics.setColor(r, g, b)
      love.graphics.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2, laser.width, laser.height)
    end
  end
end

function M.drawMissiles()
  local abilities = require("starfox.abilities")
  local isLancerActive = abilities.isMultiLockActive()

  for _, m in ipairs(weapons.missiles) do
    if isLancerActive then
      -- Fancy animation for Lancer missiles: pulsing glow and spiral trail
      local time = love.timer.getTime()
      local pulse = 0.7 + 0.3 * math.sin(time * 12 + m.x * 0.2 + m.y * 0.1)

      -- Outer glow
      for i = 3, 1, -1 do
        local glowSize = i * 5
        local glowAlpha = (0.35 / i) * pulse
        love.graphics.setColor(0.2, 0.8, 1, glowAlpha)
        love.graphics.circle("fill", m.x, m.y, glowSize)
      end

      -- Spiral trail
      for j = 0, 3 do
        local offset = (time * 8 + m.y * 0.08 + j * math.pi/2) % (math.pi * 2)
        local spiralX = m.x + math.cos(offset) * 6
        local spiralY = m.y + math.sin(offset) * 6
        love.graphics.setColor(0.4, 0.9, 1, 0.5 * pulse)
        love.graphics.circle("fill", spiralX, spiralY, 2)
      end

      -- Main missile body
      love.graphics.setColor(0.3, 1, 1, pulse)
      love.graphics.rectangle("fill", m.x - m.width/2, m.y - m.height/2, m.width, m.height)

      -- Bright core
      love.graphics.setColor(1, 1, 1, 0.7 * pulse)
      love.graphics.rectangle("fill", m.x - m.width/4, m.y - m.height/2, m.width/2, m.height)

      -- Exhaust trail
      love.graphics.setColor(0.2, 0.6, 1, 0.5 * pulse)
      love.graphics.rectangle("fill", m.x - 3, m.y + m.height/2, 6, 10)
    else
      love.graphics.setColor(1, 0.8, 0)
      love.graphics.rectangle("fill", m.x - m.width/2, m.y - m.height/2, m.width, m.height)
      love.graphics.setColor(1, 0.5, 0, 0.6)
      love.graphics.rectangle("fill", m.x - 3, m.y + m.height/2, 6, 8)
    end
  end
end

function M.drawShotgunPellets()
  local time = love.timer.getTime()

  for _, pellet in ipairs(weapons.shotgunPellets) do
    local lifeRatio = 1 - (pellet.age / pellet.maxAge)
    local alpha = pellet.alpha * lifeRatio

    -- Phantom ghostly colors: purple-blue gradient
    local pulse = 0.6 + 0.4 * math.sin(time * 15 + pellet.x * 0.5 + pellet.y * 0.5)

    -- Outer glow (large, diffuse)
    for i = 5, 1, -1 do
      local glowSize = i * 3
      local glowAlpha = (alpha * 0.15 / i) * pulse
      love.graphics.setColor(0.5, 0.3, 0.9, glowAlpha)
      love.graphics.circle("fill", pellet.x, pellet.y, pellet.width + glowSize)
    end

    -- Middle glow (brighter)
    love.graphics.setColor(0.6, 0.5, 1, alpha * 0.6 * pulse)
    love.graphics.circle("fill", pellet.x, pellet.y, pellet.width * 1.5)

    -- Core pellet (bright white-blue center)
    love.graphics.setColor(0.9, 0.8, 1, alpha * pulse)
    love.graphics.circle("fill", pellet.x, pellet.y, pellet.width)

    -- Inner bright core
    love.graphics.setColor(1, 1, 1, alpha * 0.9 * pulse)
    love.graphics.circle("fill", pellet.x, pellet.y, pellet.width * 0.5)

    -- Trailing ghost particles
    if lifeRatio > 0.5 then
      for j = 1, 3 do
        local trailOffset = j * 8
        local trailAlpha = alpha * 0.3 * (1 - j/4)
        love.graphics.setColor(0.5, 0.4, 0.8, trailAlpha)
        love.graphics.circle("fill", pellet.x - pellet.vx/50 * j, pellet.y - pellet.vy/50 * j, pellet.width * 0.7)
      end
    end
  end
end

function M.drawChargedBlasts()
  local time = love.timer.getTime()

  for _, blast in ipairs(weapons.chargedBlasts) do
    local pulse = 0.7 + 0.3 * math.sin(time * 20)

    -- Outer expanding shockwave rings
    for i = 3, 1, -1 do
      local ringRadius = blast.currentRadius + i * 15 * math.sin(time * 10 + blast.age * 5)
      local ringAlpha = 0.3 / i
      love.graphics.setColor(0.3, 1, 0.5, ringAlpha)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", blast.x, blast.y, ringRadius)
    end

    -- Multiple bloom layers
    for i = 5, 1, -1 do
      local bloomRadius = blast.currentRadius * (1 + i * 0.2)
      local bloomAlpha = (0.2 / i) * pulse
      love.graphics.setColor(0.4, 1, 0.6, bloomAlpha)
      love.graphics.circle("fill", blast.x, blast.y, bloomRadius)
    end

    -- Main blast sphere
    love.graphics.setColor(0.5, 1, 0.7, 0.8 * pulse)
    love.graphics.circle("fill", blast.x, blast.y, blast.currentRadius)

    -- Bright core
    love.graphics.setColor(1, 1, 1, 0.9 * pulse)
    love.graphics.circle("fill", blast.x, blast.y, blast.currentRadius * 0.6)

    -- Ultra-bright center
    love.graphics.setColor(1, 1, 1, pulse)
    love.graphics.circle("fill", blast.x, blast.y, blast.currentRadius * 0.3)

    -- Rotating energy particles around the blast
    for i = 0, 7 do
      local angle = (i / 8) * math.pi * 2 + time * 5
      local px = blast.x + math.cos(angle) * blast.currentRadius * 0.8
      local py = blast.y + math.sin(angle) * blast.currentRadius * 0.8
      love.graphics.setColor(0.8, 1, 0.9, 0.7)
      love.graphics.circle("fill", px, py, 6)
    end

    love.graphics.setLineWidth(1)
  end
end

function M.drawTargetingCrosshairs(player)
  local targeting = require("starfox.targeting")
  local abilities = require("starfox.abilities")
  local isLancerActive = abilities.isMultiLockActive()

  if not targeting.active and not isLancerActive then return end

  -- Check dodge path for Lancer special
  local inDodgePath = {}
  if isLancerActive and player and player.dodging and player.dodgeStartX then
    local minX = math.min(player.dodgeStartX, player.x)
    local maxX = math.max(player.dodgeStartX, player.x)
    for _, enemy in ipairs(enemies.enemies) do
      local dy = enemy.y - player.y
      if enemy.x >= minX and enemy.x <= maxX and dy < 0 then
        inDodgePath[enemy] = true
      end
    end
  end

  for _, enemy in ipairs(enemies.enemies) do
    local progress = targeting.getLockProgress(enemy)
    local isLocked = targeting.locks[enemy] and targeting.locks[enemy].locked
    local isInDodge = inDodgePath[enemy]

    -- During Lancer special: show fancy crosshairs for locked enemies OR enemies in dodge path
    -- During normal targeting: show progress crosshairs for all
    local shouldShow = isLancerActive and (isLocked or isInDodge) or (not isLancerActive and progress > 0)
    
    if shouldShow then
      if isLancerActive and (isLocked or isInDodge) then progress = 1 end
      local size = 20
      local alpha = 0.5 + progress * 0.5

      if isLancerActive and (isLocked or isInDodge) then
        -- Cyan animated crosshair for Lancer special
        local time = love.timer.getTime()
        local pulse = 0.7 + 0.3 * math.sin(time * 6 + enemy.x * 0.1)
        love.graphics.setColor(0.2, 0.9, 1, alpha * pulse)
        love.graphics.setLineWidth(2)

        -- Spinning crosshair corners
        local spin = time * 2
        for c = 0, 3 do
          local angle = spin + c * math.pi/2
          local cx = enemy.x + math.cos(angle) * size
          local cy = enemy.y + math.sin(angle) * size
          local ix = enemy.x + math.cos(angle) * size * 0.5
          local iy = enemy.y + math.sin(angle) * size * 0.5
          love.graphics.line(cx, cy, ix, iy)
        end

        -- Pulsing lock circle
        love.graphics.circle("line", enemy.x, enemy.y, size * 0.7 * pulse)

        -- Diamond indicator
        local ds = 4
        love.graphics.polygon("fill", enemy.x, enemy.y - ds, enemy.x + ds, enemy.y, enemy.x, enemy.y + ds, enemy.x - ds, enemy.y)
      else
        local r, g = progress < 1 and 1 or 0, progress < 1 and progress or 1
        love.graphics.setColor(r, g, 0, alpha)
        love.graphics.setLineWidth(2)

        -- Crosshair corners
        love.graphics.line(enemy.x - size, enemy.y, enemy.x - size/2, enemy.y)
        love.graphics.line(enemy.x + size, enemy.y, enemy.x + size/2, enemy.y)
        love.graphics.line(enemy.x, enemy.y - size, enemy.x, enemy.y - size/2)
        love.graphics.line(enemy.x, enemy.y + size, enemy.x, enemy.y + size/2)

        -- Lock progress
        if progress < 1 then
          love.graphics.arc("line", "open", enemy.x, enemy.y, size*0.7, 0, progress*math.pi*2)
        else
          love.graphics.circle("line", enemy.x, enemy.y, size*0.7)
        end
      end

      love.graphics.setLineWidth(1)
    end
  end
end

function M.drawBombs()
  for _, bomb in ipairs(weapons.bombs) do
    love.graphics.setColor(1, 1, 0.5, bomb.alpha)
    love.graphics.circle("line", bomb.x, bomb.y, bomb.radius)
    love.graphics.circle("line", bomb.x, bomb.y, bomb.radius * 0.8)
  end
end

function M.drawEnemies()
  for _, enemy in ipairs(enemies.enemies) do
    local alpha = 1

    -- In Sector X, enemies only visible near lasers
    if M.isSectorX() then
      alpha = 0
      for _, laser in ipairs(weapons.lasers) do
        local dist = math.sqrt((enemy.x - laser.x)^2 + (enemy.y - laser.y)^2)
        if dist < 400 then
          local t = 1 - (dist / 400)  -- 1 at center, 0 at edge
          local laserAlpha = math.exp(-12 * (1 - t)) * 0.9  -- Match 4x steep decay
          alpha = math.max(alpha, laserAlpha)
        end
      end
      if alpha <= 0.01 then goto continue end
    end

    -- Set color based on enemy type
    local r, g, b = 1, 0.3, 0.3
    if enemy.color == "green" then
      r, g, b = 0.3, 1, 0.3
    elseif enemy.color == "blue" then
      r, g, b = 0.3, 0.5, 1
    end

    love.graphics.setColor(r, g, b, alpha)
    love.graphics.polygon("fill", enemy.x, enemy.y + 15, enemy.x - 12, enemy.y - 10, enemy.x + 12, enemy.y - 10)

    -- Draw health bar for enemies with > 1 max health
    if enemy.maxHealth and enemy.maxHealth > 1 then
      local barWidth = 30
      local barHeight = 4
      local healthPercent = enemy.health / enemy.maxHealth

      -- Background
      love.graphics.setColor(0.2, 0.2, 0.2, alpha)
      love.graphics.rectangle("fill", enemy.x - barWidth/2, enemy.y - 20, barWidth, barHeight)

      -- Health
      love.graphics.setColor(r * 0.7, g * 0.7, b * 0.7, alpha)
      love.graphics.rectangle("fill", enemy.x - barWidth/2, enemy.y - 20, barWidth * healthPercent, barHeight)

      -- Border
      love.graphics.setColor(1, 1, 1, alpha * 0.5)
      love.graphics.rectangle("line", enemy.x - barWidth/2, enemy.y - 20, barWidth, barHeight)
    end

    ::continue::
  end
end

function M.drawTurrets()
  for _, turret in ipairs(turrets.turrets) do
    if turret.active then
      local alpha = 1

      -- In Sector X, turrets only visible near lasers
      if M.isSectorX() then
        alpha = 0
        for _, laser in ipairs(weapons.lasers) do
          local dist = math.sqrt((turret.x - laser.x)^2 + (turret.y - laser.y)^2)
          if dist < 400 then
            local t = 1 - (dist / 400)
            local laserAlpha = math.exp(-12 * (1 - t)) * 0.9
            alpha = math.max(alpha, laserAlpha)
          end
        end
        if alpha <= 0.01 then goto continue end
      end

      love.graphics.setColor(0.5, 0.5, 0.5, alpha)
      love.graphics.rectangle("fill", turret.x - 15, turret.y, 30, 15)
      love.graphics.setColor(0.8, 0.3, 0.3, alpha)
      love.graphics.circle("fill", turret.x, turret.y, 10)

      ::continue::
    end
  end
end

function M.drawCapitalShips()
  for _, ship in ipairs(capitalship.ships) do
    local alpha = 1

    -- In Sector X, capital ships only visible near lasers
    if M.isSectorX() then
      alpha = 0
      for _, laser in ipairs(weapons.lasers) do
        local dist = math.sqrt((ship.x - laser.x)^2 + (ship.y - laser.y)^2)
        if dist < 400 then
          local t = 1 - (dist / 400)
          local laserAlpha = math.exp(-12 * (1 - t)) * 0.9
          alpha = math.max(alpha, laserAlpha)
        end
      end
      if alpha <= 0.01 then goto continue end
    end

    -- Main hull
    love.graphics.setColor(0.4, 0.4, 0.5, alpha)
    love.graphics.rectangle("fill", ship.x - ship.width/2, ship.y - ship.height/2, ship.width, ship.height)

    -- Bridge
    love.graphics.setColor(0.3, 0.3, 0.4, alpha)
    love.graphics.rectangle("fill", ship.x - 30, ship.y - ship.height/2 - 15, 60, 20)

    -- Engine glow
    love.graphics.setColor(0.3, 0.5, 1, 0.8 * alpha)
    love.graphics.rectangle("fill", ship.x - 60, ship.y + ship.height/2 - 5, 30, 10)
    love.graphics.rectangle("fill", ship.x + 30, ship.y + ship.height/2 - 5, 30, 10)

    -- Cannons
    love.graphics.setColor(0.6, 0.3, 0.3, alpha)
    love.graphics.circle("fill", ship.x - 60, ship.y + 20, 8)
    love.graphics.circle("fill", ship.x, ship.y + 30, 8)
    love.graphics.circle("fill", ship.x + 60, ship.y + 20, 8)

    -- Health bar
    local healthPct = ship.health / ship.maxHealth
    love.graphics.setColor(0.2, 0.2, 0.2, alpha)
    love.graphics.rectangle("fill", ship.x - 40, ship.y - ship.height/2 - 25, 80, 6)
    love.graphics.setColor(1, 0.3, 0.3, alpha)
    love.graphics.rectangle("fill", ship.x - 40, ship.y - ship.height/2 - 25, 80 * healthPct, 6)

    ::continue::
  end
end

function M.drawMothership()
  local m = mothership.mothership
  if not m or not m.active then return end

  -- Main hull
  love.graphics.setColor(0.3, 0.25, 0.4)
  love.graphics.rectangle("fill", m.x - m.width/2, m.y - m.height/2, m.width, m.height)

  -- Hull details
  love.graphics.setColor(0.4, 0.35, 0.5)
  love.graphics.rectangle("fill", m.x - 100, m.y - 40, 200, 20)
  love.graphics.rectangle("fill", m.x - 120, m.y + 10, 240, 30)

  -- Spawn ports (sides)
  love.graphics.setColor(0.2, 0.2, 0.3)
  love.graphics.rectangle("fill", m.x - 100, m.y + 50, 40, 25)
  love.graphics.rectangle("fill", m.x + 60, m.y + 50, 40, 25)

  -- Weapon ports
  love.graphics.setColor(0.6, 0.2, 0.2)
  love.graphics.circle("fill", m.x - 60, m.y + m.height/2 - 10, 10)
  love.graphics.circle("fill", m.x, m.y + m.height/2 - 10, 10)
  love.graphics.circle("fill", m.x + 60, m.y + m.height/2 - 10, 10)

  -- Core (Phase 2)
  if m.phase == 2 then
    love.graphics.setColor(1, 0.3, 0.1)
    love.graphics.circle("fill", m.x, m.y, 30)
    local pulse = math.abs(math.sin(love.timer.getTime() * 4))
    love.graphics.setColor(1, 0.5, 0.2, pulse * 0.5)
    love.graphics.circle("fill", m.x, m.y, 40)
  end

  -- Health bar
  local healthPct, maxHealth
  if m.phase == 1 then
    healthPct = m.hullHealth / m.hullMaxHealth
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", m.x - 60, m.y - m.height/2 - 20, 120, 8)
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("fill", m.x - 60, m.y - m.height/2 - 20, 120 * healthPct, 8)
  else
    healthPct = m.coreHealth / m.coreMaxHealth
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", m.x - 60, m.y - m.height/2 - 20, 120, 8)
    love.graphics.setColor(1, 0.3, 0.1)
    love.graphics.rectangle("fill", m.x - 60, m.y - m.height/2 - 20, 120 * healthPct, 8)
  end
end

function M.drawAllies()
  for _, ally in ipairs(allies.allies) do
    if ally.converted then
      -- Purple glow for converted wingmen
      love.graphics.setColor(0.6, 0.1, 1, 0.2)
      love.graphics.circle("fill", ally.x, ally.y, 20)
      love.graphics.setColor(0.5, 0.1, 0.9)
      love.graphics.polygon("fill", ally.x, ally.y - 12, ally.x - 10, ally.y + 10, ally.x + 10, ally.y + 10)
      love.graphics.setColor(0.7, 0.3, 1)
      love.graphics.polygon("fill", ally.x - 18, ally.y + 5, ally.x - 10, ally.y, ally.x - 10, ally.y + 10, ally.x - 18, ally.y + 10)
      love.graphics.polygon("fill", ally.x + 18, ally.y + 5, ally.x + 10, ally.y, ally.x + 10, ally.y + 10, ally.x + 18, ally.y + 10)
      love.graphics.setColor(0.8, 0.5, 1, 0.6)
      love.graphics.polygon("line", ally.x, ally.y - 12, ally.x - 10, ally.y + 10, ally.x + 10, ally.y + 10)
    else
      -- Blue triangle (friendly color)
      love.graphics.setColor(0.2, 0.6, 1)
      love.graphics.polygon("fill", ally.x, ally.y - 12, ally.x - 10, ally.y + 10, ally.x + 10, ally.y + 10)

      -- Wings
      love.graphics.setColor(0.3, 0.7, 1)
      love.graphics.polygon("fill", ally.x - 18, ally.y + 5, ally.x - 10, ally.y, ally.x - 10, ally.y + 10, ally.x - 18, ally.y + 10)
      love.graphics.polygon("fill", ally.x + 18, ally.y + 5, ally.x + 10, ally.y, ally.x + 10, ally.y + 10, ally.x + 18, ally.y + 10)

      -- Outline
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.polygon("line", ally.x, ally.y - 12, ally.x - 10, ally.y + 10, ally.x + 10, ally.y + 10)
    end
  end
end

function M.drawBoss()
  local b = boss.currentBoss
  if not b or not b.active then return end

  if b.type == "midboss" then
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", b.x - b.width/2, b.y - b.height/2, b.width, b.height)
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.circle("fill", b.x, b.y, 20)

  elseif b.type == "finalboss" then
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill", b.x - b.width/2, b.y - b.height/2, b.width, b.height)

    if not b.leftArm.destroyed then
      love.graphics.setColor(0.5, 0.3, 0.3)
      love.graphics.rectangle("fill", b.x + b.leftArm.x - 25, b.y + 20, 50, 30)
    end
    if not b.rightArm.destroyed then
      love.graphics.setColor(0.5, 0.3, 0.3)
      love.graphics.rectangle("fill", b.x + b.rightArm.x - 25, b.y + 20, 50, 30)
    end

    if b.phase >= 2 then
      love.graphics.setColor(1, 0.5, 0)
      love.graphics.circle("fill", b.x, b.y, 25)
    end

  elseif b.type == "area6boss" then
    -- Main body
    love.graphics.setColor(0.3, 0.3, 0.5)
    love.graphics.rectangle("fill", b.x - b.width/2, b.y - b.height/2, b.width, b.height)

    -- Shield generators (Phase 1)
    if b.phase == 1 then
      if not b.leftShield.destroyed then
        love.graphics.setColor(0.2, 0.5, 0.8)
        love.graphics.circle("fill", b.x - 70, b.y, 25)
        love.graphics.setColor(0.4, 0.7, 1, 0.5)
        love.graphics.circle("line", b.x - 70, b.y, 30)
      end
      if not b.rightShield.destroyed then
        love.graphics.setColor(0.2, 0.5, 0.8)
        love.graphics.circle("fill", b.x + 70, b.y, 25)
        love.graphics.setColor(0.4, 0.7, 1, 0.5)
        love.graphics.circle("line", b.x + 70, b.y, 30)
      end
    end

    -- Core (visible in Phase 2+)
    if b.phase >= 2 then
      local coreColor = b.phase == 3 and {1, 0.3, 0.1} or {1, 0.6, 0.2}
      love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3])
      love.graphics.circle("fill", b.x, b.y, 35)

      -- Pulsing effect in Phase 3
      if b.phase == 3 then
        local pulse = math.abs(math.sin(love.timer.getTime() * 5))
        love.graphics.setColor(1, 0.2, 0.1, pulse * 0.5)
        love.graphics.circle("fill", b.x, b.y, 45)
      end
    end

    -- Weapon ports
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", b.x - 50, b.y + 40, 20, 15)
    love.graphics.rectangle("fill", b.x + 30, b.y + 40, 20, 15)
    love.graphics.rectangle("fill", b.x - 10, b.y + 50, 20, 15)
  end
end

function M.drawBolseStation()
  local s = bolse.getStation()
  if not s or not s.active then return end

  love.graphics.push()
  love.graphics.translate(s.x, s.y)

  -- Outer structure ring
  love.graphics.setColor(0.3, 0.3, 0.4)
  love.graphics.setLineWidth(6)
  love.graphics.circle("line", 0, 0, 120)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", 0, 0, 100)

  -- Rotating arms
  love.graphics.rotate(s.rotation)
  for i = 0, 5 do
    love.graphics.setColor(0.35, 0.35, 0.45)
    love.graphics.rectangle("fill", 25, -6, 75, 12)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("fill", 85, -10, 20, 20)
    love.graphics.rotate(math.pi * 2 / 6)
  end
  love.graphics.rotate(-s.rotation)

  -- Core
  if s.coreExposed then
    local pulse = math.abs(math.sin(love.timer.getTime() * 4))
    love.graphics.setColor(1, 0.3, 0.1, 0.8 + pulse * 0.2)
    love.graphics.circle("fill", 0, 0, 35)
    love.graphics.setColor(1, 0.5, 0.2, pulse * 0.5)
    love.graphics.circle("fill", 0, 0, 45)
    love.graphics.setColor(1, 0.2, 0.1, pulse * 0.3)
    love.graphics.circle("line", 0, 0, 50)
  elseif s.phase >= 2 then
    local alpha = s.coreExposure or 0
    love.graphics.setColor(1, 0.4, 0.2, alpha * 0.8)
    love.graphics.circle("fill", 0, 0, 25 + alpha * 10)
  else
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.circle("fill", 0, 0, 30)
  end

  love.graphics.pop()

  -- Turrets (drawn in world space)
  for _, turret in ipairs(s.turrets) do
    if not turret.destroyed then
      love.graphics.setColor(0.6, 0.25, 0.25)
      love.graphics.circle("fill", turret.worldX, turret.worldY, 12)
      love.graphics.setColor(0.9, 0.35, 0.35)
      love.graphics.circle("line", turret.worldX, turret.worldY, 15)

      -- Turret health indicator
      local healthPct = turret.health / turret.maxHealth
      if healthPct < 1 then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", turret.worldX - 12, turret.worldY - 22, 24, 4)
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.rectangle("fill", turret.worldX - 12, turret.worldY - 22, 24 * healthPct, 4)
      end
    end
  end

  -- Station health bar (core)
  if s.phase >= 2 then
    local healthPct = s.coreHealth / s.coreMaxHealth
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", s.x - 60, s.y - 150, 120, 8)
    love.graphics.setColor(1, 0.4, 0.2)
    love.graphics.rectangle("fill", s.x - 60, s.y - 150, 120 * healthPct, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf("CORE", s.x - 60, s.y - 165, 120, "center")
  end

  love.graphics.setLineWidth(1)
end

function M.drawRival()
  local r = rival.getRival()
  if not r or not r.active or r.destroyed then return end

  love.graphics.push()
  love.graphics.translate(r.x, r.y)

  -- Body (dark gray/black scheme)
  love.graphics.setColor(0.15, 0.15, 0.18)
  love.graphics.polygon("fill", 0, -18, -18, 15, 18, 15)

  -- Red accents
  love.graphics.setColor(0.7, 0.15, 0.15)
  love.graphics.polygon("fill", 0, -12, -10, 10, 10, 10)

  -- Cockpit
  love.graphics.setColor(0.2, 0.2, 0.25)
  love.graphics.circle("fill", 0, -2, 6)

  -- Wings
  love.graphics.setColor(0.12, 0.12, 0.15)
  love.graphics.polygon("fill", -30, 12, -18, 5, -18, 15, -30, 18)
  love.graphics.polygon("fill", 30, 12, 18, 5, 18, 15, 30, 18)

  -- Wing tips (red)
  love.graphics.setColor(0.6, 0.1, 0.1)
  love.graphics.polygon("fill", -32, 13, -30, 12, -30, 18, -32, 17)
  love.graphics.polygon("fill", 32, 13, 30, 12, 30, 18, 32, 17)

  -- Reflection effect
  if r.reflecting then
    love.graphics.setColor(0.3, 0.8, 1, 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", 0, 0, 40)
    love.graphics.setColor(0.5, 0.9, 1, 0.4)
    love.graphics.circle("line", 0, 0, 35)
    love.graphics.setLineWidth(1)
  end

  love.graphics.pop()

  -- Health bar
  local healthPct = r.health / r.maxHealth
  love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
  love.graphics.rectangle("fill", r.x - 25, r.y - 32, 50, 5)
  love.graphics.setColor(0.8, 0.2, 0.2)
  love.graphics.rectangle("fill", r.x - 25, r.y - 32, 50 * healthPct, 5)

  -- "WOLF" label
  love.graphics.setColor(1, 0.3, 0.3)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("WOLF", r.x - 25, r.y - 45, 50, "center")
end

function M.drawRivalLasers()
  for _, laser in ipairs(rival.getLasers()) do
    love.graphics.setColor(1, 0.2, 0.5)
    love.graphics.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2, laser.width, laser.height)
  end
end

function M.drawMaze()
  if not maze.isActive() then return end

  for _, wall in ipairs(maze.getWalls()) do
    -- Left wall section
    love.graphics.setColor(0.3, 0.25, 0.35)
    love.graphics.rectangle("fill", 0, wall.y, wall.gapLeft, wall.height)

    -- Right wall section
    love.graphics.rectangle("fill", wall.gapRight, wall.y, screen.WIDTH - wall.gapRight, wall.height)

    -- Wall outlines
    love.graphics.setColor(0.5, 0.4, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, wall.y, wall.gapLeft, wall.height)
    love.graphics.rectangle("line", wall.gapRight, wall.y, screen.WIDTH - wall.gapRight, wall.height)

    -- Gap indicators (subtle glow)
    love.graphics.setColor(0.3, 0.6, 0.3, 0.3)
    love.graphics.rectangle("fill", wall.gapLeft, wall.y, wall.gapRight - wall.gapLeft, wall.height)
    love.graphics.setLineWidth(1)
  end
end

function M.drawVenomBoss()
  local vb = venomboss.boss
  if not vb or not vb.active then return end

  love.graphics.push()
  love.graphics.translate(vb.x, vb.y)

  local alpha = vb.fadeAlpha

  -- Main body
  love.graphics.setColor(0.25 * alpha, 0.2 * alpha, 0.35 * alpha, alpha)
  love.graphics.rectangle("fill", -vb.width/2, -vb.height/2, vb.width, vb.height)

  -- Body details
  love.graphics.setColor(0.35 * alpha, 0.3 * alpha, 0.45 * alpha, alpha)
  love.graphics.rectangle("fill", -50, -30, 100, 20)
  love.graphics.rectangle("fill", -60, 10, 120, 25)

  -- Central eye/core
  local coreColor = {0.8, 0.2, 0.6}
  if vb.phase >= 2 then coreColor = {1, 0.3, 0.2} end
  if vb.phase == 3 then
    local pulse = math.abs(math.sin(love.timer.getTime() * 6))
    coreColor[1] = 1
    coreColor[2] = 0.2 + pulse * 0.3
    coreColor[3] = 0.1
  end
  love.graphics.setColor(coreColor[1] * alpha, coreColor[2] * alpha, coreColor[3] * alpha, alpha)
  love.graphics.circle("fill", 0, 0, 30)

  -- Core glow
  if vb.phase >= 2 then
    local pulse = math.abs(math.sin(love.timer.getTime() * 4))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], pulse * 0.4 * alpha)
    love.graphics.circle("fill", 0, 0, 40)
  end

  -- Weapon ports
  love.graphics.setColor(0.6 * alpha, 0.15 * alpha, 0.15 * alpha, alpha)
  love.graphics.rectangle("fill", -50, 35, 25, 20)
  love.graphics.rectangle("fill", 25, 35, 25, 20)
  love.graphics.rectangle("fill", -12, 45, 24, 15)

  love.graphics.pop()

  -- Continuous laser
  if vb.laserActive then
    local ex, ey = venomboss.getLaserEndpoint()
    local laserColor = vb.laserReflected and {0.3, 0.8, 1} or {1, 0.2, 0.3}

    -- Outer glow
    love.graphics.setColor(laserColor[1], laserColor[2], laserColor[3], 0.3)
    love.graphics.setLineWidth(20)
    love.graphics.line(vb.x, vb.y + 50, ex, ey)

    -- Middle layer
    love.graphics.setColor(laserColor[1], laserColor[2], laserColor[3], 0.6)
    love.graphics.setLineWidth(10)
    love.graphics.line(vb.x, vb.y + 50, ex, ey)

    -- Core beam
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(4)
    love.graphics.line(vb.x, vb.y + 50, ex, ey)

    love.graphics.setLineWidth(1)
  end

  -- Health bar
  local healthPct = vb.health / vb.maxHealth
  love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
  love.graphics.rectangle("fill", vb.x - 60, vb.y - vb.height/2 - 25, 120, 8)
  local barColor = vb.phase == 3 and {1, 0.3, 0.1} or {0.7, 0.2, 0.5}
  love.graphics.setColor(barColor[1], barColor[2], barColor[3])
  love.graphics.rectangle("fill", vb.x - 60, vb.y - vb.height/2 - 25, 120 * healthPct, 8)

  -- Boss name
  love.graphics.setColor(1, 0.4, 0.6)
  love.graphics.setFont(love.graphics.newFont(12))
  love.graphics.printf("ANDROSS MECH", vb.x - 60, vb.y - vb.height/2 - 40, 120, "center")
end

function M.drawSectorZBoss()
  local szb = sectorzboss.boss
  if not szb or not szb.active then return end

  love.graphics.push()
  love.graphics.translate(szb.x, szb.y)

  local alpha = szb.fadeAlpha or 1

  -- Phase-based color (Elden Ring aesthetic: crimson/gold/black)
  local phaseColors = {
    {0.15, 0.1, 0.1},   -- Phase 1: Dark
    {0.2, 0.1, 0.15},   -- Phase 2: Shadow
    {0.25, 0.12, 0.1},  -- Phase 3: Void Waves tint
    {0.2, 0.15, 0.2},   -- Phase 4: Gravity purple
    {0.3, 0.15, 0.1},   -- Phase 5: Blood red
    {0.1, 0.1, 0.15},   -- Phase 6: Void Blight dark
    {0.35, 0.2, 0.1}    -- Phase 7: Void sLAYER gold/crimson
  }
  local baseColor = phaseColors[szb.phase] or phaseColors[1]

  -- Main body - menacing dark form
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  love.graphics.rectangle("fill", -szb.width/2, -szb.height/2, szb.width, szb.height)

  -- Armored plating
  love.graphics.setColor(0.1 * alpha, 0.08 * alpha, 0.08 * alpha, alpha)
  love.graphics.rectangle("fill", -60, -45, 120, 30)
  love.graphics.rectangle("fill", -70, 5, 140, 35)

  -- Central eye/core - glowing based on phase
  local coreColors = {
    {0.8, 0.3, 0.2},   -- Phase 1: Orange
    {0.6, 0.2, 0.8},   -- Phase 2: Purple (shadow)
    {1, 0.2, 0.1},     -- Phase 3: Void Waves red
    {0.5, 0.2, 1},     -- Phase 4: Gravity purple
    {1, 0.5, 0.3},     -- Phase 5: Waterfowl gold
    {0.2, 0.1, 0.1},   -- Phase 6: Void Blight black
    {1, 0.8, 0.2}      -- Phase 7: Void sLAYER gold
  }
  local coreColor = coreColors[szb.phase] or coreColors[1]

  -- Pulsing effect in later phases
  local pulse = 1
  if szb.phase >= 5 then
    pulse = 0.7 + math.abs(math.sin(love.timer.getTime() * 6)) * 0.3
  end
  if szb.enraged then
    pulse = 0.5 + math.abs(math.sin(love.timer.getTime() * 10)) * 0.5
  end

  love.graphics.setColor(coreColor[1] * pulse * alpha, coreColor[2] * pulse * alpha, coreColor[3] * pulse * alpha, alpha)
  love.graphics.circle("fill", 0, -5, 35)

  -- Core inner glow
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, 0.6 * alpha)
  love.graphics.circle("fill", 0, -5, 15)

  -- Outer glow during transitions or attacks
  if szb.phaseTransitioning or szb.enraged then
    local glowPulse = math.abs(math.sin(love.timer.getTime() * 8))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], glowPulse * 0.5 * alpha)
    love.graphics.circle("fill", 0, -5, 55)
  end

  -- Weapon ports
  love.graphics.setColor(0.5 * alpha, 0.1 * alpha, 0.1 * alpha, alpha)
  love.graphics.rectangle("fill", -55, 45, 30, 20)
  love.graphics.rectangle("fill", 25, 45, 30, 20)
  love.graphics.rectangle("fill", -15, 50, 30, 15)

  -- Phase indicator wings/appendages
  if szb.phase >= 3 then
    love.graphics.setColor(0.6 * alpha, 0.15 * alpha, 0.15 * alpha, alpha * 0.8)
    love.graphics.polygon("fill", -80, 0, -60, -30, -60, 30)
    love.graphics.polygon("fill", 80, 0, 60, -30, 60, 30)
  end

  love.graphics.pop()

  -- Draw rot zones (Void Waves - Phase 3+)
  if szb.rotZones then
    for _, zone in ipairs(szb.rotZones) do
      local zonePulse = 0.3 + math.abs(math.sin(love.timer.getTime() * 3 + zone.x)) * 0.3
      -- Outer glow
      love.graphics.setColor(0.8, 0.2, 0.1, zonePulse * 0.3)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 10)
      -- Inner zone
      love.graphics.setColor(1, 0.3, 0.1, zonePulse * 0.5)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      -- Core
      love.graphics.setColor(1, 0.5, 0.2, zonePulse * 0.7)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.5)
    end
  end

  -- Draw gravity well indicator (Phase 4+)
  if szb.gravityActive then
    local wellPulse = 0.4 + math.abs(math.sin(love.timer.getTime() * 5)) * 0.4
    love.graphics.setColor(0.4, 0.2, 0.8, wellPulse * 0.3)
    love.graphics.circle("line", szb.x, szb.y, 150)
    love.graphics.circle("line", szb.x, szb.y, 100)
    love.graphics.circle("line", szb.x, szb.y, 50)
  end

  -- Attack warning indicators
  local warning, progress = sectorzboss.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    -- Warning bar
    love.graphics.setColor(0.3, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200, 10)
    love.graphics.setColor(1, 0.3, 0.1)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200 * progress, 10)
  end

  -- Health bar (Elden Ring style - large at bottom)
  local healthPct = szb.health / szb.maxHealth
  local barWidth = 300
  local barX = screen.WIDTH/2 - barWidth/2
  local barY = 30

  -- Background
  love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
  love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, 16)

  -- Health segments (7 phases visible)
  for i = 1, 7 do
    local segStart = (i - 1) / 7
    local segEnd = i / 7
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local phaseColor = coreColors[i]
      love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
    end
    -- Segment divider
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 7) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  love.graphics.setColor(1, 0.8, 0.4)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. szb.phase .. "/7", barX, barY + 14, barWidth, "center")

  -- Boss name
  local bossName = szb.enraged and "AGENT OF THE MACHINE - VOID SLAYER" or "AGENT OF THE MACHINE"
  love.graphics.setColor(1, 0.7, 0.3)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(bossName, barX, barY - 20, barWidth, "center")
end

function M.drawWardenBoss()
  local wb = wardenboss.boss
  if not wb or not wb.active then return end

  love.graphics.push()
  love.graphics.translate(wb.x, wb.y)

  local alpha = wb.fadeAlpha or 1
  local time = love.timer.getTime()

  -- Phase-based colors (dark/ancient fortress aesthetic)
  local phaseColors = {
    {0.25, 0.15, 0.05},  -- Phase 1: Dark bronze
    {0.3, 0.12, 0.08},   -- Phase 2: Rusted crimson
    {0.2, 0.1, 0.2},     -- Phase 3: Void purple
    {0.35, 0.2, 0.05},   -- Phase 4: Ancient gold
    {0.4, 0.15, 0.05}    -- Phase 5: Molten fury
  }
  local baseColor = phaseColors[wb.phase] or phaseColors[1]

  -- Main body - imposing armored form
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  love.graphics.rectangle("fill", -wb.width/2, -wb.height/2, wb.width, wb.height)

  -- Heavy armored plating (layered)
  love.graphics.setColor(0.12 * alpha, 0.08 * alpha, 0.04 * alpha, alpha)
  love.graphics.rectangle("fill", -65, -50, 130, 35)
  love.graphics.rectangle("fill", -75, 10, 150, 40)

  -- Shoulder pauldrons
  love.graphics.setColor(0.3 * alpha, 0.18 * alpha, 0.06 * alpha, alpha)
  love.graphics.polygon("fill", -80, -20, -95, 10, -70, 15, -60, -15)
  love.graphics.polygon("fill", 80, -20, 95, 10, 70, 15, 60, -15)

  -- Guards (shield generators) - Phase 1 only
  if not wb.guardsDown then
    if not wb.leftGuard.destroyed then
      love.graphics.setColor(0.6 * alpha, 0.35 * alpha, 0.1 * alpha, alpha)
      love.graphics.circle("fill", -70, 0, 22)
      local shieldPulse = 0.5 + math.sin(time * 4) * 0.3
      love.graphics.setColor(0.8, 0.5, 0.15, shieldPulse * alpha)
      love.graphics.circle("line", -70, 0, 28)
      love.graphics.circle("line", -70, 0, 32)
    end
    if not wb.rightGuard.destroyed then
      love.graphics.setColor(0.6 * alpha, 0.35 * alpha, 0.1 * alpha, alpha)
      love.graphics.circle("fill", 70, 0, 22)
      local shieldPulse = 0.5 + math.sin(time * 4 + math.pi) * 0.3
      love.graphics.setColor(0.8, 0.5, 0.15, shieldPulse * alpha)
      love.graphics.circle("line", 70, 0, 28)
      love.graphics.circle("line", 70, 0, 32)
    end
  end

  -- Central eye/visor - glowing menacingly
  local coreColors = {
    {0.9, 0.5, 0.1},   -- Phase 1: Amber
    {1, 0.3, 0.15},    -- Phase 2: Fire red
    {0.6, 0.2, 0.9},   -- Phase 3: Void purple
    {1, 0.8, 0.2},     -- Phase 4: Golden
    {1, 0.4, 0.1}      -- Phase 5: Molten orange
  }
  local coreColor = coreColors[wb.phase] or coreColors[1]

  local pulse = 1
  if wb.phase >= 3 then
    pulse = 0.7 + math.abs(math.sin(time * 5)) * 0.3
  end
  if wb.phase >= 5 then
    pulse = 0.5 + math.abs(math.sin(time * 8)) * 0.5
  end

  -- Visor slit (wide horizontal eye)
  love.graphics.setColor(0.05, 0.02, 0.02, alpha)
  love.graphics.rectangle("fill", -40, -15, 80, 12)
  love.graphics.setColor(coreColor[1] * pulse * alpha, coreColor[2] * pulse * alpha, coreColor[3] * pulse * alpha, alpha)
  love.graphics.rectangle("fill", -35, -13, 70, 8)

  -- Inner eye glow
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, 0.5 * alpha * pulse)
  love.graphics.rectangle("fill", -15, -12, 30, 6)

  -- Outer glow during phase transitions
  if wb.phaseTransitioning then
    local glowPulse = math.abs(math.sin(time * 8))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], glowPulse * 0.6 * alpha)
    love.graphics.circle("fill", 0, -9, 60)
  end

  -- Crown/crest (appears Phase 3+)
  if wb.phase >= 3 then
    love.graphics.setColor(0.5 * alpha, 0.3 * alpha, 0.08 * alpha, alpha)
    love.graphics.polygon("fill", 0, -65, -20, -50, -15, -45, 0, -55, 15, -45, 20, -50)
    love.graphics.setColor(coreColor[1] * 0.8, coreColor[2] * 0.8, coreColor[3] * 0.8, 0.7 * alpha)
    love.graphics.circle("fill", 0, -52, 5)
  end

  -- Weapon ports (glow in later phases)
  local weaponGlow = wb.phase >= 4 and (0.5 + math.sin(time * 6) * 0.3) or 0
  love.graphics.setColor((0.5 + weaponGlow) * alpha, 0.15 * alpha, 0.08 * alpha, alpha)
  love.graphics.rectangle("fill", -55, 45, 25, 18)
  love.graphics.rectangle("fill", 30, 45, 25, 18)
  love.graphics.rectangle("fill", -12, 52, 24, 14)

  -- Phase 4+ chains (swinging appendages)
  if wb.phase >= 4 then
    love.graphics.setColor(0.4 * alpha, 0.25 * alpha, 0.1 * alpha, alpha * 0.9)
    local chainAngle = math.sin(time * 3) * 0.4
    love.graphics.push()
    love.graphics.rotate(chainAngle)
    love.graphics.polygon("fill", -85, -5, -95, 5, -90, 25, -80, 15)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.rotate(-chainAngle)
    love.graphics.polygon("fill", 85, -5, 95, 5, 90, 25, 80, 15)
    love.graphics.pop()
  end

  love.graphics.pop()

  -- Draw prison zones (Phase 3+)
  if wb.prisonZones then
    for _, zone in ipairs(wb.prisonZones) do
      local zonePulse = 0.3 + math.abs(math.sin(time * 2.5 + zone.x * 0.05)) * 0.3
      -- Outer cage bars
      love.graphics.setColor(0.5, 0.3, 0.8, zonePulse * 0.25)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 12)
      -- Inner void
      love.graphics.setColor(0.3, 0.1, 0.5, zonePulse * 0.4)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      -- Core glow
      love.graphics.setColor(0.6, 0.2, 0.9, zonePulse * 0.6)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.4)
      -- Cage bars
      love.graphics.setColor(0.7, 0.4, 1, zonePulse * 0.5)
      love.graphics.setLineWidth(2)
      for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 + time * 0.5
        local x1 = zone.x + math.cos(angle) * zone.radius
        local y1 = zone.y + math.sin(angle) * zone.radius
        love.graphics.line(zone.x, zone.y, x1, y1)
      end
      love.graphics.setLineWidth(1)
    end
  end

  -- Attack warning indicators
  local warning, progress = wardenboss.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.6, 0.1, 0.9)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    love.graphics.setColor(0.2, 0.1, 0.05, 0.8)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200, 10)
    love.graphics.setColor(1, 0.6, 0.1)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200 * progress, 10)
  end

  -- Health bar (Elden Ring style - golden/bronze)
  local healthPct = wb.health / wb.maxHealth
  local barWidth = 300
  local barX = screen.WIDTH/2 - barWidth/2
  local barY = 30

  -- Background
  love.graphics.setColor(0.08, 0.05, 0.02, 0.9)
  love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, 16)

  -- Health segments (5 phases visible)
  for i = 1, 5 do
    local segStart = (i - 1) / 5
    local segEnd = i / 5
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local phaseColor = coreColors[i]
      love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
    end
    -- Segment divider
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 5) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  love.graphics.setColor(1, 0.8, 0.3)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. wb.phase .. "/5", barX, barY + 14, barWidth, "center")

  -- Boss name
  local bossName = wb.phase >= 5 and "THE WARDEN - UNCHAINED" or "THE WARDEN"
  love.graphics.setColor(0.9, 0.6, 0.15)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(bossName, barX, barY - 20, barWidth, "center")
end

function M.drawSentinelBoss()
  local sb = sentinelboss.boss
  if not sb or not sb.active then return end

  love.graphics.push()
  love.graphics.translate(sb.x, sb.y)

  local alpha = sb.fadeAlpha or 1
  local time = love.timer.getTime()

  -- Phase-based colors (high-tech cyber aesthetic)
  local phaseColors = {
    {0.2, 0.3, 0.5},   -- Phase 1: Steel blue
    {0.1, 0.6, 0.7},   -- Phase 2: Electric cyan
    {0.1, 0.15, 0.45},  -- Phase 3: Deep blue
    {0.4, 0.15, 0.55},  -- Phase 4: Violet plasma
    {0.7, 0.75, 0.85}   -- Phase 5: White singularity
  }
  local baseColor = phaseColors[sb.phase] or phaseColors[1]

  -- Main body - angular armored sentinel form
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  -- Central hexagonal body
  love.graphics.polygon("fill",
    -sb.width/2, -20,
    -sb.width/2 + 15, -sb.height/2,
    sb.width/2 - 15, -sb.height/2,
    sb.width/2, -20,
    sb.width/2 - 15, sb.height/2,
    -sb.width/2 + 15, sb.height/2
  )

  -- Armored plating (angular tech panels)
  love.graphics.setColor(0.06 * alpha, 0.1 * alpha, 0.18 * alpha, alpha)
  love.graphics.polygon("fill", -60, -40, -45, -50, 45, -50, 60, -40, 50, -30, -50, -30)
  love.graphics.polygon("fill", -65, 10, 65, 10, 60, 30, -60, 30)

  -- Angular shoulder pylons
  love.graphics.setColor(0.15 * alpha, 0.3 * alpha, 0.45 * alpha, alpha)
  love.graphics.polygon("fill", -80, -25, -95, 5, -85, 20, -65, 10, -70, -20)
  love.graphics.polygon("fill", 80, -25, 95, 5, 85, 20, 65, 10, 70, -20)

  -- Guards (drone shield generators) - Phase 1 only
  if not sb.guardsDown then
    if not sb.leftGuard.destroyed then
      love.graphics.setColor(0.2 * alpha, 0.6 * alpha, 0.8 * alpha, alpha)
      -- Hexagonal shield node
      local gx, gy = -70, 0
      love.graphics.polygon("fill",
        gx, gy-18, gx+16, gy-9, gx+16, gy+9,
        gx, gy+18, gx-16, gy+9, gx-16, gy-9)
      local shieldPulse = 0.5 + math.sin(time * 5) * 0.3
      love.graphics.setColor(0.3, 0.8, 1, shieldPulse * alpha)
      love.graphics.setLineWidth(2)
      love.graphics.polygon("line",
        gx, gy-24, gx+21, gy-12, gx+21, gy+12,
        gx, gy+24, gx-21, gy+12, gx-21, gy-12)
      love.graphics.setLineWidth(1)
    end
    if not sb.rightGuard.destroyed then
      love.graphics.setColor(0.2 * alpha, 0.6 * alpha, 0.8 * alpha, alpha)
      local gx, gy = 70, 0
      love.graphics.polygon("fill",
        gx, gy-18, gx+16, gy-9, gx+16, gy+9,
        gx, gy+18, gx-16, gy+9, gx-16, gy-9)
      local shieldPulse = 0.5 + math.sin(time * 5 + math.pi) * 0.3
      love.graphics.setColor(0.3, 0.8, 1, shieldPulse * alpha)
      love.graphics.setLineWidth(2)
      love.graphics.polygon("line",
        gx, gy-24, gx+21, gy-12, gx+21, gy+12,
        gx, gy+24, gx-21, gy+12, gx-21, gy-12)
      love.graphics.setLineWidth(1)
    end
  end

  -- Scanning visor (wide horizontal with data streams)
  local coreColors = {
    {0.3, 0.7, 1},     -- Phase 1: Ice blue
    {0, 1, 0.8},       -- Phase 2: Teal
    {0.2, 0.4, 1},     -- Phase 3: Deep electric blue
    {0.7, 0.3, 1},     -- Phase 4: Violet
    {1, 1, 1}          -- Phase 5: Pure white
  }
  local coreColor = coreColors[sb.phase] or coreColors[1]

  local pulse = 1
  if sb.phase >= 3 then
    pulse = 0.7 + math.abs(math.sin(time * 6)) * 0.3
  end
  if sb.phase >= 5 then
    pulse = 0.5 + math.abs(math.sin(time * 10)) * 0.5
  end

  -- Visor housing
  love.graphics.setColor(0.03, 0.05, 0.08, alpha)
  love.graphics.rectangle("fill", -45, -18, 90, 16, 3, 3)
  -- Scanning beam visor
  love.graphics.setColor(coreColor[1] * pulse * alpha, coreColor[2] * pulse * alpha, coreColor[3] * pulse * alpha, alpha)
  love.graphics.rectangle("fill", -40, -16, 80, 12, 2, 2)
  -- Scanning sweep line
  local scanX = math.sin(time * 4) * 35
  love.graphics.setColor(1, 1, 1, 0.7 * alpha * pulse)
  love.graphics.rectangle("fill", scanX - 2, -16, 4, 12)

  -- Inner core glow
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, 0.4 * alpha * pulse)
  love.graphics.rectangle("fill", -12, -15, 24, 10)

  -- Phase transition glow
  if sb.phaseTransitioning then
    local glowPulse = math.abs(math.sin(time * 10))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], glowPulse * 0.6 * alpha)
    love.graphics.circle("fill", 0, -10, 65)
  end

  -- Antenna array (appears Phase 2+)
  if sb.phase >= 2 then
    love.graphics.setColor(0.3 * alpha, 0.5 * alpha, 0.7 * alpha, alpha)
    love.graphics.polygon("fill", -8, -58, 0, -72, 8, -58, 4, -50, -4, -50)
    -- Signal waves from antenna
    local wavePulse = math.sin(time * 6) * 0.4 + 0.5
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], wavePulse * 0.4 * alpha)
    love.graphics.arc("line", "open", 0, -65, 15, -2.5, -0.6)
    love.graphics.arc("line", "open", 0, -65, 22, -2.5, -0.6)
  end

  -- Weapon emitter ports (glow in later phases)
  local weaponGlow = sb.phase >= 4 and (0.5 + math.sin(time * 7) * 0.3) or 0
  love.graphics.setColor((0.2 + weaponGlow * 0.5) * alpha, (0.5 + weaponGlow * 0.3) * alpha, (0.8 + weaponGlow * 0.2) * alpha, alpha)
  love.graphics.rectangle("fill", -55, 40, 22, 16, 2, 2)
  love.graphics.rectangle("fill", 33, 40, 22, 16, 2, 2)
  love.graphics.rectangle("fill", -10, 48, 20, 12, 2, 2)

  -- Phase 4+ orbital drone anchors
  if sb.phase >= 4 then
    love.graphics.setColor(0.5 * alpha, 0.3 * alpha, 0.8 * alpha, alpha * 0.8)
    local droneAngle1 = time * 2.5
    local droneAngle2 = time * 2.5 + math.pi
    love.graphics.setLineWidth(1)
    love.graphics.line(0, 0, math.cos(droneAngle1) * 50, math.sin(droneAngle1) * 50)
    love.graphics.line(0, 0, math.cos(droneAngle2) * 50, math.sin(droneAngle2) * 50)
  end

  love.graphics.pop()

  -- Draw EMP zones (Phase 3+)
  if sb.empZones then
    for _, zone in ipairs(sb.empZones) do
      local zonePulse = 0.3 + math.abs(math.sin(time * 3 + zone.x * 0.04)) * 0.35
      -- Outer EMP field
      love.graphics.setColor(0.1, 0.4, 0.8, zonePulse * 0.2)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 15)
      -- Inner electric field
      love.graphics.setColor(0.2, 0.6, 1, zonePulse * 0.35)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      -- Core spark
      love.graphics.setColor(0.5, 0.9, 1, zonePulse * 0.7)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.3)
      -- Electric arcs (hexagonal pattern)
      love.graphics.setColor(0.4, 0.8, 1, zonePulse * 0.6)
      love.graphics.setLineWidth(1.5)
      for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 + time * 0.8
        local nextAngle = ((i + 1) / 6) * math.pi * 2 + time * 0.8
        local x1 = zone.x + math.cos(angle) * zone.radius * 0.8
        local y1 = zone.y + math.sin(angle) * zone.radius * 0.8
        local x2 = zone.x + math.cos(nextAngle) * zone.radius * 0.8
        local y2 = zone.y + math.sin(nextAngle) * zone.radius * 0.8
        love.graphics.line(x1, y1, x2, y2)
      end
      love.graphics.setLineWidth(1)
    end
  end

  -- Draw orbital drones (Phase 4+)
  if sb.drones then
    for _, drone in ipairs(sb.drones) do
      if drone.active then
        -- Drone body
        love.graphics.setColor(0.3, 0.2, 0.6, 0.9)
        love.graphics.polygon("fill",
          drone.x, drone.y - 10,
          drone.x + 10, drone.y,
          drone.x, drone.y + 10,
          drone.x - 10, drone.y)
        -- Drone core glow
        local dronePulse = 0.6 + math.sin(time * 8 + drone.angle) * 0.4
        love.graphics.setColor(0.6, 0.3, 1, dronePulse)
        love.graphics.circle("fill", drone.x, drone.y, 4)
        -- Drone shield ring
        love.graphics.setColor(0.4, 0.6, 1, 0.3)
        love.graphics.circle("line", drone.x, drone.y, 14)
      end
    end
  end

  -- Draw singularity effect (Phase 5)
  if sb.singularity and sb.singularity.active then
    local sg = sb.singularity
    local sgPulse = 0.5 + math.abs(math.sin(time * 6)) * 0.5
    -- Gravitational distortion rings
    for i = 1, 4 do
      local ringRadius = sg.radius * (0.3 + i * 0.2)
      local ringAlpha = (0.4 - i * 0.08) * sgPulse
      love.graphics.setColor(0.5, 0.2, 0.9, ringAlpha)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", sg.x, sg.y, ringRadius)
    end
    -- Core void
    love.graphics.setColor(0.1, 0.05, 0.2, 0.8)
    love.graphics.circle("fill", sg.x, sg.y, sg.radius * 0.3)
    -- Accretion disc
    love.graphics.setColor(0.7, 0.3, 1, sgPulse * 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", sg.x, sg.y, sg.radius * 0.5, time * 2, time * 2 + math.pi * 1.5)
    love.graphics.setLineWidth(1)
  end

  -- Draw gravity well indicator (Phase 5)
  if sb.gravityWellActive then
    local gwPulse = 0.2 + math.sin(time * 3) * 0.1
    love.graphics.setColor(0.4, 0.15, 0.7, gwPulse)
    love.graphics.setLineWidth(1)
    for i = 1, 3 do
      local radius = 50 + i * 40
      love.graphics.circle("line", sb.x, sb.y, radius)
    end
    love.graphics.setLineWidth(1)
  end

  -- Attack warning indicators
  local warning, progress = sentinelboss.getAttackWarning()
  if warning then
    love.graphics.setColor(0.3, 0.7, 1, 0.9)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    love.graphics.setColor(0.05, 0.1, 0.2, 0.8)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200, 10)
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200 * progress, 10)
  end

  -- Lock-on warning indicator
  if sb.lockOnCharging then
    local lockPulse = math.abs(math.sin(time * 12))
    love.graphics.setColor(1, 0.2, 0.2, lockPulse * 0.8)
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.printf("⚠ LOCK-ON DETECTED ⚠", 0, screen.HEIGHT / 2 + 20, screen.WIDTH, "center")
  end

  -- Health bar (cyber/tech style - electric blue)
  local healthPct = sb.health / sb.maxHealth
  local barWidth = 300
  local barX = screen.WIDTH/2 - barWidth/2
  local barY = 30

  -- Background with tech border
  love.graphics.setColor(0.03, 0.06, 0.12, 0.9)
  love.graphics.rectangle("fill", barX - 3, barY - 3, barWidth + 6, 18)
  love.graphics.setColor(0.15, 0.35, 0.55, 0.7)
  love.graphics.rectangle("line", barX - 3, barY - 3, barWidth + 6, 18)

  -- Health segments (5 phases visible)
  for i = 1, 5 do
    local segStart = (i - 1) / 5
    local segEnd = i / 5
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local phaseColor = coreColors[i]
      love.graphics.setColor(phaseColor[1], phaseColor[2], phaseColor[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
    end
    -- Segment divider
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 5) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  love.graphics.setColor(0.4, 0.8, 1)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. sb.phase .. "/5", barX, barY + 14, barWidth, "center")

  -- Boss name
  local bossName = sb.phase >= 5 and "THE SENTINEL - SINGULARITY" or "THE SENTINEL"
  love.graphics.setColor(0.4, 0.8, 1)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(bossName, barX, barY - 20, barWidth, "center")
end

------------------------------------------------------------------------
-- MEGALITH OF MEMORIES  (10-phase endgame raid boss)
------------------------------------------------------------------------
function M.drawMegalith()
  local mb = megalith.boss
  if not mb or not mb.active then return end

  local time = love.timer.getTime()
  local alpha = mb.fadeAlpha or 1

  -- ===============================================================
  -- ENVIRONMENT HAZARDS (drawn BEHIND the boss body)
  -- ===============================================================

  -- ACT I: RAM Corridor environment
  if mb.act == 1 then
    -- RAM sticks: tall green columns with chip textures
    for _, stick in ipairs(mb.ramSticks) do
      if stick.active then
        -- Stick body (above gap)
        love.graphics.setColor(0.05, 0.25, 0.08, 0.8)
        love.graphics.rectangle("fill", stick.x - 18, -10, 36, stick.gapY + stick.scrollY - stick.gapH/2)
        -- Stick body (below gap)
        love.graphics.rectangle("fill", stick.x - 18, stick.gapY + stick.scrollY + stick.gapH/2, 36,
          screen.HEIGHT - (stick.gapY + stick.scrollY + stick.gapH/2) + 10)
        -- Circuit traces running along stick
        local tracePulse = 0.4 + math.sin(time * 4 + stick.tracePhase) * 0.3
        love.graphics.setColor(0.1, 0.8, 0.2, tracePulse * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.line(stick.x - 8, -10, stick.x - 8, stick.gapY + stick.scrollY - stick.gapH/2)
        love.graphics.line(stick.x + 8, stick.gapY + stick.scrollY + stick.gapH/2, stick.x + 8, screen.HEIGHT + 10)
        love.graphics.setLineWidth(1)
        -- Gold chip contacts at edges
        local chipPulse = 0.5 + math.sin(stick.pulse) * 0.3
        love.graphics.setColor(0.8, 0.7, 0.2, chipPulse)
        for c = 0, 3 do
          local cy = stick.gapY + stick.scrollY - stick.gapH/2 - 20 - c * 40
          if cy > -10 and cy < screen.HEIGHT then
            love.graphics.rectangle("fill", stick.x - 14, cy, 6, 8)
            love.graphics.rectangle("fill", stick.x + 8, cy, 6, 8)
          end
        end
      end
    end

    -- Memory leak zones: green toxic puddles
    for _, zone in ipairs(mb.memoryLeakZones) do
      local lPulse = 0.3 + math.sin(time * 3 + zone.x * 0.01) * 0.25
      -- Outer glow
      love.graphics.setColor(0.1, 0.8, 0.15, lPulse * 0.25)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 12)
      -- Inner pool
      love.graphics.setColor(0.15, 0.9, 0.2, lPulse * 0.45)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      -- Core
      love.graphics.setColor(0.2, 1, 0.3, lPulse * 0.6)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.45)
      -- Label
      love.graphics.setColor(0.3, 1, 0.3, lPulse)
      love.graphics.setFont(love.graphics.newFont(8))
      love.graphics.printf("MEM LEAK", zone.x - 30, zone.y - 5, 60, "center")
    end

    -- Data surge beam: horizontal beam sweeping vertically
    if mb.dataSurgeActive then
      local surgeY = screen.HEIGHT / 2 + math.sin(mb.dataSurgeAngle) * (screen.HEIGHT / 3)
      local surgePulse = 0.6 + math.sin(time * 12) * 0.4
      -- Wide glow
      love.graphics.setColor(0.2, 0.9, 0.3, 0.15 * surgePulse)
      love.graphics.rectangle("fill", 0, surgeY - 25, screen.WIDTH, 50)
      -- Core beam
      love.graphics.setColor(0.3, 1, 0.4, 0.7 * surgePulse)
      love.graphics.rectangle("fill", 0, surgeY - 8, screen.WIDTH, 16)
      -- Bright center line
      love.graphics.setColor(0.7, 1, 0.8, surgePulse)
      love.graphics.rectangle("fill", 0, surgeY - 2, screen.WIDTH, 4)
    end

    -- Puzzle gates (colored gates at bottom)
    if mb.puzzleActive then
      -- Sequence display (top of screen)
      love.graphics.setFont(love.graphics.newFont(12))
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.printf("MEMORY SEQUENCE:", screen.WIDTH/2 - 120, 55, 240, "center")

      local seqColors = {red = {1,0.2,0.2}, green = {0.2,1,0.2}, blue = {0.2,0.4,1}, gold = {1,0.85,0.2}}
      for i, col in ipairs(mb.puzzleSequence) do
        local sc = seqColors[col] or {1,1,1}
        local bright = (i < mb.puzzleIndex) and 0.3 or 1  -- dim completed entries
        if i == mb.puzzleIndex then bright = 0.6 + math.sin(time * 8) * 0.4 end
        love.graphics.setColor(sc[1] * bright, sc[2] * bright, sc[3] * bright, 0.9)
        love.graphics.circle("fill", screen.WIDTH/2 - 30 + (i - 1) * 30, 80, 8)
        if i < mb.puzzleIndex then
          love.graphics.setColor(1, 1, 1, 0.7)
          love.graphics.printf("✓", screen.WIDTH/2 - 38 + (i - 1) * 30, 72, 16, "center")
        end
      end

      -- Gate indicators at bottom
      for _, gate in ipairs(mb.puzzleGates) do
        if gate.active then
          local gc = seqColors[gate.color] or {1,1,1}
          -- Gate glow
          love.graphics.setColor(gc[1], gc[2], gc[3], 0.2 + math.sin(time * 4) * 0.1)
          love.graphics.rectangle("fill", gate.x - gate.width/2 - 5, gate.y - gate.height/2 - 5,
            gate.width + 10, gate.height + 10)
          -- Gate body
          love.graphics.setColor(gc[1], gc[2], gc[3], 0.7)
          love.graphics.rectangle("fill", gate.x - gate.width/2, gate.y - gate.height/2, gate.width, gate.height)
          -- Gate border
          love.graphics.setColor(gc[1] * 1.3, gc[2] * 1.3, gc[3] * 1.3, 0.9)
          love.graphics.rectangle("line", gate.x - gate.width/2, gate.y - gate.height/2, gate.width, gate.height)
        end
      end

      -- Timer
      love.graphics.setColor(1, 0.8, 0.2, 0.8)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf(string.format("%.1fs", mb.puzzleTimer), screen.WIDTH/2 - 30, 90, 60, "center")
    end
  end

  -- ACT II: Sector Gauntlet environment
  if mb.act == 2 then
    -- Bad sector zones: purple/magenta corruption
    for _, zone in ipairs(mb.badSectorZones) do
      local bPulse = 0.3 + math.sin(time * 2.5 + zone.x * 0.02) * 0.25
      love.graphics.setColor(0.6, 0.1, 0.7, bPulse * 0.25)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 10)
      love.graphics.setColor(0.8, 0.15, 0.9, bPulse * 0.45)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      love.graphics.setColor(0.9, 0.3, 1, bPulse * 0.6)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.4)
      love.graphics.setColor(0.9, 0.3, 1, bPulse * 0.8)
      love.graphics.setFont(love.graphics.newFont(8))
      love.graphics.printf("BAD SECTOR", zone.x - 35, zone.y - 5, 70, "center")
    end

    -- Seek arm: tall vertical bar sweeping horizontally
    if mb.seekArmActive then
      local armPulse = 0.6 + math.sin(time * 10) * 0.3
      -- Shadow
      love.graphics.setColor(0.1, 0.05, 0.15, 0.4)
      love.graphics.rectangle("fill", mb.seekArmX - 20, 0, 40, screen.HEIGHT)
      -- Arm body
      love.graphics.setColor(0.5, 0.15, 0.6, 0.7 * armPulse)
      love.graphics.rectangle("fill", mb.seekArmX - 15, 0, 30, screen.HEIGHT)
      -- Core line
      love.graphics.setColor(0.9, 0.3, 1, armPulse)
      love.graphics.rectangle("fill", mb.seekArmX - 3, 0, 6, screen.HEIGHT)
      -- Danger label
      love.graphics.setColor(1, 0.3, 0.3, armPulse)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf("SEEK ARM", mb.seekArmX - 40, screen.HEIGHT/2, 80, "center")
    end

    -- Boulder sweep: horizontal bar sweeping vertically
    if mb.boulderSweepActive then
      local bsPulse = 0.6 + math.sin(time * 8) * 0.3
      love.graphics.setColor(0.15, 0.05, 0.1, 0.4)
      love.graphics.rectangle("fill", 0, mb.boulderSweepY - 20, screen.WIDTH, 40)
      love.graphics.setColor(0.6, 0.15, 0.15, 0.7 * bsPulse)
      love.graphics.rectangle("fill", 0, mb.boulderSweepY - 10, screen.WIDTH, 20)
      love.graphics.setColor(1, 0.3, 0.2, bsPulse)
      love.graphics.rectangle("fill", 0, mb.boulderSweepY - 2, screen.WIDTH, 4)
    end

    -- Sector puzzle rings (rotating colored segments)
    if mb.sectorPuzzleActive then
      local cx, cy = screen.WIDTH / 2, screen.HEIGHT / 2 + 50
      for i, ring in ipairs(mb.sectorPuzzleRings) do
        local ringColors = {red = {1,0.2,0.2}, blue = {0.2,0.4,1}, green = {0.2,1,0.2}, gold = {1,0.85,0.2}}
        local rc = ringColors[ring.color] or {1,1,1}
        local segAlpha = ring.hit and 0.2 or 0.7
        local arcAngle = ring.angle
        local arcSize = math.pi / 3

        love.graphics.setColor(rc[1], rc[2], rc[3], segAlpha)
        love.graphics.setLineWidth(6)
        love.graphics.arc("line", "open", cx, cy, ring.radius, arcAngle, arcAngle + arcSize)
        love.graphics.setLineWidth(1)

        if not ring.hit then
          -- Glow on current target
          if i == mb.sectorPuzzleIndex then
            local tPulse = 0.4 + math.sin(time * 6) * 0.3
            love.graphics.setColor(rc[1], rc[2], rc[3], tPulse)
            love.graphics.setLineWidth(10)
            love.graphics.arc("line", "open", cx, cy, ring.radius, arcAngle, arcAngle + arcSize)
            love.graphics.setLineWidth(1)
          end
        else
          -- Check mark on hit segments
          local midAngle = arcAngle + arcSize / 2
          local mx = cx + math.cos(midAngle) * ring.radius
          local my = cy + math.sin(midAngle) * ring.radius
          love.graphics.setColor(1, 1, 1, 0.7)
          love.graphics.setFont(love.graphics.newFont(12))
          love.graphics.print("✓", mx - 5, my - 6)
        end
      end
      -- Puzzle label
      love.graphics.setColor(1, 0.8, 0.3, 0.9)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf("SECTOR ALIGNMENT", cx - 60, cy - 170, 120, "center")
    end
  end

  -- ACT III: The Core environment
  if mb.act == 3 then
    local cx, cy = screen.WIDTH / 2, screen.HEIGHT / 2

    -- Spinning platters (concentric rings with gaps)
    for _, platter in ipairs(mb.platters) do
      local pAlpha = 0.5
      -- Draw the platter ring except for the gap
      local segments = 32
      local segAngle = (math.pi * 2) / segments
      for s = 0, segments - 1 do
        local startA = s * segAngle + platter.angle
        local endA = startA + segAngle
        -- Check if this segment is in the gap
        local midA = (startA + endA) / 2
        local relA = (midA - platter.gapAngle) % (math.pi * 2)
        if relA > platter.gapSize then
          -- Not in gap: draw segment
          love.graphics.setColor(0.25, 0.22, 0.3, pAlpha)
          love.graphics.setLineWidth(platter.thickness)
          love.graphics.arc("line", "open", cx, cy, platter.radius, startA, endA)
        else
          -- In gap: draw faint indicator
          love.graphics.setColor(0.1, 0.3, 0.1, 0.2)
          love.graphics.setLineWidth(2)
          love.graphics.arc("line", "open", cx, cy, platter.radius, startA, endA)
        end
      end
      love.graphics.setLineWidth(1)
    end

    -- Spindle motor center
    love.graphics.setColor(0.15, 0.12, 0.2, 0.8)
    love.graphics.circle("fill", cx, cy, mb.spindleRadius)
    love.graphics.setColor(0.3, 0.25, 0.4, 0.6)
    love.graphics.circle("line", cx, cy, mb.spindleRadius)

    -- Spindle lasers: rotating death beams from center
    if mb.spindleLaserActive then
      for i = 0, mb.spindleLaserCount - 1 do
        local lAngle = mb.spindleLaserAngle + i * (math.pi * 2 / mb.spindleLaserCount)
        local lLen = 400
        local lx2 = cx + math.cos(lAngle) * lLen
        local ly2 = cy + math.sin(lAngle) * lLen
        -- Laser glow
        local lPulse = 0.5 + math.sin(time * 10 + i) * 0.3
        love.graphics.setColor(0.9, 0.2, 0.9, 0.15 * lPulse)
        love.graphics.setLineWidth(18)
        love.graphics.line(cx, cy, lx2, ly2)
        -- Laser core
        love.graphics.setColor(1, 0.4, 1, 0.7 * lPulse)
        love.graphics.setLineWidth(4)
        love.graphics.line(cx, cy, lx2, ly2)
        -- Laser bright center
        love.graphics.setColor(1, 0.8, 1, lPulse)
        love.graphics.setLineWidth(1)
        love.graphics.line(cx, cy, lx2, ly2)
      end
      love.graphics.setLineWidth(1)
    end

    -- Actuator arms: swinging arms from screen edges
    for _, arm in ipairs(mb.actuatorArms) do
      if arm.active then
        local endX = arm.pivotX + math.cos(arm.angle) * arm.length
        local endY = arm.pivotY + math.sin(arm.angle) * arm.length
        -- Arm shadow
        love.graphics.setColor(0.1, 0.05, 0.1, 0.4)
        love.graphics.setLineWidth(14)
        love.graphics.line(arm.pivotX, arm.pivotY, endX, endY)
        -- Arm body
        love.graphics.setColor(0.4, 0.3, 0.35, 0.8)
        love.graphics.setLineWidth(8)
        love.graphics.line(arm.pivotX, arm.pivotY, endX, endY)
        -- Arm tip
        love.graphics.setColor(0.8, 0.4, 0.3, 0.9)
        love.graphics.circle("fill", endX, endY, 6)
        -- Pivot joint
        love.graphics.setColor(0.5, 0.35, 0.3, 0.9)
        love.graphics.circle("fill", arm.pivotX, arm.pivotY, 8)
        love.graphics.setLineWidth(1)
      end
    end

    -- Falling debris columns
    if mb.debrisActive then
      for _, col in ipairs(mb.debrisColumns) do
        if col.active then
          -- Warning shadow on ground
          love.graphics.setColor(1, 0.2, 0.1, 0.15)
          love.graphics.rectangle("fill", col.x - col.width/2, 0, col.width, screen.HEIGHT)
          -- Debris chunk
          love.graphics.setColor(0.4, 0.3, 0.25, 0.9)
          love.graphics.rectangle("fill", col.x - col.width/2, col.y - 20, col.width, 40)
          love.graphics.setColor(0.6, 0.4, 0.3, 0.7)
          love.graphics.rectangle("line", col.x - col.width/2, col.y - 20, col.width, 40)
          -- Sparks trailing
          local sparkPulse = math.sin(time * 15 + col.x) * 0.5 + 0.5
          love.graphics.setColor(1, 0.6, 0.2, sparkPulse * 0.7)
          love.graphics.circle("fill", col.x + math.sin(time * 20) * 5, col.y + 22, 3)
        end
      end
    end

    -- Magnetic pulse expanding ring
    if mb.magneticPulseActive then
      local mpAlpha = math.max(0, 1 - mb.magneticPulseRadius / screen.WIDTH)
      -- Outer ring glow
      love.graphics.setColor(0.3, 0.5, 1, mpAlpha * 0.2)
      love.graphics.setLineWidth(20)
      love.graphics.circle("line", mb.x, mb.y, mb.magneticPulseRadius)
      -- Core ring
      love.graphics.setColor(0.4, 0.6, 1, mpAlpha * 0.6)
      love.graphics.setLineWidth(5)
      love.graphics.circle("line", mb.x, mb.y, mb.magneticPulseRadius)
      -- Inner edge
      love.graphics.setColor(0.7, 0.85, 1, mpAlpha * 0.9)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", mb.x, mb.y, mb.magneticPulseRadius)
      love.graphics.setLineWidth(1)
    end

    -- Gravity well indicator
    if mb.gravityActive then
      local gwPulse = 0.3 + math.sin(time * 4) * 0.2
      love.graphics.setColor(0.5, 0.2, 0.8, gwPulse)
      love.graphics.setLineWidth(1)
      for i = 1, 4 do
        love.graphics.circle("line", mb.x, mb.y, 40 + i * 35)
      end
    end

    -- Thermal event safe zone indicator (phase 10)
    if mb.thermalCharging and mb.thermalSafeZone then
      local tPulse = 0.4 + math.sin(time * 6) * 0.3
      -- Danger overlay
      love.graphics.setColor(1, 0.1, 0.05, 0.08 + tPulse * 0.06)
      love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
      -- Safe zone highlight
      love.graphics.setColor(0.1, 1, 0.3, tPulse * 0.35)
      love.graphics.circle("fill", mb.thermalSafeZone.x, mb.thermalSafeZone.y, 60)
      love.graphics.setColor(0.2, 1, 0.4, tPulse * 0.7)
      love.graphics.circle("line", mb.thermalSafeZone.x, mb.thermalSafeZone.y, 60)
      love.graphics.setColor(1, 1, 1, tPulse)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf("SAFE", mb.thermalSafeZone.x - 20, mb.thermalSafeZone.y - 6, 40, "center")
    end

    -- Core shield (glowing barrier around boss)
    if mb.coreShielded then
      local shPulse = 0.4 + math.sin(time * 3) * 0.2
      local shieldPct = mb.coreShieldHP / mb.coreShieldMaxHP
      -- Shield glow
      love.graphics.setColor(0.3, 0.6, 1, shPulse * shieldPct * 0.3)
      love.graphics.circle("fill", mb.x, mb.y, mb.width/2 + 30)
      -- Shield ring
      love.graphics.setColor(0.4, 0.7, 1, shPulse * shieldPct * 0.7)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", mb.x, mb.y, mb.width/2 + 25)
      love.graphics.setLineWidth(1)
      -- Shield HP indicator
      love.graphics.setColor(0.5, 0.8, 1, 0.8)
      love.graphics.setFont(love.graphics.newFont(9))
      love.graphics.printf(string.format("SHIELD %d%%", math.floor(shieldPct * 100)),
        mb.x - 40, mb.y + mb.height/2 + 30, 80, "center")
    end
  end

  -- ===============================================================
  -- BOSS BODY
  -- ===============================================================
  love.graphics.push()
  love.graphics.translate(mb.x, mb.y)

  -- Phase-based act color palette
  local actColors = {
    -- Act I: RAM – electric green / circuit board
    {{0.05, 0.2, 0.08}, {0.08, 0.28, 0.1}, {0.12, 0.35, 0.12}},
    -- Act II: Sectors – deep purple / magenta
    {{0.15, 0.05, 0.2}, {0.2, 0.08, 0.28}, {0.28, 0.1, 0.35}},
    -- Act III: Core – dark steel / crimson
    {{0.12, 0.1, 0.15}, {0.18, 0.12, 0.12}, {0.25, 0.08, 0.08}},
  }
  local palette = actColors[mb.act] or actColors[1]
  local phaseInAct = ((mb.phase - 1) % 3) + 1
  local baseColor = palette[math.min(phaseInAct, #palette)]

  -- Main body
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  love.graphics.rectangle("fill", -mb.width/2, -mb.height/2, mb.width, mb.height)

  -- Armored plating layers
  love.graphics.setColor(0.08 * alpha, 0.06 * alpha, 0.06 * alpha, alpha)
  love.graphics.rectangle("fill", -70, -50, 140, 30)
  love.graphics.rectangle("fill", -80, 10, 160, 40)

  -- Act-specific body details
  if mb.act == 1 then
    -- RAM chip pins along edges
    love.graphics.setColor(0.7 * alpha, 0.6 * alpha, 0.15 * alpha, alpha)
    for p = 0, 7 do
      local px = -65 + p * 18
      love.graphics.rectangle("fill", px, -mb.height/2 - 6, 8, 6)
      love.graphics.rectangle("fill", px, mb.height/2, 8, 6)
    end
    -- PCB traces
    local tracePulse = 0.4 + math.sin(time * 5) * 0.3
    love.graphics.setColor(0.1 * alpha, 0.7 * alpha * tracePulse, 0.15 * alpha, alpha * 0.6)
    love.graphics.line(-50, -20, -10, -20)
    love.graphics.line(-10, -20, -10, 20)
    love.graphics.line(-10, 20, 30, 20)
    love.graphics.line(30, -30, 50, -30)
    love.graphics.line(50, -30, 50, 10)
  elseif mb.act == 2 then
    -- Sector tracks (concentric arcs on body)
    for i = 1, 3 do
      local r = 20 + i * 15
      love.graphics.setColor(0.5 * alpha, 0.15 * alpha, 0.6 * alpha, 0.5 * alpha)
      love.graphics.arc("line", "open", 0, 0, r, -math.pi/3, math.pi/3)
    end
    -- Read head indicator
    love.graphics.setColor(0.8 * alpha, 0.3 * alpha, 0.9 * alpha, 0.8 * alpha)
    love.graphics.polygon("fill", -5, 55, 5, 55, 0, 65)
  else
    -- Core: spinning inner mechanism
    local coreSpin = time * 2
    love.graphics.setColor(0.3 * alpha, 0.08 * alpha, 0.08 * alpha, alpha * 0.7)
    for i = 0, 2 do
      local a = coreSpin + i * (math.pi * 2 / 3)
      love.graphics.line(0, 0, math.cos(a) * 50, math.sin(a) * 50)
    end
    -- Glowing spindle hub
    local hubPulse = 0.5 + math.sin(time * 4) * 0.3
    love.graphics.setColor(0.8 * alpha * hubPulse, 0.15 * alpha, 0.15 * alpha, alpha)
    love.graphics.circle("fill", 0, 0, 15)
  end

  -- Central core eye
  local coreGlow = {
    {0.2, 0.9, 0.3},   -- Act I: Green
    {0.7, 0.2, 0.9},   -- Act II: Purple
    {1.0, 0.3, 0.2},   -- Act III: Red
  }
  local coreC = coreGlow[mb.act] or coreGlow[1]

  local pulse = 1
  if mb.phase >= 7 then
    pulse = 0.6 + math.abs(math.sin(time * 7)) * 0.4
  end
  if mb.enraged then
    pulse = 0.4 + math.abs(math.sin(time * 12)) * 0.6
  end

  love.graphics.setColor(coreC[1] * pulse * alpha, coreC[2] * pulse * alpha, coreC[3] * pulse * alpha, alpha)
  love.graphics.circle("fill", 0, -5, 30)
  -- Inner glow
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, 0.5 * alpha)
  love.graphics.circle("fill", 0, -5, 12)

  -- Phase transition / enrage outer glow
  if mb.phaseTransitioning or mb.enraged then
    local glowPulse = math.abs(math.sin(time * 8))
    love.graphics.setColor(coreC[1], coreC[2], coreC[3], glowPulse * 0.4 * alpha)
    love.graphics.circle("fill", 0, -5, 60)
  end

  -- Stagger visual (stunned state)
  if mb.puzzleStagger then
    local stPulse = math.abs(math.sin(time * 15))
    love.graphics.setColor(1, 1, 0.5, stPulse * 0.5)
    love.graphics.circle("line", 0, 0, mb.width/2 + 10)
    love.graphics.setColor(1, 1, 0.3, stPulse * 0.3)
    love.graphics.circle("line", 0, 0, mb.width/2 + 20)
    -- "STAGGERED" text
    love.graphics.setColor(1, 1, 0.5, stPulse)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("STAGGERED", -60, -mb.height/2 - 25, 120, "center")
  end

  love.graphics.pop()

  -- ===============================================================
  -- ATTACK WARNING
  -- ===============================================================
  local warning, progress = megalith.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.25, 0.2, 0.85)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    -- Warning bar
    love.graphics.setColor(0.25, 0.08, 0.08, 0.8)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200, 10)
    love.graphics.setColor(1, 0.35, 0.15)
    love.graphics.rectangle("fill", screen.WIDTH/2 - 100, screen.HEIGHT/2 - 25, 200 * progress, 10)
  end

  -- Head-crash telegraph
  if mb.headCrashPhase == "telegraphing" then
    local hcPulse = math.abs(math.sin(time * 10))
    love.graphics.setColor(1, 0.15, 0.1, hcPulse * 0.4)
    love.graphics.circle("fill", mb.headCrashTargetX, mb.headCrashTargetY, 40)
    love.graphics.setColor(1, 0.3, 0.2, hcPulse * 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", mb.headCrashTargetX, mb.headCrashTargetY, 40)
    -- Crosshair
    love.graphics.line(mb.headCrashTargetX - 20, mb.headCrashTargetY, mb.headCrashTargetX + 20, mb.headCrashTargetY)
    love.graphics.line(mb.headCrashTargetX, mb.headCrashTargetY - 20, mb.headCrashTargetX, mb.headCrashTargetY + 20)
    love.graphics.setLineWidth(1)
  end

  -- ===============================================================
  -- HEALTH BAR (10-phase segmented, Elden Ring style)
  -- ===============================================================
  local healthPct = mb.health / mb.maxHealth
  local barWidth = 340
  local barX = screen.WIDTH/2 - barWidth/2
  local barY = 30

  -- Background
  love.graphics.setColor(0.08, 0.06, 0.06, 0.9)
  love.graphics.rectangle("fill", barX - 3, barY - 3, barWidth + 6, 18)
  love.graphics.setColor(0.25, 0.15, 0.1, 0.6)
  love.graphics.rectangle("line", barX - 3, barY - 3, barWidth + 6, 18)

  -- 10 phase-colored segments
  local segColors = {
    {0.15, 0.7, 0.2},   -- Phase 1: Green
    {0.2,  0.8, 0.3},   -- Phase 2: Bright green
    {0.3,  0.9, 0.4},   -- Phase 3: Light green
    {0.5,  0.15, 0.6},  -- Phase 4: Purple
    {0.6,  0.2,  0.8},  -- Phase 5: Violet
    {0.7,  0.25, 0.9},  -- Phase 6: Magenta
    {0.7,  0.15, 0.1},  -- Phase 7: Dark red
    {0.85, 0.2,  0.15}, -- Phase 8: Red
    {1.0,  0.3,  0.15}, -- Phase 9: Orange-red
    {1.0,  0.5,  0.1},  -- Phase 10: Molten gold
  }

  for i = 1, 10 do
    local segStart = (i - 1) / 10
    local segEnd = i / 10
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local sc = segColors[i]
      love.graphics.setColor(sc[1], sc[2], sc[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 10) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  love.graphics.setColor(1, 0.85, 0.4)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. mb.phase .. "/10", barX, barY + 14, barWidth, "center")

  -- Boss name
  love.graphics.setColor(1, 0.75, 0.3)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(mb.name, barX, barY - 20, barWidth, "center")

  -- Act label (right side of health bar)
  local actNames = {"RAM CORRIDOR", "SECTOR GAUNTLET", "THE CORE"}
  love.graphics.setColor(0.7, 0.6, 0.5, 0.7)
  love.graphics.setFont(love.graphics.newFont(9))
  love.graphics.printf(actNames[mb.act] or "", barX + barWidth + 8, barY, 120, "left")
end

------------------------------------------------------------------------
-- DISTANT DYNAMO  (8-phase endgame raid boss — Power Supply Overlord)
------------------------------------------------------------------------
function M.drawDynamoBoss()
  local db = dynamoboss.boss
  if not db or not db.active then return end

  local time = love.timer.getTime()
  local alpha = db.fadeAlpha or 1

  -- ==================== CABLE OBSTACLES ====================
  for _, cable in ipairs(db.cables) do
    if cable.cableType == "horizontal" then
      local leftWidth = cable.gapX - cable.gapWidth / 2
      local rightStart = cable.gapX + cable.gapWidth / 2
      local rightWidth = screen.WIDTH - rightStart
      local pulse = 0.7 + math.sin(time * 4 + cable.y * 0.1) * 0.3

      if leftWidth > 0 then
        love.graphics.setColor(0.9 * pulse, 0.45 * pulse, 0.1, 0.9)
        love.graphics.rectangle("fill", 0, cable.y - cable.height / 2, leftWidth, cable.height)
        love.graphics.setColor(1, 0.7, 0.3, 0.4 * pulse)
        love.graphics.rectangle("fill", 0, cable.y - cable.height / 2, leftWidth, 3)
      end
      if rightWidth > 0 then
        love.graphics.setColor(0.9 * pulse, 0.45 * pulse, 0.1, 0.9)
        love.graphics.rectangle("fill", rightStart, cable.y - cable.height / 2, rightWidth, cable.height)
        love.graphics.setColor(1, 0.7, 0.3, 0.4 * pulse)
        love.graphics.rectangle("fill", rightStart, cable.y - cable.height / 2, rightWidth, 3)
      end
      love.graphics.setColor(0.2, 0.8, 0.2, 0.15 + math.sin(time * 6) * 0.1)
      love.graphics.rectangle("fill", cable.gapX - cable.gapWidth / 2, cable.y - 20, cable.gapWidth, 40)

    elseif cable.cableType == "swinging" then
      local pulse = 0.6 + math.sin(time * 5 + cable.swingAngle) * 0.4
      love.graphics.setColor(0.7, 0.35, 0.05, 0.8)
      love.graphics.setLineWidth(cable.thickness)
      love.graphics.line(cable.anchorX, cable.anchorY, cable.tipX, cable.tipY)
      love.graphics.setColor(0.5, 0.25, 0.05)
      love.graphics.circle("fill", cable.anchorX, cable.anchorY, 8)
      love.graphics.setColor(1 * pulse, 0.5 * pulse, 0.1 * pulse)
      love.graphics.circle("fill", cable.tipX, cable.tipY, 18)
      love.graphics.setColor(1, 0.8, 0.2, pulse * 0.7)
      love.graphics.circle("fill", cable.tipX, cable.tipY, 10)
      love.graphics.setLineWidth(1)

    elseif cable.cableType == "sparking" then
      local pulse = 0.5 + math.sin(time * 8 + cable.x * 0.05) * 0.5
      love.graphics.setColor(0.9, 0.5, 0.1, 0.85)
      love.graphics.rectangle("fill", cable.x - cable.width / 2, cable.y - cable.height / 2, cable.width, cable.height)
      love.graphics.setColor(1, 0.9, 0.3, pulse)
      for i = 1, 3 do
        local sparkX = cable.x + (math.random() - 0.5) * cable.width
        local sparkY = cable.y + (math.random() - 0.5) * cable.height * 3
        love.graphics.circle("fill", sparkX, sparkY, 3 + math.random() * 3)
      end

    elseif cable.cableType == "crushing" then
      if cable.slamPhase == "warning" then
        local warnPulse = math.abs(math.sin(time * 10))
        love.graphics.setColor(1, 0.5, 0, warnPulse * 0.4)
        love.graphics.rectangle("fill", cable.x - cable.width / 2, 0, cable.width, screen.HEIGHT)
        love.graphics.setColor(1, 0.6, 0.1, warnPulse * 0.8)
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.printf("!!", cable.x - 20, cable.targetY - 20, 40, "center")
      else
        love.graphics.setColor(0.8, 0.35, 0.05)
        love.graphics.rectangle("fill", cable.x - cable.width / 2, cable.y - cable.height / 2, cable.width, cable.height)
        love.graphics.setColor(0.6, 0.3, 0.05)
        love.graphics.setLineWidth(4)
        love.graphics.line(cable.x, 0, cable.x, cable.y - cable.height / 2)
        love.graphics.setLineWidth(1)
        if cable.slamPhase == "grounded" then
          local impactPulse = math.abs(math.sin(time * 12))
          love.graphics.setColor(1, 0.8, 0.2, impactPulse)
          love.graphics.circle("fill", cable.x, cable.y + cable.height / 2, 15 + impactPulse * 10)
        end
      end
    end
  end

  -- ==================== CAPACITOR ZONES (Phase 3+) ====================
  if db.capacitorZones then
    for _, zone in ipairs(db.capacitorZones) do
      local zonePulse = 0.3 + math.abs(math.sin(time * 3.5 + zone.pulsePhase)) * 0.4
      love.graphics.setColor(1, 0.6, 0.1, zonePulse * 0.25)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius + 15)
      love.graphics.setColor(1, 0.45, 0.05, zonePulse * 0.45)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius)
      love.graphics.setColor(1, 0.8, 0.2, zonePulse * 0.7)
      love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.4)
      love.graphics.setColor(1, 0.9, 0.4, zonePulse * 0.6)
      love.graphics.setLineWidth(2)
      for i = 0, 3 do
        local arcAngle = (i / 4) * math.pi * 2 + zone.sparkAngle
        local x1 = zone.x + math.cos(arcAngle) * zone.radius * 0.5
        local y1 = zone.y + math.sin(arcAngle) * zone.radius * 0.5
        local x2 = zone.x + math.cos(arcAngle) * zone.radius
        local y2 = zone.y + math.sin(arcAngle) * zone.radius
        love.graphics.line(x1, y1, x2, y2)
      end
      love.graphics.setLineWidth(1)
    end
  end

  -- ==================== INDUCTOR BLADES (Phase 4+) ====================
  for _, blade in ipairs(db.inductorBlades) do
    love.graphics.push()
    love.graphics.translate(blade.x, blade.y)
    love.graphics.rotate(blade.angle)
    love.graphics.setColor(0.7, 0.35, 0.05, 0.9)
    for i = 0, 3 do
      local bladeAngle = (i / 4) * math.pi * 2
      local bx = math.cos(bladeAngle) * blade.radius
      local by = math.sin(bladeAngle) * blade.radius
      love.graphics.polygon("fill", 0, 0, bx - 5, by, bx + 5, by)
    end
    love.graphics.setColor(1, 0.6, 0.15)
    love.graphics.circle("fill", 0, 0, 10)
    love.graphics.setColor(1, 0.9, 0.4, 0.6)
    love.graphics.circle("fill", 0, 0, 5)
    love.graphics.pop()

    local bladePulse = 0.3 + math.abs(math.sin(time * 6 + blade.angle)) * 0.3
    love.graphics.setColor(1, 0.4, 0.1, bladePulse * 0.3)
    love.graphics.circle("line", blade.x, blade.y, blade.radius + 5)
  end

  -- ==================== ARC FLASH WAVES (Phase 5+) ====================
  for _, wave in ipairs(db.arcFlashWaves) do
    local wavePulse = 0.7 + math.sin(wave.pulsePhase) * 0.3
    love.graphics.setColor(1 * wavePulse, 0.5 * wavePulse, 0.05, 0.8)
    love.graphics.rectangle("fill", wave.x, wave.y - wave.height / 2, wave.width, wave.height)
    love.graphics.setColor(1, 0.9, 0.4, wavePulse)
    love.graphics.rectangle("fill", wave.x, wave.y - wave.height / 2, wave.width, 4)
    love.graphics.setColor(1, 0.4, 0.05, 0.3 * wavePulse)
    love.graphics.rectangle("fill", wave.x, wave.y - wave.height, wave.width, wave.height)
  end

  -- ==================== SHORT CIRCUIT NODES (Phase 6+) ====================
  if db.shortCircuitNodes then
    for j, node in ipairs(db.shortCircuitNodes) do
      if node.connectedTo and db.shortCircuitNodes[node.connectedTo] then
        local target = db.shortCircuitNodes[node.connectedTo]
        local nodePulse = 0.4 + math.abs(math.sin(time * 4 + j)) * 0.4
        love.graphics.setColor(1, 0.7, 0.2, nodePulse * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(node.x, node.y, target.x, target.y)
        love.graphics.setLineWidth(1)
      end
    end
    for _, node in ipairs(db.shortCircuitNodes) do
      local nodePulse = 0.5 + math.abs(math.sin(time * 5 + node.pulsePhase)) * 0.5
      love.graphics.setColor(1, 0.6, 0.1, nodePulse * 0.3)
      love.graphics.circle("fill", node.x, node.y, node.radius + 10)
      love.graphics.setColor(1, 0.5, 0.05, nodePulse * 0.8)
      love.graphics.circle("fill", node.x, node.y, node.radius)
      love.graphics.setColor(1, 0.95, 0.6, nodePulse)
      love.graphics.circle("fill", node.x, node.y, 5)
    end
  end

  -- ==================== OVERLOAD PULSES (Phase 7+) ====================
  for _, pulse in ipairs(db.overloadPulses) do
    local pulseFade = pulse.lifetime / 3
    love.graphics.setColor(1, 0.5, 0.05, pulseFade * 0.7)
    love.graphics.setLineWidth(pulse.thickness)
    love.graphics.circle("line", pulse.x, pulse.y, pulse.radius)
    love.graphics.setColor(1, 0.8, 0.3, pulseFade * 0.2)
    love.graphics.setLineWidth(pulse.thickness * 2)
    love.graphics.circle("line", pulse.x, pulse.y, pulse.radius)
    love.graphics.setLineWidth(1)
  end

  -- Overload charge warning
  if db.overloadCharging then
    local chargePulse = math.abs(math.sin(time * 12))
    love.graphics.setColor(1, 0.4, 0, chargePulse * 0.3)
    love.graphics.circle("fill", db.x, db.y, 80 + chargePulse * 40)
    love.graphics.setColor(1, 0.7, 0.2, chargePulse * 0.5)
    love.graphics.circle("fill", db.x, db.y, 40 + chargePulse * 20)
  end

  -- ==================== PUZZLE: CIRCUIT BREAKERS ====================
  if db.puzzleActive and not db.vulnerableFromPuzzle then
    for _, breaker in ipairs(db.circuitBreakers) do
      if breaker.solved then
        love.graphics.setColor(0.2, 0.9, 0.3, 0.6)
        love.graphics.circle("fill", breaker.x, breaker.y, breaker.radius * 0.8)
        love.graphics.setColor(0.3, 1, 0.4, 0.8)
        love.graphics.circle("line", breaker.x, breaker.y, breaker.radius * 0.8)
      elseif breaker.active then
        local breakerPulse = 0.6 + math.abs(math.sin(time * 6 + breaker.pulsePhase)) * 0.4
        love.graphics.setColor(1, 0.6, 0.1, breakerPulse * 0.4)
        love.graphics.circle("fill", breaker.x, breaker.y, breaker.radius + 10)
        love.graphics.setColor(1, 0.7, 0.2, breakerPulse * 0.8)
        love.graphics.circle("fill", breaker.x, breaker.y, breaker.radius)
        love.graphics.setColor(0.1, 0.05, 0)
        love.graphics.setLineWidth(3)
        love.graphics.line(breaker.x - 8, breaker.y + 5, breaker.x, breaker.y - 10)
        love.graphics.line(breaker.x, breaker.y - 10, breaker.x + 8, breaker.y + 5)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, breakerPulse)
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.printf(tostring(breaker.index), breaker.x - 10, breaker.y - 25, 20, "center")
        love.graphics.setColor(1, 0.8, 0.3, breakerPulse * math.abs(math.sin(time * 4)))
        love.graphics.polygon("fill",
          breaker.x, breaker.y + breaker.radius + 15,
          breaker.x - 8, breaker.y + breaker.radius + 25,
          breaker.x + 8, breaker.y + breaker.radius + 25)
      else
        love.graphics.setColor(0.5, 0.3, 0.1, 0.3)
        love.graphics.circle("fill", breaker.x, breaker.y, breaker.radius * 0.7)
        love.graphics.setColor(0.6, 0.35, 0.15, 0.4)
        love.graphics.circle("line", breaker.x, breaker.y, breaker.radius * 0.7)
      end
    end
    love.graphics.setColor(1, 0.7, 0.2, 0.9)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("CIRCUIT BREAKER: " .. db.breakersSolved .. "/" .. #db.circuitBreakers,
      0, screen.HEIGHT - 100, screen.WIDTH, "center")
  end

  -- Vulnerability window glow
  if db.vulnerableFromPuzzle then
    local vulnPulse = 0.5 + math.abs(math.sin(time * 6)) * 0.5
    love.graphics.setColor(0.2, 1, 0.3, vulnPulse * 0.15)
    love.graphics.circle("fill", db.x, db.y, 120)
  end

  -- ==================== MAGNET PULL INDICATOR (Phase 5+) ====================
  if db.magnetActive then
    local wellPulse = 0.4 + math.abs(math.sin(time * 5)) * 0.4
    love.graphics.setColor(0.9, 0.5, 0.1, wellPulse * 0.25)
    love.graphics.circle("line", db.x, db.y, 160)
    love.graphics.circle("line", db.x, db.y, 110)
    love.graphics.circle("line", db.x, db.y, 60)
    love.graphics.setColor(1, 0.6, 0.2, wellPulse * 0.6)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.printf("MAGNETIC PULL", db.x - 50, db.y + 170, 100, "center")
  end

  -- ==================== MELTDOWN SPARKS (Phase 8) ====================
  if db.enraged then
    for _, spark in ipairs(db.meltdownSparks) do
      local sparkAlpha = spark.lifetime / 1.0
      love.graphics.setColor(1, 0.6 + math.random() * 0.3, 0.1, sparkAlpha)
      love.graphics.circle("fill", spark.x, spark.y, spark.size)
    end
  end

  -- ==================== BOSS BODY ====================
  love.graphics.push()
  love.graphics.translate(db.x, db.y)

  local phaseColors = {
    {0.35, 0.18, 0.05},
    {0.4, 0.2, 0.06},
    {0.45, 0.22, 0.08},
    {0.5, 0.25, 0.05},
    {0.55, 0.28, 0.05},
    {0.5, 0.2, 0.1},
    {0.6, 0.3, 0.05},
    {0.65, 0.15, 0.05}
  }
  local baseColor = phaseColors[db.phase] or phaseColors[1]

  -- Main PSU body
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  love.graphics.rectangle("fill", -db.width / 2, -db.height / 2, db.width, db.height)

  -- Casing plating
  love.graphics.setColor(0.15 * alpha, 0.08 * alpha, 0.03 * alpha, alpha)
  love.graphics.rectangle("fill", -75, -58, 150, 35)
  love.graphics.rectangle("fill", -80, 12, 160, 42)

  -- Ventilation grilles
  love.graphics.setColor(0.08 * alpha, 0.04 * alpha, 0.02 * alpha, alpha)
  for i = 0, 5 do
    love.graphics.rectangle("fill", -60 + i * 22, -52, 18, 4)
  end

  -- Power connector shoulders
  love.graphics.setColor(0.4 * alpha, 0.2 * alpha, 0.05 * alpha, alpha)
  love.graphics.polygon("fill", -90, -25, -105, 10, -80, 18, -70, -18)
  love.graphics.polygon("fill", 90, -25, 105, 10, 80, 18, 70, -18)

  -- Regulator nodes (shield generators)
  if not db.regulatorsDown then
    if not db.leftRegulator.destroyed then
      love.graphics.setColor(0.9 * alpha, 0.5 * alpha, 0.1 * alpha, alpha)
      love.graphics.circle("fill", -75, 0, 24)
      local regPulse = 0.5 + math.sin(time * 4.5) * 0.3
      love.graphics.setColor(1, 0.7, 0.2, regPulse * alpha)
      love.graphics.circle("line", -75, 0, 30)
      love.graphics.circle("line", -75, 0, 35)
      local regHpPct = db.leftRegulator.health / 40
      love.graphics.setColor(1, regHpPct, 0, 0.7 * alpha)
      love.graphics.rectangle("fill", -90, -35, 30 * regHpPct, 4)
    end
    if not db.rightRegulator.destroyed then
      love.graphics.setColor(0.9 * alpha, 0.5 * alpha, 0.1 * alpha, alpha)
      love.graphics.circle("fill", 75, 0, 24)
      local regPulse = 0.5 + math.sin(time * 4.5 + math.pi) * 0.3
      love.graphics.setColor(1, 0.7, 0.2, regPulse * alpha)
      love.graphics.circle("line", 75, 0, 30)
      love.graphics.circle("line", 75, 0, 35)
      local regHpPct = db.rightRegulator.health / 40
      love.graphics.setColor(1, regHpPct, 0, 0.7 * alpha)
      love.graphics.rectangle("fill", 60, -35, 30 * regHpPct, 4)
    end
  end

  -- Central hexagonal core
  local coreColors = {
    {1, 0.6, 0.1},
    {1, 0.5, 0.15},
    {1, 0.45, 0.1},
    {1, 0.55, 0.05},
    {1, 0.4, 0.1},
    {1, 0.3, 0.05},
    {1, 0.7, 0.15},
    {1, 0.2, 0.05}
  }
  local coreColor = coreColors[db.phase] or coreColors[1]

  local pulse = 1
  if db.phase >= 4 then pulse = 0.7 + math.abs(math.sin(time * 5)) * 0.3 end
  if db.phase >= 6 then pulse = 0.6 + math.abs(math.sin(time * 7)) * 0.4 end
  if db.enraged then pulse = 0.4 + math.abs(math.sin(time * 12)) * 0.6 end

  -- Hex outline
  love.graphics.setColor(0.05, 0.02, 0.01, alpha)
  local hexR = 38
  local hexVerts = {}
  for i = 0, 5 do
    local a = (i / 6) * math.pi * 2 - math.pi / 6
    table.insert(hexVerts, math.cos(a) * hexR)
    table.insert(hexVerts, math.sin(a) * hexR)
  end
  love.graphics.polygon("fill", unpack(hexVerts))

  -- Core glow
  love.graphics.setColor(coreColor[1] * pulse * alpha, coreColor[2] * pulse * alpha, coreColor[3] * pulse * alpha, alpha)
  local innerHexVerts = {}
  local innerR = 30
  for i = 0, 5 do
    local a = (i / 6) * math.pi * 2 - math.pi / 6
    table.insert(innerHexVerts, math.cos(a) * innerR)
    table.insert(innerHexVerts, math.sin(a) * innerR)
  end
  love.graphics.polygon("fill", unpack(innerHexVerts))

  -- White-hot centre
  love.graphics.setColor(1 * alpha, 1 * alpha, 0.9 * alpha, 0.5 * alpha * pulse)
  love.graphics.circle("fill", 0, 0, 14)

  -- Phase transition glow
  if db.phaseTransitioning then
    local glowPulse = math.abs(math.sin(time * 10))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], glowPulse * 0.6 * alpha)
    love.graphics.circle("fill", 0, 0, 65)
  end

  -- Vulnerability glow (puzzle solved)
  if db.vulnerableFromPuzzle then
    local vulnPulse = 0.5 + math.abs(math.sin(time * 8)) * 0.5
    love.graphics.setColor(0.2, 1, 0.3, vulnPulse * 0.4 * alpha)
    love.graphics.circle("fill", 0, 0, 70)
  end

  -- Power output ports
  local portGlow = db.phase >= 3 and (0.4 + math.sin(time * 6) * 0.3) or 0
  love.graphics.setColor((0.6 + portGlow) * alpha, (0.25 + portGlow * 0.3) * alpha, 0.08 * alpha, alpha)
  love.graphics.rectangle("fill", -60, 48, 28, 18)
  love.graphics.rectangle("fill", 32, 48, 28, 18)
  love.graphics.rectangle("fill", -14, 55, 28, 14)

  -- Cable appendages (Phase 5+)
  if db.phase >= 5 then
    love.graphics.setColor(0.5 * alpha, 0.25 * alpha, 0.05 * alpha, alpha * 0.9)
    local cableWave = math.sin(time * 3.5) * 0.35
    love.graphics.push()
    love.graphics.rotate(cableWave)
    love.graphics.polygon("fill", -95, -8, -110, 8, -100, 28, -88, 12)
    love.graphics.pop()
    love.graphics.push()
    love.graphics.rotate(-cableWave)
    love.graphics.polygon("fill", 95, -8, 110, 8, 100, 28, 88, 12)
    love.graphics.pop()
  end

  -- Overload crown (Phase 7+)
  if db.phase >= 7 then
    love.graphics.setColor(1 * alpha, 0.6 * alpha, 0.1 * alpha, alpha * 0.8)
    love.graphics.polygon("fill", 0, -72, -25, -55, -18, -48, 0, -60, 18, -48, 25, -55)
    love.graphics.setColor(coreColor[1] * 0.9, coreColor[2] * 0.9, coreColor[3] * 0.9, 0.8 * alpha)
    love.graphics.circle("fill", 0, -58, 6)
  end

  -- Meltdown cracks (Phase 8)
  if db.enraged then
    love.graphics.setColor(1, 0.4, 0.05, 0.7 + math.sin(time * 15) * 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(-40, -30, -20, 10)
    love.graphics.line(-20, 10, -35, 40)
    love.graphics.line(30, -25, 15, 15)
    love.graphics.line(15, 15, 40, 45)
    love.graphics.line(-5, -40, 10, -10)
    love.graphics.line(10, -10, -10, 35)
    love.graphics.setLineWidth(1)
  end

  love.graphics.pop()

  -- ==================== ATTACK WARNING ====================
  local warning, progress = dynamoboss.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.5, 0.1, 0.9)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    if progress then
      love.graphics.setColor(0.3, 0.15, 0.05, 0.8)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200, 10)
      love.graphics.setColor(1, 0.5, 0.1)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200 * progress, 10)
    end
  end

  -- ==================== HEALTH BAR (8-segment, orange theme) ====================
  local healthPct = db.health / db.maxHealth
  local barWidth = 320
  local barX = screen.WIDTH / 2 - barWidth / 2
  local barY = 30

  love.graphics.setColor(0.08, 0.04, 0.02, 0.9)
  love.graphics.rectangle("fill", barX - 3, barY - 3, barWidth + 6, 18)
  love.graphics.setColor(0.6, 0.3, 0.08, 0.7)
  love.graphics.rectangle("line", barX - 3, barY - 3, barWidth + 6, 18)

  local segmentCoreColors = {
    {1, 0.6, 0.1}, {1, 0.5, 0.15}, {1, 0.45, 0.1}, {1, 0.55, 0.05},
    {1, 0.4, 0.1}, {1, 0.3, 0.05}, {1, 0.7, 0.15}, {1, 0.2, 0.05}
  }
  for i = 1, 8 do
    local segStart = (i - 1) / 8
    local segEnd = i / 8
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart
      local segColor = segmentCoreColors[i]
      love.graphics.setColor(segColor[1], segColor[2], segColor[3])
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
    end
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", barX + (i / 8) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  love.graphics.setColor(1, 0.8, 0.3)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. db.phase .. "/8 — " .. dynamoboss.getPhaseName(), barX, barY + 14, barWidth, "center")

  -- Boss name
  local bossName = db.enraged and "POWER SUPPLY OVERLORD — TOTAL MELTDOWN" or "POWER SUPPLY OVERLORD"
  love.graphics.setColor(1, 0.6, 0.15)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf(bossName, barX, barY - 20, barWidth, "center")
end

function M.drawParticles()
  for _, p in ipairs(particles.particles) do
    local alpha = p.life / p.maxLife

    if p.bloom then
      -- Bloom effect: multiple layers of decreasing alpha
      for i = 5, 1, -1 do
        local bloomSize = p.size * (1 + i * 0.5)
        local bloomAlpha = (alpha * 0.15 / i)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], bloomAlpha)
        love.graphics.circle("fill", p.x, p.y, bloomSize)
      end

      -- Bright core
      love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.8)
      love.graphics.circle("fill", p.x, p.y, p.size)

      -- Extra bright center
      love.graphics.setColor(1, 1, 1, alpha * 0.6)
      love.graphics.circle("fill", p.x, p.y, p.size * 0.5)
    else
      -- Normal particle
      love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
      love.graphics.circle("fill", p.x, p.y, p.size)
    end
  end
end

function M.drawHUD(player, levelTime, bossActive, levelName, portalCount)
  local callout = wingmen.getCurrentCallout()
  local bossHealth, bossMaxHealth = nil, nil

  if bossActive and boss.currentBoss then
    bossHealth = boss.currentBoss.health
    bossMaxHealth = boss.currentBoss.maxHealth
  end

  -- Show Prototype health bar when Prototype is active
  local prototype = require("starfox.prototype")
  if prototype.isActive() and not prototype.defeated then
    local ship = prototype.getShip()
    if ship then
      bossHealth = ship.health
      bossMaxHealth = prototype.getDef().health
    end
  end

  hud.draw(player, levelTime, callout, bossHealth, bossMaxHealth, levelName, portalCount)
end

function M.drawMenu()
  love.graphics.setBackgroundColor(0, 0, 0)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("STARFOX 2D", 0, 200, screen.WIDTH, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("CORNERIA", 0, 250, screen.WIDTH, "center")
  love.graphics.printf("Press SPACE to start", 0, 320, screen.WIDTH, "center")
  love.graphics.printf("Arrows: Move | SPACE: Shoot | Z: Barrel Roll | X: Bomb", 0, 360, screen.WIDTH, "center")
end

function M.drawGameOver(score)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 0, 0)
  love.graphics.printf("MISSION FAILED", 0, 200, screen.WIDTH, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 280, screen.WIDTH, "center")
  love.graphics.printf("Press R to retry", 0, 340, screen.WIDTH, "center")
end

function M.startVictoryAnimation(enemiesDefeated, totalEnemies, notesEarned)
  victoryState.active = true
  victoryState.timer = 0
  victoryState.enemiesDefeated = enemiesDefeated
  victoryState.totalEnemies = totalEnemies
  victoryState.baseNotesEarned = notesEarned
  victoryState.displayedEnemies = 0
  victoryState.displayedNotes = 0
  victoryState.countSpeed = 8
  victoryState.countPhase = "counting"
  victoryState.groupedMedals = supershot.getGroupedEarnedMedals()
  victoryState.medalIndex = 0
  victoryState.medalTimer = 0
  victoryState.medalBonusDisplayed = 0
  victoryState.medalSlideIn = 0
  victoryState.medalShowTimes = {}
  victoryState.lastNoteThreshold = 0
  victoryState.notePulse = 0
  victoryState.noteFlashTimer = 0
end

function M.updateVictory(dt)
  if not victoryState.active then return end
  victoryState.timer = victoryState.timer + dt

  if victoryState.countPhase == "counting" then
    -- Accelerate the count over time
    victoryState.countSpeed = math.min(victoryState.countSpeed + dt * 20, 120)
    victoryState.displayedEnemies = victoryState.displayedEnemies + victoryState.countSpeed * dt

    if victoryState.displayedEnemies >= victoryState.enemiesDefeated then
      victoryState.displayedEnemies = victoryState.enemiesDefeated
      victoryState.displayedNotes = victoryState.baseNotesEarned
      victoryState.countPhase = "medals_pause"
      victoryState.medalTimer = 0
    else
      -- Update notes proportionally
      local newNotes = math.floor(victoryState.displayedEnemies / 10)
      if newNotes > victoryState.displayedNotes then
        victoryState.displayedNotes = newNotes
        victoryState.notePulse = 1.0
        victoryState.noteFlashTimer = 0.3
      end
    end
  elseif victoryState.countPhase == "medals_pause" then
    -- Brief pause before showing medals
    victoryState.medalTimer = victoryState.medalTimer + dt
    if victoryState.medalTimer >= 0.8 then
      if #victoryState.groupedMedals > 0 then
        victoryState.countPhase = "medals"
        victoryState.medalIndex = 1
        victoryState.medalTimer = 0
        victoryState.medalSlideIn = 0
        victoryState.medalBonusDisplayed = 0
      else
        victoryState.countPhase = "done"
      end
    end
  elseif victoryState.countPhase == "medals" then
    local groups = victoryState.groupedMedals
    if victoryState.medalIndex > #groups then
      victoryState.countPhase = "done"
    else
      victoryState.medalTimer = victoryState.medalTimer + dt
      victoryState.medalSlideIn = math.min(victoryState.medalSlideIn + dt * 4, 1.0)

      -- After slide-in, increment the bonus notes for this group
      local group = groups[victoryState.medalIndex]
      local totalGroupBonus = supershot.getMedalBonusNotes(group.medal.threshold) * group.count
      if victoryState.medalSlideIn >= 1.0 and victoryState.medalBonusDisplayed < totalGroupBonus then
        local addSpeed = math.max(totalGroupBonus * 2, 8)
        victoryState.medalBonusDisplayed = victoryState.medalBonusDisplayed + addSpeed * dt
        if victoryState.medalBonusDisplayed >= totalGroupBonus then
          victoryState.medalBonusDisplayed = totalGroupBonus
        end
        local newTotal = victoryState.baseNotesEarned + math.floor(victoryState.medalBonusDisplayed)
        -- Accumulate from previous groups
        for i = 1, victoryState.medalIndex - 1 do
          local prevGroup = groups[i]
          newTotal = newTotal + supershot.getMedalBonusNotes(prevGroup.medal.threshold) * prevGroup.count
        end
        if newTotal > victoryState.displayedNotes then
          victoryState.displayedNotes = newTotal
          victoryState.notePulse = 1.0
          victoryState.noteFlashTimer = 0.3
        end
      end

      -- Move to next group after counting is done and a pause
      if victoryState.medalBonusDisplayed >= totalGroupBonus then
        -- Record when this medal row finished counting
        if not victoryState.medalShowTimes[victoryState.medalIndex] then
          victoryState.medalShowTimes[victoryState.medalIndex] = love.timer.getTime()
        end
        if victoryState.medalTimer > 2.0 then
          -- Calculate accumulated notes before moving on
          local accumulatedBonus = 0
          for i = 1, victoryState.medalIndex do
            local g = groups[i]
            accumulatedBonus = accumulatedBonus + supershot.getMedalBonusNotes(g.medal.threshold) * g.count
          end
          victoryState.displayedNotes = victoryState.baseNotesEarned + accumulatedBonus
          victoryState.medalIndex = victoryState.medalIndex + 1
          victoryState.medalTimer = 0
          victoryState.medalSlideIn = 0
          victoryState.medalBonusDisplayed = 0
        end
      end
    end
  end

  -- Decay visual effects
  victoryState.notePulse = math.max(0, victoryState.notePulse - dt * 3)
  victoryState.noteFlashTimer = math.max(0, victoryState.noteFlashTimer - dt)
end

-- Epic Warden boss victory screen
function M.drawWardenVictory(enemiesDefeated, totalEnemies, notesEarned)
  local time = love.timer.getTime()
  local cx, cy = screen.WIDTH / 2, screen.HEIGHT / 2

  -- Dark dramatic background with pulsing red/gold edges
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Radial ember glow from center
  for i = 1, 5 do
    local radius = 180 - i * 30
    local pulse = math.sin(time * 1.2 + i * 0.5) * 0.1 + 0.15
    love.graphics.setColor(0.9, 0.5 + i * 0.05, 0.1, pulse / i)
    love.graphics.circle("fill", cx, cy - 40, radius)
  end

  -- Floating golden particles (embers rising)
  for i = 1, 30 do
    local seed = i * 137.508
    local px = cx + math.sin(seed + time * 0.4) * (100 + i * 5)
    local py = screen.HEIGHT - math.fmod((time * 40 + i * 23), screen.HEIGHT + 40)
    local sz = 1 + math.sin(seed) * 1.5
    local flicker = math.sin(time * 3 + seed) * 0.3 + 0.7
    if i % 3 == 0 then
      love.graphics.setColor(1, 0.85, 0.3, flicker * 0.8)
    elseif i % 3 == 1 then
      love.graphics.setColor(1, 0.5, 0.1, flicker * 0.6)
    else
      love.graphics.setColor(1, 0.3, 0.1, flicker * 0.5)
    end
    love.graphics.circle("fill", px, py, sz)
  end

  -- Shattered chains falling from top (decorative)
  for i = 1, 8 do
    local chainX = 40 + i * (screen.WIDTH - 80) / 8
    local drop = math.fmod(time * 20 + i * 50, screen.HEIGHT + 60)
    local rot = time * 2 + i
    local alpha = math.max(0, 1 - drop / screen.HEIGHT)
    love.graphics.setColor(0.5, 0.4, 0.3, alpha * 0.6)
    love.graphics.push()
    love.graphics.translate(chainX, drop)
    love.graphics.rotate(rot)
    -- Chain link
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", 0, 0, 6, 10)
    love.graphics.ellipse("line", 0, 14, 6, 10)
    love.graphics.pop()
  end

  -- Dramatic title: "THE WARDEN HAS FALLEN"
  local titleY = 50
  local titleShake = math.sin(time * 8) * 1.5
  -- Shadow
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.printf("THE WARDEN HAS FALLEN", 3, titleY + 3 + titleShake, screen.WIDTH, "center")
  -- Gold glow behind text
  love.graphics.setColor(1, 0.7, 0.2, 0.3 + math.sin(time * 2) * 0.15)
  love.graphics.printf("THE WARDEN HAS FALLEN", 0, titleY + titleShake, screen.WIDTH, "center")
  -- Main text
  local titlePulse = math.sin(time * 1.5) * 0.15
  love.graphics.setColor(1, 0.85 + titlePulse, 0.3 + titlePulse, 1)
  love.graphics.printf("THE WARDEN HAS FALLEN", 1, titleY + 1 + titleShake, screen.WIDTH, "center")

  -- Subtitle
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.8, 0.6, 0.3, 0.7 + math.sin(time * 2.5) * 0.3)
  love.graphics.printf("The prison is broken. Freedom reigns.", 0, titleY + 40, screen.WIDTH, "center")

  -- Defeated warden silhouette (crumbling)
  local wardenY = cy - 20
  love.graphics.setColor(0.15, 0.08, 0.05, 0.6)
  -- Body
  love.graphics.rectangle("fill", cx - 30, wardenY - 30, 60, 70, 4, 4)
  -- Head cracked
  love.graphics.circle("fill", cx, wardenY - 45, 18)
  -- Crack lines through the silhouette
  love.graphics.setColor(1, 0.6, 0.1, 0.5 + math.sin(time * 4) * 0.3)
  love.graphics.setLineWidth(2)
  love.graphics.line(cx - 5, wardenY - 55, cx + 3, wardenY - 20, cx - 8, wardenY + 10, cx + 5, wardenY + 40)
  love.graphics.line(cx + 8, wardenY - 50, cx - 2, wardenY - 15, cx + 10, wardenY + 15)
  -- Crumbling pieces falling
  for i = 1, 12 do
    local fallSpeed = 15 + i * 3
    local px = cx + math.sin(i * 2.3) * 35
    local py = wardenY + math.fmod(time * fallSpeed + i * 20, 120) - 30
    local sz = 2 + math.sin(i * 1.7) * 1.5
    local alpha = math.max(0, 1 - (py - wardenY) / 100)
    love.graphics.setColor(0.3, 0.2, 0.1, alpha * 0.7)
    love.graphics.rectangle("fill", px, py, sz, sz)
  end

  -- Stats section
  local statsY = cy + 90
  local dispEnemies = math.floor(victoryState.displayedEnemies)
  local percentage = totalEnemies > 0 and math.floor((enemiesDefeated / totalEnemies) * 100) or 100
  local isPerfect = percentage == 100

  -- Rank with golden styling
  local rank = "E"
  if percentage == 100 then rank = "S"
  elseif percentage >= 90 then rank = "A"
  elseif percentage >= 75 then rank = "B"
  elseif percentage >= 60 then rank = "C"
  elseif percentage >= 40 then rank = "D"
  end

  -- Enemies defeated
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.9, 0.8, 0.6, 1)
  love.graphics.printf("Enemies Vanquished: " .. dispEnemies .. " / " .. totalEnemies, 0, statsY, screen.WIDTH, "center")

  -- Rank with special glow for S rank
  local rankY = statsY + 30
  if rank == "S" then
    love.graphics.setColor(1, 0.9, 0.3, 0.3 + math.sin(time * 3) * 0.2)
    love.graphics.printf("RANK: S", -2, rankY - 2, screen.WIDTH, "center")
    love.graphics.setColor(1, 0.95, 0.5, 1)
  else
    love.graphics.setColor(0.9, 0.8, 0.6, 1)
  end
  love.graphics.printf("RANK: " .. rank, 0, rankY, screen.WIDTH, "center")

  -- Notes earned with golden flash
  local notesY = rankY + 30
  local noteScale = 1 + victoryState.notePulse * 0.3
  love.graphics.push()
  love.graphics.translate(cx, notesY + 8)
  love.graphics.scale(noteScale, noteScale)
  local noteFlash = victoryState.noteFlashTimer > 0 and math.sin(victoryState.noteFlashTimer * 20) * 0.5 + 0.5 or 0
  love.graphics.setColor(1, 0.9 + noteFlash * 0.1, 0.3 + noteFlash * 0.3, 1)
  love.graphics.printf("+" .. math.floor(victoryState.displayedNotes) .. " Notes", -screen.WIDTH / 2, -8, screen.WIDTH, "center")
  love.graphics.pop()

  -- Medal bonuses
  M.drawVictoryMedals()

  -- Fireworks for perfect victory (golden themed)
  if isPerfect then
    for i = 1, 6 do
      local fx = math.sin(time * 0.7 + i * 1.2) * (screen.WIDTH * 0.35) + cx
      local fy = 80 + math.sin(time * 0.5 + i * 0.8) * 40
      for j = 1, 8 do
        local angle = (j / 8) * math.pi * 2 + time * 2
        local dist = 12 + math.sin(time * 4 + i + j) * 8
        local sparkX = fx + math.cos(angle) * dist
        local sparkY = fy + math.sin(angle) * dist
        love.graphics.setColor(1, 0.8 + math.sin(j + time) * 0.2, 0.2, 0.8)
        love.graphics.circle("fill", sparkX, sparkY, 2)
      end
    end
  end

  -- "MEGA ANTENNA SECURED" subtitle at bottom
  local securedY = screen.HEIGHT - 80
  local securedPulse = math.sin(time * 2) * 0.2
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.2, 1, 0.5, 0.6 + securedPulse)
  love.graphics.printf("MEGA ANTENNA SECURED", 0, securedY, screen.WIDTH, "center")

  -- Press R prompt
  if victoryState.countPhase == "done" then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1, 0.7 + math.sin(time * 3) * 0.3)
    love.graphics.printf("Press R to continue", 0, screen.HEIGHT - 40, screen.WIDTH, "center")
  end
end

function M.drawSentinelVictory(enemiesDefeated, totalEnemies, notesEarned)
  local time = love.timer.getTime()
  local cx, cy = screen.WIDTH / 2, screen.HEIGHT / 2

  -- Dark dramatic background with electric edges
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Radial electric glow from center
  for i = 1, 5 do
    local radius = 180 - i * 30
    local pulse = math.sin(time * 1.5 + i * 0.6) * 0.12 + 0.15
    love.graphics.setColor(0.15 + i * 0.04, 0.4 + i * 0.06, 0.8, pulse / i)
    love.graphics.circle("fill", cx, cy - 40, radius)
  end

  -- Floating electric particles (sparks drifting upward)
  for i = 1, 35 do
    local seed = i * 137.508
    local px = cx + math.sin(seed + time * 0.5) * (110 + i * 5)
    local py = screen.HEIGHT - math.fmod((time * 45 + i * 21), screen.HEIGHT + 40)
    local sz = 1 + math.sin(seed) * 1.5
    local flicker = math.sin(time * 4 + seed) * 0.3 + 0.7
    if i % 3 == 0 then
      love.graphics.setColor(0.4, 0.8, 1, flicker * 0.8)
    elseif i % 3 == 1 then
      love.graphics.setColor(0.3, 0.6, 1, flicker * 0.6)
    else
      love.graphics.setColor(0.6, 0.4, 1, flicker * 0.5)
    end
    love.graphics.circle("fill", px, py, sz)
  end

  -- Dissolving circuit traces falling from top
  for i = 1, 10 do
    local traceX = 30 + i * (screen.WIDTH - 60) / 10
    local drop = math.fmod(time * 18 + i * 45, screen.HEIGHT + 60)
    local alpha = math.max(0, 1 - drop / screen.HEIGHT)
    love.graphics.setColor(0.2, 0.5, 0.9, alpha * 0.5)
    love.graphics.setLineWidth(1.5)
    -- Circuit line segments
    local y1 = drop
    local y2 = drop + 15
    local y3 = drop + 20
    love.graphics.line(traceX, y1, traceX, y2)
    love.graphics.line(traceX, y2, traceX + 8 * math.sin(i), y3)
    love.graphics.line(traceX + 8 * math.sin(i), y3, traceX + 8 * math.sin(i), y3 + 12)
    love.graphics.setLineWidth(1)
  end

  -- Dramatic title: "THE SENTINEL HAS FALLEN"
  local titleY = 50
  local titleShake = math.sin(time * 9) * 1.2
  -- Shadow
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.printf("THE SENTINEL HAS FALLEN", 3, titleY + 3 + titleShake, screen.WIDTH, "center")
  -- Electric glow behind text
  love.graphics.setColor(0.2, 0.6, 1, 0.3 + math.sin(time * 2.5) * 0.15)
  love.graphics.printf("THE SENTINEL HAS FALLEN", 0, titleY + titleShake, screen.WIDTH, "center")
  -- Main text
  local titlePulse = math.sin(time * 1.8) * 0.15
  love.graphics.setColor(0.5 + titlePulse, 0.85 + titlePulse, 1, 1)
  love.graphics.printf("THE SENTINEL HAS FALLEN", 1, titleY + 1 + titleShake, screen.WIDTH, "center")

  -- Subtitle
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.4, 0.7, 0.9, 0.7 + math.sin(time * 2.8) * 0.3)
  love.graphics.printf("The perimeter is breached. Protocols overridden.", 0, titleY + 40, screen.WIDTH, "center")

  -- Defeated sentinel silhouette (dissolving hologram)
  local sentinelY = cy - 20
  -- Glitching hologram body
  local glitchOffset = math.floor(time * 12) % 3 == 0 and math.random(-3, 3) or 0
  love.graphics.setColor(0.15, 0.3, 0.5, 0.4)
  -- Hexagonal body outline
  love.graphics.polygon("fill",
    cx + glitchOffset - 25, sentinelY - 35,
    cx + glitchOffset + 25, sentinelY - 35,
    cx + glitchOffset + 35, sentinelY,
    cx + glitchOffset + 25, sentinelY + 35,
    cx + glitchOffset - 25, sentinelY + 35,
    cx + glitchOffset - 35, sentinelY)
  -- Visor slit
  love.graphics.setColor(0.3, 0.7, 1, 0.3 + math.sin(time * 5) * 0.2)
  love.graphics.rectangle("fill", cx + glitchOffset - 20, sentinelY - 8, 40, 6)
  -- Scan lines through silhouette (hologram glitch)
  love.graphics.setColor(0.3, 0.6, 1, 0.2)
  for scanLine = -35, 35, 4 do
    if math.sin(time * 8 + scanLine * 0.3) > 0 then
      love.graphics.line(cx - 35, sentinelY + scanLine, cx + 35, sentinelY + scanLine)
    end
  end
  -- Dissolving pixel fragments
  for i = 1, 15 do
    local fallSpeed = 12 + i * 3
    local px = cx + math.sin(i * 2.7) * 40
    local py = sentinelY + math.fmod(time * fallSpeed + i * 18, 130) - 35
    local sz = 2 + math.sin(i * 1.9) * 1.5
    local fragAlpha = math.max(0, 1 - (py - sentinelY) / 110)
    love.graphics.setColor(0.2, 0.5, 0.8, fragAlpha * 0.6)
    love.graphics.rectangle("fill", px, py, sz, sz)
  end

  -- Stats section
  local statsY = cy + 90
  local dispEnemies = math.floor(victoryState.displayedEnemies)
  local percentage = totalEnemies > 0 and math.floor((enemiesDefeated / totalEnemies) * 100) or 100
  local isPerfect = percentage == 100

  -- Rank
  local rank = "E"
  if percentage == 100 then rank = "S"
  elseif percentage >= 90 then rank = "A"
  elseif percentage >= 75 then rank = "B"
  elseif percentage >= 60 then rank = "C"
  elseif percentage >= 40 then rank = "D"
  end

  -- Enemies defeated
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.7, 0.85, 1, 1)
  love.graphics.printf("Targets Eliminated: " .. dispEnemies .. " / " .. totalEnemies, 0, statsY, screen.WIDTH, "center")

  -- Rank with special glow for S rank
  local rankY = statsY + 30
  if rank == "S" then
    love.graphics.setColor(0.4, 0.8, 1, 0.3 + math.sin(time * 3.5) * 0.2)
    love.graphics.printf("RANK: S", -2, rankY - 2, screen.WIDTH, "center")
    love.graphics.setColor(0.6, 0.9, 1, 1)
  else
    love.graphics.setColor(0.7, 0.85, 1, 1)
  end
  love.graphics.printf("RANK: " .. rank, 0, rankY, screen.WIDTH, "center")

  -- Notes earned with electric flash
  local notesY = rankY + 30
  local noteScale = 1 + victoryState.notePulse * 0.3
  love.graphics.push()
  love.graphics.translate(cx, notesY + 8)
  love.graphics.scale(noteScale, noteScale)
  local noteFlash = victoryState.noteFlashTimer > 0 and math.sin(victoryState.noteFlashTimer * 20) * 0.5 + 0.5 or 0
  love.graphics.setColor(0.4 + noteFlash * 0.3, 0.8 + noteFlash * 0.1, 1, 1)
  love.graphics.printf("+" .. math.floor(victoryState.displayedNotes) .. " Notes", -screen.WIDTH / 2, -8, screen.WIDTH, "center")
  love.graphics.pop()

  -- Medal bonuses
  M.drawVictoryMedals()

  -- Electric fireworks for perfect victory
  if isPerfect then
    for i = 1, 6 do
      local fx = math.sin(time * 0.8 + i * 1.1) * (screen.WIDTH * 0.35) + cx
      local fy = 80 + math.sin(time * 0.6 + i * 0.9) * 40
      for j = 1, 10 do
        local angle = (j / 10) * math.pi * 2 + time * 2.5
        local dist = 14 + math.sin(time * 5 + i + j) * 9
        local sparkX = fx + math.cos(angle) * dist
        local sparkY = fy + math.sin(angle) * dist
        love.graphics.setColor(0.3 + math.sin(j + time) * 0.2, 0.7, 1, 0.8)
        love.graphics.circle("fill", sparkX, sparkY, 2)
      end
      -- Electric arcs between sparks
      love.graphics.setColor(0.4, 0.8, 1, 0.3)
      love.graphics.setLineWidth(1)
      for j = 1, 4 do
        local a1 = (j / 10) * math.pi * 2 + time * 2.5
        local a2 = ((j + 1) / 10) * math.pi * 2 + time * 2.5
        local d = 14
        love.graphics.line(
          fx + math.cos(a1) * d, fy + math.sin(a1) * d,
          fx + math.cos(a2) * d, fy + math.sin(a2) * d)
      end
    end
  end

  -- "POWER AMPLIFIER SECURED" subtitle at bottom
  local securedY = screen.HEIGHT - 80
  local securedPulse = math.sin(time * 2.2) * 0.2
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.3, 0.8, 1, 0.6 + securedPulse)
  love.graphics.printf("POWER AMPLIFIER SECURED", 0, securedY, screen.WIDTH, "center")

  -- Press R prompt
  if victoryState.countPhase == "done" then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1, 0.7 + math.sin(time * 3) * 0.3)
    love.graphics.printf("Press R to continue", 0, screen.HEIGHT - 40, screen.WIDTH, "center")
  end
end

function M.drawVictory(enemiesDefeated, totalEnemies, notesEarned)
  notesEarned = notesEarned or 0

  -- Start animation if not active
  if not victoryState.active then
    M.startVictoryAnimation(enemiesDefeated, totalEnemies, notesEarned)
  end

  -- Special epic victory screen for The Warden (level 19)
  if currentLevelId == 19 then
    M.drawWardenVictory(enemiesDefeated, totalEnemies, notesEarned)
    return
  end

  -- Special epic victory screen for The Sentinel (level 20)
  if currentLevelId == 20 then
    M.drawSentinelVictory(enemiesDefeated, totalEnemies, notesEarned)
    return
  end

  local dispEnemies = math.floor(victoryState.displayedEnemies)
  local dispNotes = victoryState.displayedNotes
  local percentage = totalEnemies > 0 and (dispEnemies / totalEnemies * 100) or 0
  local finalPercentage = totalEnemies > 0 and (enemiesDefeated / totalEnemies * 100) or 0
  local rank = ""
  local title = ""
  local titleColor = {0, 1, 0}
  local isPerfect = false

  if finalPercentage >= 100 then
    rank = "S"
    isPerfect = true
  elseif finalPercentage >= 95 then
    rank = "S"
  elseif finalPercentage >= 90 then
    rank = "A"
  elseif finalPercentage >= 80 then
    rank = "B"
  elseif finalPercentage >= 70 then
    rank = "C"
  elseif finalPercentage >= 60 then
    rank = "D"
  else
    rank = "E"
  end

  if finalPercentage >= 60 then
    if isPerfect then
      title = "PERFECT STAGE!!"
      titleColor = {1, 1, 0}
    else
      title = "STAGE CLEAR"
      titleColor = {0, 1, 0}
    end
  else
    title = "STAGE FAILED"
    titleColor = {1, 0, 0}
  end

  -- Draw fireworks for perfect stage
  if isPerfect and victoryState.countPhase ~= "counting" then
    M.drawFireworks()
  end

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(titleColor)
  love.graphics.printf(title, 0, 150, screen.WIDTH, "center")

  -- Enemies Defeated line with counting animation
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(string.format("Enemies Defeated: %d / %d (%.1f%%)", dispEnemies, totalEnemies, percentage), 0, 230, screen.WIDTH, "center")

  -- Rank (show only after counting done)
  if victoryState.countPhase ~= "counting" then
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Rank: " .. rank, 0, 260, screen.WIDTH, "center")
  end

  -- Notes Earned with pulse animation
  local noteScale = 1.0 + victoryState.notePulse * 0.3
  local noteY = 295

  love.graphics.push()
  love.graphics.translate(400, noteY + 10)
  love.graphics.scale(noteScale, noteScale)

  if victoryState.noteFlashTimer > 0 then
    love.graphics.setColor(1, 1, 0.5)
  else
    love.graphics.setColor(1, 1, 0)
  end
  love.graphics.setFont(fonts.normal)
  love.graphics.printf(string.format("Notes Earned: %d", dispNotes), -400, -10, screen.WIDTH, "center")
  love.graphics.pop()

  -- Draw medal bonuses
  if victoryState.countPhase == "medals" or victoryState.countPhase == "done" then
    M.drawVictoryMedals()
  end

  -- Press R prompt (show after done)
  if victoryState.countPhase == "done" then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to continue", 0, 520, screen.WIDTH, "center")
  end
end

function M.drawVictoryMedals()
  local groups = victoryState.groupedMedals
  if #groups == 0 then return end

  local startY = 340
  local rowHeight = 45
  local time = love.timer.getTime()
  local DECAY_DURATION = 5.0  -- seconds to slow animations to a stop

  for i, group in ipairs(groups) do
    local medal = group.medal
    local count = group.count
    local r, g, b = medal.color[1], medal.color[2], medal.color[3]
    local rr, rg, rb = medal.rimColor[1], medal.rimColor[2], medal.rimColor[3]
    local totalGroupBonus = supershot.getMedalBonusNotes(medal.threshold) * count
    local y = startY + (i - 1) * rowHeight

    -- Calculate slide and alpha
    local slideIn = 0
    local alpha = 0
    local bonusCount = totalGroupBonus  -- fully counted by default

    if victoryState.countPhase == "medals" then
      if i < victoryState.medalIndex then
        slideIn = 1.0
        alpha = 1.0
      elseif i == victoryState.medalIndex then
        slideIn = victoryState.medalSlideIn
        alpha = slideIn
        bonusCount = math.floor(victoryState.medalBonusDisplayed)
      else
        slideIn = 0
        alpha = 0
      end
    elseif victoryState.countPhase == "done" then
      slideIn = 1.0
      alpha = 1.0
    end

    if alpha <= 0 then goto continueLoop end

    -- Calculate animation decay factor (1.0 = full intensity, 0.0 = stopped)
    local decayFactor = 1.0
    local showTime = victoryState.medalShowTimes[i]
    if showTime then
      local elapsed = time - showTime
      decayFactor = math.max(0, 1.0 - (elapsed / DECAY_DURATION))
    end

    local offsetX = (1.0 - slideIn) * 200
    local baseX = screen.WIDTH / 2 - 216 + offsetX
    local baseY = y

    -- Animation intensity per tier, scaled by decay
    local pulseAmt = 0
    local glowInt = 1.0
    local shakeX = 0

    if medal.threshold == 10 then
      pulseAmt = math.sin(time * 8) * 1.5 * decayFactor
      glowInt = 1.0 + math.sin(time * 10) * 0.2 * decayFactor
    elseif medal.threshold == 15 then
      pulseAmt = math.sin(time * 10) * 2 * decayFactor
      glowInt = 1.0 + math.sin(time * 13) * 0.3 * decayFactor
      shakeX = math.sin(time * 18) * 1 * decayFactor
    elseif medal.threshold == 20 then
      pulseAmt = math.sin(time * 12) * 3 * decayFactor
      glowInt = 1.0 + math.sin(time * 16) * 0.5 * decayFactor
      shakeX = math.sin(time * 25) * 1.5 * decayFactor
    elseif medal.threshold == 25 then
      pulseAmt = math.sin(time * 16) * 4 * decayFactor
      glowInt = 1.0 + math.sin(time * 20) * 0.7 * decayFactor
      shakeX = math.sin(time * 35) * 2.5 * decayFactor
    end

    baseX = baseX + shakeX

    -- Glow behind row for higher tiers
    if medal.threshold >= 15 and decayFactor > 0 then
      local glowLayers = medal.threshold >= 25 and 3 or (medal.threshold >= 20 and 2 or 1)
      for j = 1, glowLayers do
        love.graphics.setColor(r, g, b, (0.06 * glowInt * alpha * decayFactor) / j)
        love.graphics.rectangle("fill", baseX - 8 - j * 4, baseY - 4 - j * 2,
          440 + j * 8, rowHeight - 4 + j * 4, 6, 6)
      end
    end

    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", baseX - 4, baseY, 440, rowHeight - 8, 6, 6)

    love.graphics.setColor(rr, rg, rb, 0.5 * alpha * glowInt)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", baseX - 4, baseY, 440, rowHeight - 8, 6, 6)
    love.graphics.setLineWidth(1)

    -- Medal icon
    local iconX = baseX + 16
    local iconY = baseY + (rowHeight - 8) / 2
    local iconPulse = 1.0 + pulseAmt * 0.01

    -- Outer glow
    love.graphics.setColor(r, g, b, 0.2 * alpha * glowInt)
    love.graphics.circle("fill", iconX, iconY, 14 * iconPulse)

    -- Disc
    love.graphics.setColor(rr, rg, rb, 0.9 * alpha)
    love.graphics.circle("fill", iconX, iconY, 10 * iconPulse)

    -- Inner
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.circle("fill", iconX, iconY, 7 * iconPulse)

    -- Star
    love.graphics.setColor(1, 1, 1, 0.9 * alpha)
    local sz = 4 * iconPulse
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

    -- Rim
    love.graphics.setColor(1, 1, 1, 0.4 * alpha)
    love.graphics.circle("line", iconX, iconY, 10 * iconPulse)

    -- Medal label with count
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(r, g, b, alpha)
    local labelText = medal.label
    if count > 1 then
      labelText = medal.label .. " x" .. count
    end
    love.graphics.print(labelText, baseX + 36, baseY + 7)

    -- Bonus notes text
    local bonusText = string.format("+%d Notes", bonusCount)
    love.graphics.setFont(fonts.normal)

    -- Animate color intensity for bonus text, scaled by decay
    local bonusAlpha = alpha
    if i == victoryState.medalIndex and victoryState.countPhase == "medals" then
      bonusAlpha = alpha * (0.7 + math.sin(time * 12) * 0.3)
    end
    love.graphics.setColor(1, 1, 0, bonusAlpha)
    love.graphics.printf(bonusText, baseX + 36, baseY + 7, 380, "right")

    ::continueLoop::
  end
end

function M.resetVictory()
  victoryState.active = false
  victoryState.timer = 0
  victoryState.countPhase = "counting"
end

function M.drawFireworks()
  local time = love.timer.getTime()
  local elapsed = time % 5  -- 5 second loop
  local progress = elapsed / 5  -- 0 to 1
  local fadeStart = 0.8  -- Start fading at 4 seconds
  local alpha = 1
  
  if progress >= fadeStart then
    alpha = 1 - ((progress - fadeStart) / (1 - fadeStart))
  end
  
  if alpha <= 0 then return end
  
  -- Left side fireworks
  for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2 + time * 3
    local distance = progress * 200
    local x = 100 + math.cos(angle) * distance
    local y = 150 + math.sin(angle) * distance
    
    local sparkleSize = (1 - progress) * 3 + 1
    love.graphics.setColor(1, math.random() * 0.5, 0, alpha)
    love.graphics.circle("fill", x, y, sparkleSize)
  end
  
  -- Right side fireworks
  for i = 1, 8 do
    local angle = (i / 8) * math.pi * 2 + time * 3
    local distance = progress * 200
    local x = 700 + math.cos(angle) * distance
    local y = 150 + math.sin(angle) * distance
    
    local sparkleSize = (1 - progress) * 3 + 1
    love.graphics.setColor(0, 1, math.random() * 0.5, alpha)
    love.graphics.circle("fill", x, y, sparkleSize)
  end
end

function M.drawWarp(score)
  -- Warp effect background
  local time = love.timer.getTime()
  for i = 1, 30 do
    local speed = 200 + i * 50
    local y = (time * speed) % 700 - 50
    local alpha = 0.3 + (i / 30) * 0.5
    love.graphics.setColor(0.3, 0.6, 1, alpha)
    love.graphics.rectangle("fill", 350 + math.sin(i) * 50, y, 4, 30 + i * 2)
    love.graphics.rectangle("fill", 450 - math.sin(i) * 50, y, 4, 30 + i * 2)
  end

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.4, 0.8, 1)
  love.graphics.printf("WARP ZONE!", 0, 180, screen.WIDTH, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.6, 0.9, 1)
  love.graphics.printf("All 7 portals collected!", 0, 240, screen.WIDTH, "center")

  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 300, screen.WIDTH, "center")
  love.graphics.printf("SECRET PATH UNLOCKED", 0, 340, screen.WIDTH, "center")
  love.graphics.printf("Press R to continue", 0, 400, screen.WIDTH, "center")
end

function M.drawPostLevelMenu(selectedIndex)
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.8)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("MISSION COMPLETE", 0, 150, screen.WIDTH, "center")

  -- Menu options
  love.graphics.setFont(fonts.normal)
  local options = {"Return to Portal", "Go To World Map", "Return To Station"}
  local startY = 260

  for i, option in ipairs(options) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * 50, screen.WIDTH, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(option, 0, startY + (i - 1) * 50, screen.WIDTH, "center")
    end
  end

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select", 0, 450, screen.WIDTH, "center")
end

function M.drawLevelSelect()
  -- Delegate to levelselect's own draw function (LOTR-styled ring map)
  levelselect.draw()
end

function M.drawPauseMenu(selectedIndex, isLevelSelect, enteredFromPortal)
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("PAUSED", 0, 150, screen.WIDTH, "center")

  -- Menu options
  love.graphics.setFont(fonts.normal)
  local options
  if isLevelSelect then
    options = {"Resume", "Options", "Exit to Station"}
  else
    local mapOption = enteredFromPortal and "Exit to Portal" or "Return to Map"
    options = {"Resume", "Restart Level", "Options", mapOption, "Return to Station"}
  end
  local startY = 250

  for i, option in ipairs(options) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. option .. " <", 0, startY + (i - 1) * 40, screen.WIDTH, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(option, 0, startY + (i - 1) * 40, screen.WIDTH, "center")
    end
  end

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 450, screen.WIDTH, "center")
end

function M.drawOptionsMenu()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("OPTIONS", 0, 200, screen.WIDTH, "center")

  -- Placeholder text
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Options menu coming soon...", 0, 280, screen.WIDTH, "center")

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("ESC: Back", 0, 450, screen.WIDTH, "center")
end

function M.drawSphereBoss()
  local sb = sphereboss.boss
  if not sb or not sb.active then return end

  local time = love.timer.getTime()
  local alpha = 1

  -- ============================================================
  -- DEATH STAR TUNNEL BACKGROUND
  -- tunnelDepth 0→1 drives progression from outer trench to reactor core
  -- ============================================================
  local depth = sb.tunnelDepth or 0

  -- Darken sky as we go deeper
  local skyDarken = depth * 0.7
  love.graphics.setColor(0, 0, 0, skyDarken)
  love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)

  -- Tunnel walls (metallic grey → orange reactor glow)
  local wallR = 0.15 + depth * 0.5
  local wallG = 0.15 + depth * 0.2
  local wallB = 0.18 - depth * 0.1
  local wallAlpha = 0.3 + depth * 0.5

  -- Left wall panels
  for i = 0, 8 do
    local yOff = (i * 90 + time * 60 * (0.5 + depth)) % (screen.HEIGHT + 90) - 45
    local wallW = 30 + depth * 50 + math.sin(time + i) * 8
    love.graphics.setColor(wallR * 0.6, wallG * 0.6, wallB, wallAlpha * 0.6)
    love.graphics.rectangle("fill", 0, yOff, wallW, 80)
    -- Panel seams
    love.graphics.setColor(wallR, wallG, wallB, wallAlpha * 0.3)
    love.graphics.rectangle("fill", 0, yOff, wallW, 2)
    love.graphics.rectangle("fill", 0, yOff + 79, wallW, 2)
    -- Inner glow lines
    if depth > 0.5 then
      local glow = (depth - 0.5) * 2
      love.graphics.setColor(1, 0.5, 0.1, glow * 0.3 * (0.5 + math.sin(time * 3 + i) * 0.3))
      love.graphics.rectangle("fill", wallW - 4, yOff + 10, 3, 60)
    end
  end

  -- Right wall panels
  for i = 0, 8 do
    local yOff = (i * 90 + time * 60 * (0.5 + depth) + 45) % (screen.HEIGHT + 90) - 45
    local wallW = 30 + depth * 50 + math.sin(time + i + 3) * 8
    love.graphics.setColor(wallR * 0.6, wallG * 0.6, wallB, wallAlpha * 0.6)
    love.graphics.rectangle("fill", screen.WIDTH - wallW, yOff, wallW, 80)
    love.graphics.setColor(wallR, wallG, wallB, wallAlpha * 0.3)
    love.graphics.rectangle("fill", screen.WIDTH - wallW, yOff, wallW, 2)
    love.graphics.rectangle("fill", screen.WIDTH - wallW, yOff + 79, wallW, 2)
    if depth > 0.5 then
      local glow = (depth - 0.5) * 2
      love.graphics.setColor(1, 0.5, 0.1, glow * 0.3 * (0.5 + math.sin(time * 3 + i + 2) * 0.3))
      love.graphics.rectangle("fill", screen.WIDTH - wallW + 1, yOff + 10, 3, 60)
    end
  end

  -- Superstructure girders (horizontal beams crossing overhead)
  if depth > 0.2 then
    local girderAlpha = (depth - 0.2) * 1.2
    for i = 0, 3 do
      local yOff = (i * 200 + time * 80 * depth) % (screen.HEIGHT + 200) - 100
      love.graphics.setColor(0.12, 0.1, 0.14, girderAlpha * 0.4)
      love.graphics.rectangle("fill", 0, yOff, screen.WIDTH, 6)
      love.graphics.setColor(wallR * 0.3, wallG * 0.3, wallB * 0.3, girderAlpha * 0.2)
      love.graphics.rectangle("fill", 0, yOff + 6, screen.WIDTH, 2)
    end
  end

  -- Reactor glow (Phases 3-4: deep orange glow from below)
  if depth > 0.6 then
    local reactorGlow = (depth - 0.6) * 2.5
    love.graphics.setColor(1, 0.45, 0.05, reactorGlow * 0.15 * (0.7 + math.sin(time * 1.5) * 0.3))
    love.graphics.rectangle("fill", 0, screen.HEIGHT * 0.6, screen.WIDTH, screen.HEIGHT * 0.4)
    -- Pulsing core light from ahead (bottom of screen)
    love.graphics.setColor(1, 0.6, 0.2, reactorGlow * 0.08 * (0.5 + math.sin(time * 2) * 0.5))
    love.graphics.circle("fill", screen.WIDTH / 2, screen.HEIGHT + 50, 300)
  end

  -- Floating debris / sparks (constant throughout)
  for i = 0, 5 do
    local dx = math.sin(time * 1.2 + i * 7) * screen.WIDTH * 0.4 + screen.WIDTH / 2
    local dy = (time * 120 + i * 133) % screen.HEIGHT
    local sparkSize = 1 + math.sin(time * 5 + i) * 0.5
    love.graphics.setColor(0.8 + depth * 0.2, 0.5 + depth * 0.3, 0.2, 0.6)
    love.graphics.circle("fill", dx, dy, sparkSize)
  end

  -- ============================================================
  -- BOSS BODY
  -- ============================================================
  love.graphics.push()
  love.graphics.translate(sb.x, sb.y)

  -- Phase-based core colors
  local phaseColors = {
    {0.3, 0.3, 0.4},   -- Phase 1: Cold steel
    {0.2, 0.15, 0.5},  -- Phase 2: Deep purple energy
    {0.1, 0.6, 0.4},   -- Phase 3: Reactor green
    {0.7, 0.2, 0.2}    -- Phase 4: Angry red
  }
  local baseColor = phaseColors[sb.phase] or phaseColors[1]

  -- Outer sphere shell
  local shellPulse = 0.85 + math.sin(time * 2) * 0.15
  love.graphics.setColor(baseColor[1] * shellPulse * alpha, baseColor[2] * shellPulse * alpha, baseColor[3] * shellPulse * alpha, alpha)
  love.graphics.circle("fill", 0, 0, sb.width / 2)

  -- Inner glow ring
  love.graphics.setColor(baseColor[1] * 1.4, baseColor[2] * 1.4, baseColor[3] * 1.4, 0.3 * alpha)
  love.graphics.circle("line", 0, 0, sb.width / 2 - 8)
  love.graphics.circle("line", 0, 0, sb.width / 2 - 12)

  -- Surface tech lines (rotating)
  love.graphics.setColor(0.5, 0.5, 0.6, 0.4 * alpha)
  love.graphics.setLineWidth(1)
  for i = 0, 7 do
    local angle = (i / 8) * math.pi * 2 + time * 0.3
    local r1 = sb.width / 2 - 15
    local r2 = sb.width / 2 - 5
    love.graphics.line(math.cos(angle) * r1, math.sin(angle) * r1,
                       math.cos(angle) * r2, math.sin(angle) * r2)
  end

  -- Central eye/core
  local corePulse = 0.6 + math.abs(math.sin(time * 4)) * 0.4
  love.graphics.setColor(1, 0.8, 0.4, corePulse * alpha)
  love.graphics.circle("fill", 0, 0, 12)
  love.graphics.setColor(1, 1, 0.9, corePulse * 0.5 * alpha)
  love.graphics.circle("fill", 0, 0, 6)

  love.graphics.pop()

  -- ============================================================
  -- PHASE 1: ROTATING SHELL PLATES
  -- ============================================================
  if sb.phase == 1 and sb.shellPlates then
    for _, plate in ipairs(sb.shellPlates) do
      if plate.hp > 0 then
        local px = plate.x or (sb.x + math.cos(plate.angle) * plate.orbitRadius)
        local py = plate.y or (sb.y + math.sin(plate.angle) * plate.orbitRadius)

        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(plate.angle + math.pi / 2)

        -- Plate body
        local plateHP = plate.hp / 25
        love.graphics.setColor(0.35 * plateHP + 0.15, 0.3 * plateHP + 0.1, 0.4 * plateHP + 0.1, alpha)
        love.graphics.rectangle("fill", -18, -8, 36, 16)
        -- Armored edge
        love.graphics.setColor(0.5, 0.45, 0.55, alpha * 0.7)
        love.graphics.rectangle("line", -18, -8, 36, 16)
        -- Damage glow
        if plateHP < 0.5 then
          local dmgGlow = (1 - plateHP * 2) * (0.5 + math.sin(time * 6) * 0.5)
          love.graphics.setColor(1, 0.3, 0.1, dmgGlow * alpha)
          love.graphics.rectangle("fill", -15, -5, 30, 10)
        end

        love.graphics.pop()
      end
    end
  end

  -- ============================================================
  -- PHASE 2: GRAVITY TETHERS + LASER RING
  -- ============================================================
  if sb.phase == 2 then
    -- Gravity tethers (pulling fields)
    if sb.gravityTethers then
      for _, tether in ipairs(sb.gravityTethers) do
        if tether.active then
          local tx = tether.x or sb.x
          local ty = tether.y or sb.y
          local tRadius = tether.radius or 80

          -- Outer pull field
          local pullPulse = 0.3 + math.sin(time * 3 + tx * 0.1) * 0.2
          love.graphics.setColor(0.2, 0.3, 0.8, pullPulse * 0.2 * alpha)
          love.graphics.circle("fill", tx, ty, tRadius)

          -- Converging rings (pulling inward effect)
          for r = 0, 2 do
            local ringR = tRadius * (0.4 + r * 0.25) - (time * 30 + r * 20) % (tRadius * 0.3)
            if ringR > 0 then
              love.graphics.setColor(0.3, 0.5, 1, (1 - ringR / tRadius) * 0.4 * alpha)
              love.graphics.circle("line", tx, ty, ringR)
            end
          end

          -- Tether core
          love.graphics.setColor(0.5, 0.3, 1, 0.6 * alpha)
          love.graphics.circle("fill", tx, ty, 8)
        end
      end
    end

    -- Laser ring (sweeping beams from boss)
    if sb.laserRing then
      love.graphics.setLineWidth(3)
      for _, beam in ipairs(sb.laserRing) do
        if beam.active then
          local bAngle = beam.angle or 0
          local bLen = beam.length or 300
          local endX = sb.x + math.cos(bAngle) * bLen
          local endY = sb.y + math.sin(bAngle) * bLen

          -- Beam core
          love.graphics.setColor(1, 0.4, 0.1, 0.8 * alpha)
          love.graphics.line(sb.x, sb.y, endX, endY)
          -- Beam glow
          love.graphics.setColor(1, 0.6, 0.2, 0.3 * alpha)
          love.graphics.setLineWidth(7)
          love.graphics.line(sb.x, sb.y, endX, endY)
          love.graphics.setLineWidth(1)
        end
      end
      love.graphics.setLineWidth(1)
    end
  end

  -- ============================================================
  -- PHASE 3: PUZZLE NODES
  -- ============================================================
  if sb.phase == 3 and sb.puzzleNodes then
    for idx, node in ipairs(sb.puzzleNodes) do
      local nx = node.x or sb.x
      local ny = node.y or sb.y

      if node.solved then
        -- Solved node: green, inert
        love.graphics.setColor(0.1, 0.7, 0.3, 0.6 * alpha)
        love.graphics.circle("fill", nx, ny, 14)
        love.graphics.setColor(0.2, 1, 0.5, 0.3 * alpha)
        love.graphics.circle("line", nx, ny, 18)
      else
        -- Active node
        local isTarget = (sb.puzzleSequenceIndex and sb.puzzleOrder and
                          sb.puzzleOrder[sb.puzzleSequenceIndex] == idx)

        if isTarget then
          -- Current target: bright flashing indicator
          local flash = 0.6 + math.sin(time * 8) * 0.4
          love.graphics.setColor(1, 1, 0.3, flash * alpha)
          love.graphics.circle("fill", nx, ny, 16)
          love.graphics.setColor(1, 1, 0.6, flash * 0.5 * alpha)
          love.graphics.circle("fill", nx, ny, 22)
          -- Targeting diamond
          love.graphics.setColor(1, 1, 0, flash * alpha)
          love.graphics.setLineWidth(2)
          love.graphics.polygon("line",
            nx, ny - 24, nx + 16, ny, nx, ny + 24, nx - 16, ny)
          love.graphics.setLineWidth(1)
        else
          -- Inactive node: dim, waiting
          love.graphics.setColor(0.4, 0.4, 0.5, 0.5 * alpha)
          love.graphics.circle("fill", nx, ny, 12)
          love.graphics.setColor(0.5, 0.5, 0.6, 0.3 * alpha)
          love.graphics.circle("line", nx, ny, 16)
        end
      end

      -- Node index label
      love.graphics.setColor(1, 1, 1, 0.7 * alpha)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf(tostring(idx), nx - 10, ny - 5, 20, "center")
    end

    -- Puzzle drones
    if sb.puzzleDrones then
      for _, drone in ipairs(sb.puzzleDrones) do
        if drone.active and drone.hp > 0 then
          love.graphics.push()
          love.graphics.translate(drone.x, drone.y)

          -- Drone body
          love.graphics.setColor(0.35, 0.25, 0.15, alpha)
          love.graphics.polygon("fill", 0, -10, 8, 4, 5, 10, -5, 10, -8, 4)
          -- Engine glow
          love.graphics.setColor(0.8, 0.3, 0.1, 0.6 * alpha)
          love.graphics.circle("fill", 0, 11, 3)

          love.graphics.pop()
        end
      end
    end

    -- Sequence progress indicator
    if sb.puzzleSequenceIndex and sb.puzzleOrder then
      local total = #sb.puzzleOrder
      local current = sb.puzzleSequenceIndex
      love.graphics.setColor(0.1, 0.8, 0.4, 0.8)
      love.graphics.setFont(love.graphics.newFont(12))
      love.graphics.printf("SEQUENCE: " .. (current - 1) .. "/" .. total,
        screen.WIDTH / 2 - 80, 60, 160, "center")
    end
  end

  -- ============================================================
  -- PHASE 4: THE MIRROR CLONE
  -- ============================================================
  if sb.phase == 4 and sb.clone then
    local c = sb.clone
    love.graphics.push()
    love.graphics.translate(c.x, c.y)

    if c.stunned then
      -- Stunned clone: flickering, drifting
      local flicker = math.sin(time * 20) > 0 and 1 or 0.2
      love.graphics.setColor(0.4 * flicker, 0.6 * flicker, 1 * flicker, 0.7 * alpha)

      -- Glitchy ship shape
      local jitterX = math.random(-3, 3)
      local jitterY = math.random(-3, 3)
      love.graphics.translate(jitterX, jitterY)

      -- Stunned ship body (inverted arwing silhouette)
      love.graphics.polygon("fill", 0, 12, -14, -8, -6, -4, 0, -14, 6, -4, 14, -8)
      -- Stun sparks
      love.graphics.setColor(0.5, 0.7, 1, flicker * 0.8)
      love.graphics.circle("fill", math.random(-10, 10), math.random(-10, 10), 2)
      love.graphics.circle("fill", math.random(-10, 10), math.random(-10, 10), 2)

      -- "STUNNED" label
      love.graphics.setColor(0.5, 0.8, 1, 0.8)
      love.graphics.setFont(love.graphics.newFont(10))
      love.graphics.printf("STUNNED", -30, -28, 60, "center")
    else
      -- Active clone: ghostly mirror of player
      local ghostPulse = 0.6 + math.sin(time * 3) * 0.2

      -- Ghostly body (inverted arwing - nose points DOWN because it mirrors)
      love.graphics.setColor(0.3, 0.5, 0.9, ghostPulse * alpha)
      love.graphics.polygon("fill", 0, 12, -14, -8, -6, -4, 0, -14, 6, -4, 14, -8)

      -- Mirror aura
      love.graphics.setColor(0.4, 0.6, 1, ghostPulse * 0.3 * alpha)
      love.graphics.circle("line", 0, 0, 22)
      love.graphics.circle("line", 0, 0, 26)

      -- Ghostly trail lines
      love.graphics.setColor(0.3, 0.5, 1, 0.15 * alpha)
      for i = 1, 3 do
        local trailY = -i * 12
        love.graphics.polygon("fill",
          0, 12 + trailY, -14 + i * 2, -8 + trailY, 14 - i * 2, -8 + trailY)
      end

      -- Red eye
      local eyeGlow = 0.7 + math.sin(time * 5) * 0.3
      love.graphics.setColor(1, 0.2, 0.2, eyeGlow * alpha)
      love.graphics.circle("fill", 0, -2, 3)
    end

    love.graphics.pop()

    -- Clone health bar (only when stunned and damageable)
    if c.stunned then
      local cloneHP = (c.hp or 100) / 100
      local cloneBarW = 120
      local cloneBarX = c.x - cloneBarW / 2
      local cloneBarY = c.y - 40

      love.graphics.setColor(0.05, 0.05, 0.15, 0.8)
      love.graphics.rectangle("fill", cloneBarX - 1, cloneBarY - 1, cloneBarW + 2, 8)
      love.graphics.setColor(0.3, 0.5, 1)
      love.graphics.rectangle("fill", cloneBarX, cloneBarY, cloneBarW * cloneHP, 6)
      love.graphics.setColor(0.6, 0.8, 1, 0.8)
      love.graphics.setFont(love.graphics.newFont(8))
      love.graphics.printf("MIRROR", cloneBarX, cloneBarY - 12, cloneBarW, "center")
    end
  end

  -- ============================================================
  -- PHASE TRANSITION FLASH
  -- ============================================================
  if sb.phaseTransitioning then
    local flash = math.abs(math.sin(time * 10))
    love.graphics.setColor(1, 1, 1, flash * 0.3)
    love.graphics.circle("fill", sb.x, sb.y, 120)
  end

  -- ============================================================
  -- ATTACK WARNING
  -- ============================================================
  local warning, progress = sphereboss.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.5, 0.1, 0.9)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    if progress then
      love.graphics.setColor(0.15, 0.08, 0.02, 0.8)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200, 10)
      love.graphics.setColor(1, 0.5, 0.1)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200 * progress, 10)
    end
  end

  -- ============================================================
  -- HEALTH BAR
  -- ============================================================
  local healthPct = sb.health / sb.maxHealth
  local barWidth = 320
  local barX = screen.WIDTH / 2 - barWidth / 2
  local barY = 28

  -- Background
  love.graphics.setColor(0.05, 0.05, 0.1, 0.9)
  love.graphics.rectangle("fill", barX - 2, barY - 2, barWidth + 4, 16)

  -- Phase segment colors
  local segColors = {
    {0.4, 0.4, 0.5},   -- Phase 1: Steel
    {0.4, 0.2, 0.7},   -- Phase 2: Purple
    {0.1, 0.7, 0.4},   -- Phase 3: Green
    {0.8, 0.2, 0.2}    -- Phase 4: Red
  }

  -- Draw health with phase segments
  local thresholds = {1.0, 0.75, 0.45, 0.25, 0}
  for i = 1, 4 do
    local segStart = 1 - thresholds[i]
    local segEnd = 1 - thresholds[i + 1]
    if healthPct > segStart then
      local fillEnd = math.min(healthPct, segEnd)
      local segColor = segColors[i]
      love.graphics.setColor(segColor[1], segColor[2], segColor[3])
      love.graphics.rectangle("fill",
        barX + segStart * barWidth, barY,
        (fillEnd - segStart) * barWidth, 12)
    end
    -- Segment divider
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", barX + (1 - thresholds[i + 1]) * barWidth - 1, barY, 2, 12)
  end

  -- Phase indicator
  local phaseName = sphereboss.getPhaseName()
  love.graphics.setColor(0.8, 0.8, 0.9, 0.9)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. sb.phase .. "/4 - " .. phaseName, barX, barY + 14, barWidth, "center")

  -- Boss name
  love.graphics.setColor(0.7, 0.75, 0.9)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf("THE SPHERE", barX, barY - 20, barWidth, "center")
end

------------------------------------------------------------------------
-- SYNESTHESIA INSTALLATION  (10-phase endgame raid — GPU Core Architect)
------------------------------------------------------------------------
function M.drawSynesthesia()
  if not synesthesia.isActive() and not synesthesia.isBossActive() then return end

  local time = love.timer.getTime()
  local sb = synesthesia.boss

  -- ===========================================================
  -- MUSIC VISUALIZATION BACKGROUND (drawn behind everything)
  -- ===========================================================

  -- Grid lines pulsing with simulated music
  for _, line in ipairs(synesthesia.vizGridLines) do
    local hue = (synesthesia.vizHue + line.y / screen.HEIGHT * 0.3) % 1.0
    local r, g, b = M.hsvToRgb(hue, 0.6, 0.8)
    love.graphics.setColor(r, g, b, line.alpha)
    love.graphics.setLineWidth(1)
    love.graphics.line(0, line.y, screen.WIDTH, line.y)
  end

  -- Frequency spectrum bars (bottom of screen)
  local barCount = #synesthesia.vizBars
  local barSpacing = screen.WIDTH / barCount
  for i, bar in ipairs(synesthesia.vizBars) do
    local hue = (bar.hue + synesthesia.vizHue) % 1.0
    local r, g, b = M.hsvToRgb(hue, 0.8, 0.9)
    -- Outer glow
    love.graphics.setColor(r, g, b, 0.15)
    love.graphics.rectangle("fill",
      (i - 1) * barSpacing + 1, screen.HEIGHT - bar.height - 6,
      barSpacing - 2, bar.height + 6)
    -- Main bar
    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.rectangle("fill",
      (i - 1) * barSpacing + 2, screen.HEIGHT - bar.height,
      barSpacing - 4, bar.height)
    -- Bright cap
    love.graphics.setColor(r, g, b, 0.7)
    love.graphics.rectangle("fill",
      (i - 1) * barSpacing + 2, screen.HEIGHT - bar.height,
      barSpacing - 4, 3)
  end

  -- Oscilloscope waveform (mid-screen)
  if #synesthesia.vizWaveforms > 1 then
    local whue = (synesthesia.vizHue + 0.5) % 1.0
    local wr, wg, wb = M.hsvToRgb(whue, 0.5, 0.9)
    love.graphics.setColor(wr, wg, wb, 0.2 * synesthesia.vizIntensity)
    love.graphics.setLineWidth(2)
    for i = 2, #synesthesia.vizWaveforms do
      local p1 = synesthesia.vizWaveforms[i - 1]
      local p2 = synesthesia.vizWaveforms[i]
      love.graphics.line(p1.x, p1.y, p2.x, p2.y)
    end
    love.graphics.setLineWidth(1)
  end

  -- Bass pulse flash overlay
  if synesthesia.vizBassHit then
    local flashAlpha = synesthesia.vizBassDecay / 0.3 * 0.08
    local hr, hg, hb = M.hsvToRgb(synesthesia.vizHue, 0.3, 1)
    love.graphics.setColor(hr, hg, hb, flashAlpha)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
  end

  -- Floating visualization particles
  for _, p in ipairs(synesthesia.vizParticles) do
    local alpha = (p.life / p.maxLife) * 0.6
    local pr, pg, pb = M.hsvToRgb(p.hue, 0.7, 1)
    love.graphics.setColor(pr, pg, pb, alpha)
    love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
  end

  -- ===========================================================
  -- TERRAIN HAZARDS
  -- ===========================================================

  -- Heatsink fins (Section 1)
  for _, fin in ipairs(synesthesia.heatsinkFins) do
    local glow = 0.3 + math.sin(time * 2 + fin.glowPhase) * 0.15
    local finColors = {
      {0.35, 0.4, 0.5},   -- Gunmetal
      {0.3, 0.35, 0.45},  -- Dark steel
      {0.4, 0.45, 0.5}    -- Light steel
    }
    local fc = finColors[fin.color] or finColors[1]

    if fin.doubleGap then
      -- Left wall
      love.graphics.setColor(fc[1], fc[2], fc[3], 0.9)
      love.graphics.rectangle("fill", 0, fin.y, fin.gapLeft1, fin.height)
      -- Middle wall
      love.graphics.rectangle("fill", fin.gapRight1, fin.y,
        fin.gapLeft2 - fin.gapRight1, fin.height)
      -- Right wall
      love.graphics.rectangle("fill", fin.gapRight2, fin.y,
        screen.WIDTH - fin.gapRight2, fin.height)
      -- Edge glow
      love.graphics.setColor(0.4, 0.7, 1, glow)
      love.graphics.line(0, fin.y + fin.height, fin.gapLeft1, fin.y + fin.height)
      love.graphics.line(fin.gapRight1, fin.y + fin.height, fin.gapLeft2, fin.y + fin.height)
      love.graphics.line(fin.gapRight2, fin.y + fin.height, screen.WIDTH, fin.y + fin.height)
    else
      -- Left wall
      love.graphics.setColor(fc[1], fc[2], fc[3], 0.9)
      love.graphics.rectangle("fill", 0, fin.y, fin.gapLeft, fin.height)
      -- Right wall
      love.graphics.rectangle("fill", fin.gapRight, fin.y,
        screen.WIDTH - fin.gapRight, fin.height)
      -- Edge glow
      love.graphics.setColor(0.4, 0.7, 1, glow)
      love.graphics.line(0, fin.y + fin.height, fin.gapLeft, fin.y + fin.height)
      love.graphics.line(fin.gapRight, fin.y + fin.height, screen.WIDTH, fin.y + fin.height)
      -- Fin ridge lines (aesthetic detail)
      love.graphics.setColor(fc[1] * 0.7, fc[2] * 0.7, fc[3] * 0.7, 0.5)
      for ridge = 0, fin.gapLeft, 40 do
        love.graphics.line(ridge, fin.y, ridge, fin.y + fin.height)
      end
      for ridge = fin.gapRight, screen.WIDTH, 40 do
        love.graphics.line(ridge, fin.y, ridge, fin.y + fin.height)
      end
    end
  end

  -- Circuit traces with electrical arcs (Sections 1 & 2)
  for _, trace in ipairs(synesthesia.circuitTraces) do
    -- Copper trace line
    love.graphics.setColor(0.7, 0.5, 0.2, 0.6)
    love.graphics.setLineWidth(trace.width)
    love.graphics.line(trace.startX, trace.y, trace.endX, trace.y)
    love.graphics.setLineWidth(1)

    -- Warning indicator before arc
    if trace.warned and not trace.arcActive then
      local warnPulse = 0.4 + math.sin(time * 8) * 0.4
      love.graphics.setColor(1, 0.8, 0, warnPulse)
      love.graphics.circle("fill", (trace.startX + trace.endX) / 2, trace.y, 8)
      love.graphics.setColor(1, 0.3, 0, warnPulse * 0.6)
      love.graphics.printf("!", (trace.startX + trace.endX) / 2 - 10, trace.y - 8, 20, "center")
    end

    -- Active electrical arc
    if trace.arcActive then
      local segments = 12
      local midY = trace.y
      love.graphics.setColor(0.3, 0.8, 1, trace.arcIntensity * 0.8)
      love.graphics.setLineWidth(2)
      local prevX, prevY = trace.startX, midY
      for s = 1, segments do
        local t = s / segments
        local sx = trace.startX + (trace.endX - trace.startX) * t
        local sy = midY + (math.random() - 0.5) * 30 * trace.arcIntensity
        love.graphics.line(prevX, prevY, sx, sy)
        prevX, prevY = sx, sy
      end
      love.graphics.setLineWidth(1)
      -- Bright core
      love.graphics.setColor(0.7, 0.95, 1, trace.arcIntensity * 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.line(trace.startX, trace.y, trace.endX, trace.y)
    end
  end

  -- Capacitor boulders (Section 2)
  for _, boulder in ipairs(synesthesia.capacitorBoulders) do
    love.graphics.push()
    love.graphics.translate(boulder.x, boulder.y)
    love.graphics.rotate(boulder.rotation)
    -- Capacitor body (cylindrical look)
    love.graphics.setColor(0.3, 0.25, 0.15, 0.9)
    love.graphics.circle("fill", 0, 0, boulder.radius)
    -- Metal casing bands
    love.graphics.setColor(0.5, 0.5, 0.55, 0.8)
    love.graphics.circle("line", 0, 0, boulder.radius)
    love.graphics.circle("line", 0, 0, boulder.radius * 0.75)
    -- Polarity stripe
    love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
    love.graphics.rectangle("fill", -boulder.radius * 0.15, -boulder.radius, boulder.radius * 0.3, boulder.radius * 2)
    -- Voltage warning symbol
    love.graphics.setColor(1, 0.8, 0, 0.7)
    love.graphics.polygon("fill", 0, -boulder.radius * 0.4, -5, boulder.radius * 0.2, 5, boulder.radius * 0.2)
    love.graphics.pop()
  end

  -- Laser security grids (Sections 2 & 3)
  for _, grid in ipairs(synesthesia.laserGrids) do
    if grid.type == "horizontal" then
      local pulse = 0.6 + math.sin(time * 6) * 0.3
      -- Left beam
      love.graphics.setColor(1, 0.15, 0.15, pulse * 0.7)
      love.graphics.setLineWidth(3)
      love.graphics.line(0, grid.y, grid.gapX - grid.gapWidth / 2, grid.y)
      -- Right beam
      love.graphics.line(grid.gapX + grid.gapWidth / 2, grid.y, screen.WIDTH, grid.y)
      -- Glow
      love.graphics.setColor(1, 0.1, 0.1, pulse * 0.2)
      love.graphics.setLineWidth(12)
      love.graphics.line(0, grid.y, grid.gapX - grid.gapWidth / 2, grid.y)
      love.graphics.line(grid.gapX + grid.gapWidth / 2, grid.y, screen.WIDTH, grid.y)
      love.graphics.setLineWidth(1)
      -- Gap indicator
      love.graphics.setColor(0, 1, 0, 0.3 + math.sin(time * 4) * 0.2)
      love.graphics.rectangle("line", grid.gapX - grid.gapWidth / 2, grid.y - 15, grid.gapWidth, 30)

    elseif grid.type == "vertical" then
      local pulse = 0.6 + math.sin(time * 6) * 0.3
      -- Top beam
      love.graphics.setColor(1, 0.15, 0.15, pulse * 0.7)
      love.graphics.setLineWidth(3)
      love.graphics.line(grid.x, 0, grid.x, grid.gapY - grid.gapHeight / 2)
      -- Bottom beam
      love.graphics.line(grid.x, grid.gapY + grid.gapHeight / 2, grid.x, screen.HEIGHT)
      love.graphics.setLineWidth(1)

    elseif grid.type == "cross" then
      local pulse = 0.6 + math.sin(time * 6) * 0.3
      love.graphics.setColor(1, 0.15, 0.15, pulse * 0.7)
      love.graphics.setLineWidth(grid.beamWidth)
      -- Two crossing beams
      local len = math.max(screen.WIDTH, screen.HEIGHT)
      local dx1 = math.cos(grid.angle) * len
      local dy1 = math.sin(grid.angle) * len
      love.graphics.line(grid.cx - dx1, grid.cy - dy1, grid.cx + dx1, grid.cy + dy1)
      local dx2 = math.cos(grid.angle + math.pi / 2) * len
      local dy2 = math.sin(grid.angle + math.pi / 2) * len
      love.graphics.line(grid.cx - dx2, grid.cy - dy2, grid.cx + dx2, grid.cy + dy2)
      love.graphics.setLineWidth(1)
    end
  end

  -- VRM thermal explosions (Section 3)
  for _, vrm in ipairs(synesthesia.vrmExplosions) do
    if not vrm.exploding then
      -- Charging warning circle
      local chargePct = 1 - vrm.chargeTimer / 1.8
      local warnAlpha = vrm.warned and (0.3 + math.sin(time * 10) * 0.3) or 0.1
      -- Danger zone circle
      love.graphics.setColor(1, 0.3, 0, warnAlpha)
      love.graphics.circle("line", vrm.x, vrm.y, vrm.maxRadius * chargePct)
      -- Fill growing
      love.graphics.setColor(1, 0.4, 0.1, warnAlpha * 0.3)
      love.graphics.circle("fill", vrm.x, vrm.y, vrm.maxRadius * chargePct * 0.5)
      -- Center dot
      love.graphics.setColor(1, 0.6, 0, warnAlpha * 0.8)
      love.graphics.circle("fill", vrm.x, vrm.y, 5)
    else
      -- Explosion!
      local fade = vrm.explosionTimer / 0.5
      love.graphics.setColor(1, 0.5, 0, fade * 0.6)
      love.graphics.circle("fill", vrm.x, vrm.y, vrm.radius)
      love.graphics.setColor(1, 0.8, 0.3, fade * 0.8)
      love.graphics.circle("fill", vrm.x, vrm.y, vrm.radius * 0.6)
      love.graphics.setColor(1, 1, 0.7, fade)
      love.graphics.circle("fill", vrm.x, vrm.y, vrm.radius * 0.2)
    end
  end

  -- PCB bridge sections (Section 3)
  for _, bridge in ipairs(synesthesia.pcbBridges) do
    if bridge.integrity > 0 then
      local bAlpha = bridge.integrity * 0.8
      -- Bridge platform
      love.graphics.setColor(0.15, 0.3, 0.12, bAlpha)
      love.graphics.rectangle("fill",
        bridge.x - bridge.width / 2, bridge.y - bridge.height / 2,
        bridge.width, bridge.height)
      -- Circuit traces on bridge
      love.graphics.setColor(0.6, 0.5, 0.2, bAlpha * 0.5)
      for tr = 0, bridge.width, 30 do
        love.graphics.line(
          bridge.x - bridge.width / 2 + tr, bridge.y - bridge.height / 2,
          bridge.x - bridge.width / 2 + tr, bridge.y + bridge.height / 2)
      end
      -- Crumbling warning
      if bridge.collapsing and bridge.collapseDelay > 0 then
        local shake = math.sin(time * 20) * 2 * (1 - bridge.collapseDelay / 0.8)
        love.graphics.setColor(1, 0.3, 0, 0.5)
        love.graphics.rectangle("line",
          bridge.x - bridge.width / 2 + shake, bridge.y - bridge.height / 2,
          bridge.width, bridge.height)
      end
      -- Crumbling gaps
      if bridge.integrity < 0.7 then
        love.graphics.setColor(0, 0, 0, 1 - bridge.integrity)
        local holes = math.floor((1 - bridge.integrity) * 8)
        for h = 1, holes do
          local hx = bridge.x - bridge.width / 2 + math.sin(h * 7.3) * bridge.width * 0.4 + bridge.width / 2
          local hy = bridge.y + math.cos(h * 3.1) * bridge.height * 0.3
          love.graphics.circle("fill", hx, hy, 8 + (1 - bridge.integrity) * 12)
        end
      end
    end
  end

  -- ===========================================================
  -- PUZZLE OVERLAYS
  -- ===========================================================
  if synesthesia.puzzleActive and synesthesia.puzzleData then
    -- Puzzle timer bar
    local pTimerPct = synesthesia.puzzleTimer / 15
    love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, 60, 200, 12)
    local timerColor = pTimerPct > 0.3 and {0.2, 0.8, 1} or {1, 0.3, 0.2}
    love.graphics.setColor(timerColor[1], timerColor[2], timerColor[3], 0.8)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, 60, 200 * pTimerPct, 12)

    -- Puzzle type label
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(love.graphics.newFont(11))
    local puzzleLabels = {
      trace_route = "TRACE ROUTE: Shoot nodes in order!",
      frequency = "FREQUENCY MATCH: Stay in the zone!",
      color_decode = "COLOR DECODE: Repeat the sequence!",
      memory_bus = "MEMORY BUS: Fly through waypoints!"
    }
    love.graphics.printf(puzzleLabels[synesthesia.puzzleType] or "PUZZLE",
      screen.WIDTH / 2 - 150, 45, 300, "center")

    -- Trace Route puzzle: colored numbered nodes
    if synesthesia.puzzleType == "trace_route" then
      local nodeColors = {
        red = {1, 0.2, 0.2},
        green = {0.2, 1, 0.2},
        blue = {0.3, 0.5, 1},
        yellow = {1, 1, 0.2}
      }
      -- Draw connecting lines between nodes
      love.graphics.setColor(0.4, 0.4, 0.5, 0.3)
      love.graphics.setLineWidth(1)
      for i = 2, #synesthesia.puzzleData.nodes do
        local n1 = synesthesia.puzzleData.nodes[i - 1]
        local n2 = synesthesia.puzzleData.nodes[i]
        love.graphics.line(n1.x, n1.y, n2.x, n2.y)
      end
      -- Draw nodes
      for _, node in ipairs(synesthesia.puzzleData.nodes) do
        local nc = nodeColors[node.color] or {1, 1, 1}
        local pulse = 0.7 + math.sin(node.pulsePhase) * 0.3
        if node.hit then
          -- Completed node: dimmed with checkmark
          love.graphics.setColor(nc[1] * 0.3, nc[2] * 0.3, nc[3] * 0.3, 0.5)
          love.graphics.circle("fill", node.x, node.y, node.radius)
          love.graphics.setColor(0, 1, 0, 0.8)
          love.graphics.circle("line", node.x, node.y, node.radius + 3)
        elseif node.order == synesthesia.puzzleData.currentTarget then
          -- Current target: bright with arrow indicator
          love.graphics.setColor(nc[1], nc[2], nc[3], pulse)
          love.graphics.circle("fill", node.x, node.y, node.radius + 3)
          love.graphics.setColor(1, 1, 1, pulse * 0.8)
          love.graphics.circle("line", node.x, node.y, node.radius + 6)
          -- Pulsing ring
          local ringR = node.radius + 10 + math.sin(time * 5) * 4
          love.graphics.setColor(nc[1], nc[2], nc[3], 0.3)
          love.graphics.circle("line", node.x, node.y, ringR)
        else
          -- Future node: visible but subdued
          love.graphics.setColor(nc[1] * 0.5, nc[2] * 0.5, nc[3] * 0.5, 0.4)
          love.graphics.circle("fill", node.x, node.y, node.radius)
          love.graphics.setColor(nc[1] * 0.6, nc[2] * 0.6, nc[3] * 0.6, 0.5)
          love.graphics.circle("line", node.x, node.y, node.radius)
        end
        -- Node number
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.printf(tostring(node.order), node.x - 10, node.y - 7, 20, "center")
      end

    -- Frequency match puzzle: oscillating target zone
    elseif synesthesia.puzzleType == "frequency" then
      local pd = synesthesia.puzzleData
      local targetY = screen.HEIGHT / 2 + math.sin(time * pd.targetFreq) * pd.targetAmplitude
      -- Target zone
      love.graphics.setColor(0.2, 0.8, 1, 0.2)
      love.graphics.rectangle("fill", 0, targetY - pd.zoneWidth / 2, screen.WIDTH, pd.zoneWidth)
      love.graphics.setColor(0.3, 0.9, 1, 0.5)
      love.graphics.setLineWidth(2)
      love.graphics.line(0, targetY - pd.zoneWidth / 2, screen.WIDTH, targetY - pd.zoneWidth / 2)
      love.graphics.line(0, targetY + pd.zoneWidth / 2, screen.WIDTH, targetY + pd.zoneWidth / 2)
      love.graphics.setLineWidth(1)
      -- Match progress
      local matchPct = pd.matchTimer / pd.matchRequired
      love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 60, 80, 120, 10)
      love.graphics.setColor(0.2, 1, 0.5, 0.8)
      love.graphics.rectangle("fill", screen.WIDTH / 2 - 60, 80, 120 * matchPct, 10)
      love.graphics.setColor(1, 1, 1, 0.7)
      love.graphics.setFont(love.graphics.newFont(9))
      love.graphics.printf("LOCK ON", screen.WIDTH / 2 - 60, 92, 120, "center")

    -- Color decode puzzle: sequence + colored targets
    elseif synesthesia.puzzleType == "color_decode" then
      local pd = synesthesia.puzzleData
      -- Show sequence being flashed
      if pd.showingSequence and pd.flashIndex <= #pd.sequence then
        local fc = pd.sequence[pd.flashIndex]
        love.graphics.setColor(fc[1], fc[2], fc[3], 0.15)
        love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
        -- Sequence indicator dots
        for si = 1, #pd.sequence do
          local dotX = screen.WIDTH / 2 - (#pd.sequence * 15) / 2 + (si - 1) * 15
          if si == pd.flashIndex then
            love.graphics.setColor(1, 1, 1, 0.9)
          elseif si < pd.flashIndex then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
          else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
          end
          love.graphics.circle("fill", dotX + 7, 100, 4)
        end
      end
      -- Draw color targets
      if not pd.showingSequence then
        for _, target in ipairs(pd.targets) do
          local tc = target.color
          local tPulse = 0.6 + math.sin(target.pulsePhase + time * 3) * 0.3
          love.graphics.setColor(tc[1], tc[2], tc[3], tPulse)
          love.graphics.circle("fill", target.x, target.y, target.radius)
          love.graphics.setColor(1, 1, 1, 0.4)
          love.graphics.circle("line", target.x, target.y, target.radius + 3)
          -- Label
          love.graphics.setColor(1, 1, 1, 0.8)
          love.graphics.setFont(love.graphics.newFont(9))
          love.graphics.printf(target.colorName, target.x - 25, target.y + target.radius + 5, 50, "center")
        end
        -- Progress indicator
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.setFont(love.graphics.newFont(10))
        love.graphics.printf("Step " .. pd.currentStep .. "/" .. #pd.sequence,
          screen.WIDTH / 2 - 50, 100, 100, "center")
      end

    -- Memory bus puzzle: waypoints to fly through
    elseif synesthesia.puzzleType == "memory_bus" then
      local pd = synesthesia.puzzleData
      for i, wp in ipairs(pd.waypoints) do
        if wp.reached then
          love.graphics.setColor(0, 0.8, 0.3, 0.4)
          love.graphics.circle("line", wp.x, wp.y, wp.radius)
        elseif i == pd.currentWaypoint and not pd.showingPattern then
          -- Active waypoint: bright pulsing
          local wpPulse = 0.5 + math.sin(time * 5) * 0.3
          love.graphics.setColor(0.2, 0.7, 1, wpPulse * 0.3)
          love.graphics.circle("fill", wp.x, wp.y, wp.radius)
          love.graphics.setColor(0.3, 0.8, 1, wpPulse)
          love.graphics.circle("line", wp.x, wp.y, wp.radius)
          -- Arrow pointing to it
          love.graphics.setColor(1, 1, 1, 0.7)
          love.graphics.printf(tostring(i), wp.x - 10, wp.y - 7, 20, "center")
        else
          -- Future or showing pattern
          local alpha = pd.showingPattern and 0.6 or 0.2
          love.graphics.setColor(0.4, 0.5, 0.6, alpha)
          love.graphics.circle("line", wp.x, wp.y, wp.radius)
          love.graphics.setColor(1, 1, 1, alpha * 0.6)
          love.graphics.setFont(love.graphics.newFont(10))
          love.graphics.printf(tostring(i), wp.x - 10, wp.y - 7, 20, "center")
        end
      end
      if pd.showingPattern then
        love.graphics.setColor(1, 1, 0.5, 0.8 + math.sin(time * 3) * 0.2)
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.printf("MEMORIZE THE PATTERN",
          screen.WIDTH / 2 - 120, screen.HEIGHT / 2 - 60, 240, "center")
      end
    end
  end

  -- ===========================================================
  -- BOSS BODY & EFFECTS
  -- ===========================================================
  if sb and sb.active then
    local alpha = sb.fadeAlpha or 1

    -- Phase color progression (chromatic GPU aesthetic)
    local phaseColors = {
      {0.3, 0.9, 0.4},    -- 1: Shader Storm (green)
      {0.2, 0.6, 1.0},    -- 2: Pipeline (blue)
      {0.9, 0.3, 0.9},    -- 3: Rasterizer (magenta)
      {0.6, 0.2, 0.9},    -- 4: Tensor Core (purple)
      {0.2, 1.0, 0.8},    -- 5: Ray Trace (cyan)
      {1.0, 0.5, 0.1},    -- 6: Buffer Overflow (orange)
      {1.0, 0.8, 0.1},    -- 7: Overclock (gold)
      {1.0, 0.15, 0.15},  -- 8: Kernel Panic (red)
      {1.0, 0.4, 0.2},    -- 9: Thermal Throttle (fire)
      {1.0, 1.0, 1.0},    -- 10: Ascension (white)
    }
    local pc = phaseColors[sb.phase] or {1, 1, 1}

    -- Overclock zones (Phase 7+)
    if sb.overclockActive then
      for _, zone in ipairs(sb.overclockZones) do
        local zPulse = 0.3 + math.sin(time * 4 + zone.x * 0.02) * 0.2
        -- Danger aura
        love.graphics.setColor(1, 0.6, 0, zPulse * 0.2)
        love.graphics.circle("fill", zone.x, zone.y, zone.radius + 10)
        -- Core
        love.graphics.setColor(1, 0.8, 0.2, zPulse * 0.4)
        love.graphics.circle("fill", zone.x, zone.y, zone.radius)
        -- Clock symbol
        love.graphics.setColor(1, 0.9, 0.4, zPulse * 0.6)
        love.graphics.circle("line", zone.x, zone.y, zone.radius * 0.5)
        local handAngle = time * 3
        love.graphics.line(zone.x, zone.y,
          zone.x + math.cos(handAngle) * zone.radius * 0.4,
          zone.y + math.sin(handAngle) * zone.radius * 0.4)
      end
    end

    -- Raytrace beams (Phase 5+)
    for _, beam in ipairs(sb.raytraceBeams) do
      love.graphics.setColor(0.2, 1, 0.8, 0.6)
      love.graphics.setLineWidth(3)
      love.graphics.line(beam.x, beam.y, beam.x + beam.dx * 40, beam.y + beam.dy * 40)
      -- Bright tip
      love.graphics.setColor(0.5, 1, 0.9, 0.9)
      love.graphics.circle("fill", beam.x, beam.y, 4)
      -- Trail glow
      love.graphics.setColor(0.2, 1, 0.8, 0.15)
      love.graphics.setLineWidth(8)
      love.graphics.line(beam.x, beam.y, beam.x + beam.dx * 40, beam.y + beam.dy * 40)
      love.graphics.setLineWidth(1)
    end

    -- Thermal waves (Phase 9+)
    for _, wave in ipairs(sb.thermalWaves) do
      local wAlpha = wave.life / wave.maxLife
      -- Fire wave ring
      love.graphics.setColor(1, 0.3, 0.1, wAlpha * 0.5)
      love.graphics.setLineWidth(wave.width)
      love.graphics.circle("line", wave.x, wave.y, wave.radius)
      -- Inner glow
      love.graphics.setColor(1, 0.6, 0.2, wAlpha * 0.2)
      love.graphics.setLineWidth(wave.width * 2)
      love.graphics.circle("line", wave.x, wave.y, wave.radius)
      love.graphics.setLineWidth(1)
    end

    -- Buffer flood projectiles (Phase 6)
    for _, proj in ipairs(sb.bufferProjectiles) do
      love.graphics.setColor(1, 0.5, 0.1, 0.7)
      love.graphics.rectangle("fill", proj.x - 4, proj.y - 4, 8, 8)
      love.graphics.setColor(1, 0.8, 0.3, 0.4)
      love.graphics.rectangle("fill", proj.x - 6, proj.y - 6, 12, 12)
    end

    -- Rasterizer sweep beam (Phase 3)
    if sb.rasterActive then
      love.graphics.setColor(0.9, 0.3, 0.9, 0.6)
      love.graphics.setLineWidth(4)
      love.graphics.line(sb.rasterX, 0, sb.rasterX, screen.HEIGHT)
      -- Glow
      love.graphics.setColor(0.9, 0.3, 0.9, 0.15)
      love.graphics.setLineWidth(20)
      love.graphics.line(sb.rasterX, 0, sb.rasterX, screen.HEIGHT)
      love.graphics.setLineWidth(1)
      -- Scanning line indicator at top
      love.graphics.setColor(1, 0.5, 1, 0.8)
      love.graphics.polygon("fill", sb.rasterX, 5, sb.rasterX - 6, 0, sb.rasterX + 6, 0)
    end

    -- Kernel Panic telegraph (Phase 8)
    if sb.kernelPanicCharging then
      local chargePct = 1 - sb.kernelPanicTimer / sb.kernelPanicDuration
      local flashRate = 4 + chargePct * 12
      local flash = 0.3 + math.sin(time * flashRate) * 0.3

      -- Target zone (huge expanding circle)
      love.graphics.setColor(1, 0, 0, flash * 0.3 * chargePct)
      love.graphics.circle("fill", sb.kernelPanicTargetX, sb.kernelPanicTargetY,
        sb.kernelPanicRadius * chargePct)
      -- Danger border
      love.graphics.setColor(1, 0.2, 0.2, flash * 0.8)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", sb.kernelPanicTargetX, sb.kernelPanicTargetY,
        sb.kernelPanicRadius * chargePct)
      love.graphics.setLineWidth(1)
      -- Warning text
      love.graphics.setColor(1, 0.3, 0.3, flash)
      love.graphics.setFont(love.graphics.newFont(18))
      love.graphics.printf("KERNEL PANIC",
        sb.kernelPanicTargetX - 80, sb.kernelPanicTargetY - 12, 160, "center")
    end

    -- Tensor nodes (Phase 4+)
    for _, node in ipairs(sb.tensorNodes) do
      if node.active then
        local nx = sb.x + math.cos(node.angle) * node.dist
        local ny = sb.y + math.sin(node.angle) * node.dist
        -- Node body
        love.graphics.setColor(0.5, 0.2, 0.9, 0.8)
        love.graphics.circle("fill", nx, ny, 12)
        love.graphics.setColor(0.7, 0.4, 1, 0.6)
        love.graphics.circle("line", nx, ny, 14)
        -- Connection line to boss
        love.graphics.setColor(0.5, 0.2, 0.9, 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.line(sb.x, sb.y, nx, ny)
      end
    end

    -- Tensor gravity well visual (Phase 4)
    if sb.tensorActive and sb.tensorPullStrength > 0 then
      local gravAlpha = math.min(sb.tensorPullStrength / 300, 0.4)
      -- Swirling vortex rings
      for ring = 1, 4 do
        local ringR = 30 + ring * 40 + math.sin(time * 2 + ring) * 10
        love.graphics.setColor(0.5, 0.2, 0.9, gravAlpha / ring)
        love.graphics.circle("line", sb.x, sb.y, ringR)
      end
    end

    -- BOSS BODY (GPU Core Architect)
    love.graphics.push()
    love.graphics.translate(sb.x, sb.y)

    -- Phase transition glow
    if sb.phaseTransitioning then
      local tPulse = 0.5 + math.sin(time * 8) * 0.5
      love.graphics.setColor(pc[1], pc[2], pc[3], tPulse * 0.4)
      love.graphics.circle("fill", 0, 0, sb.width * 0.6)
    end

    -- Ascension aura (Phase 10)
    if sb.ascended then
      local auraPulse = 0.3 + math.sin(time * 3) * 0.15
      -- Rainbow chromatic halo
      for ring = 1, 5 do
        local rHue = (synesthesia.vizHue + ring * 0.15) % 1
        local ar, ag, ab = M.hsvToRgb(rHue, 0.6, 1)
        love.graphics.setColor(ar, ag, ab, auraPulse / ring)
        love.graphics.circle("line", 0, 0, sb.width * 0.5 + ring * 15 + math.sin(time * 2 + ring) * 5)
      end
    end

    -- Main body: GPU die shape (square with beveled corners)
    -- Outer casing
    love.graphics.setColor(0.12, 0.12, 0.15, alpha)
    local hw, hh = sb.width / 2, sb.height / 2
    love.graphics.polygon("fill",
      -hw + 15, -hh,
      hw - 15, -hh,
      hw, -hh + 15,
      hw, hh - 15,
      hw - 15, hh,
      -hw + 15, hh,
      -hw, hh - 15,
      -hw, -hh + 15)

    -- Circuit trace pattern on body
    love.graphics.setColor(pc[1] * 0.3, pc[2] * 0.3, pc[3] * 0.3, alpha * 0.5)
    love.graphics.setLineWidth(1)
    for tx = -hw + 25, hw - 25, 20 do
      love.graphics.line(tx, -hh + 20, tx, hh - 20)
    end
    for ty = -hh + 25, hh - 25, 20 do
      love.graphics.line(-hw + 20, ty, hw - 20, ty)
    end

    -- Inner die (processor core)
    local innerScale = 0.65
    love.graphics.setColor(pc[1] * 0.15, pc[2] * 0.15, pc[3] * 0.15, alpha)
    love.graphics.rectangle("fill", -hw * innerScale, -hh * innerScale,
      sb.width * innerScale, sb.height * innerScale)
    -- Die border glow
    local diePulse = 0.4 + math.sin(time * 2.5) * 0.3
    love.graphics.setColor(pc[1], pc[2], pc[3], diePulse * alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -hw * innerScale, -hh * innerScale,
      sb.width * innerScale, sb.height * innerScale)
    love.graphics.setLineWidth(1)

    -- Central core eye (GPU compute unit)
    local eyePulse = 0.5 + math.sin(time * 3 + sb.phase) * 0.4
    love.graphics.setColor(pc[1], pc[2], pc[3], eyePulse * alpha)
    love.graphics.circle("fill", 0, 0, 18)
    love.graphics.setColor(1, 1, 1, eyePulse * alpha * 0.6)
    love.graphics.circle("fill", 0, 0, 8)
    -- Eye ring
    love.graphics.setColor(pc[1], pc[2], pc[3], alpha * 0.7)
    love.graphics.circle("line", 0, 0, 22)

    -- BGA solder ball grid (bottom of chip)
    love.graphics.setColor(0.6, 0.6, 0.5, alpha * 0.3)
    for bx = -hw * 0.5, hw * 0.5, 16 do
      for by = -hh * 0.5, hh * 0.5, 16 do
        local dist = math.sqrt(bx*bx + by*by)
        if dist > 25 then  -- Not in central eye
          love.graphics.circle("fill", bx, by, 2)
        end
      end
    end

    -- Shield cores (sides of boss body)
    if not sb.shieldCoresDown then
      -- Left shield core
      if not sb.leftShieldCore.destroyed then
        local scPulse = 0.6 + math.sin(time * 4) * 0.3
        love.graphics.setColor(0.2, 0.6, 1, scPulse * alpha)
        love.graphics.circle("fill", sb.leftShieldCore.x, 0, 15)
        love.graphics.setColor(0.3, 0.8, 1, alpha * 0.8)
        love.graphics.circle("line", sb.leftShieldCore.x, 0, 18)
        -- Shield energy line to center
        love.graphics.setColor(0.2, 0.5, 1, 0.3)
        love.graphics.line(sb.leftShieldCore.x, 0, 0, 0)
      end
      -- Right shield core
      if not sb.rightShieldCore.destroyed then
        local scPulse = 0.6 + math.sin(time * 4 + math.pi) * 0.3
        love.graphics.setColor(0.2, 0.6, 1, scPulse * alpha)
        love.graphics.circle("fill", sb.rightShieldCore.x, 0, 15)
        love.graphics.setColor(0.3, 0.8, 1, alpha * 0.8)
        love.graphics.circle("line", sb.rightShieldCore.x, 0, 18)
        love.graphics.setColor(0.2, 0.5, 1, 0.3)
        love.graphics.line(sb.rightShieldCore.x, 0, 0, 0)
      end
      -- Shield barrier between cores
      if not sb.leftShieldCore.destroyed and not sb.rightShieldCore.destroyed then
        local shieldAlpha = 0.15 + math.sin(time * 3) * 0.08
        love.graphics.setColor(0.2, 0.5, 1, shieldAlpha)
        love.graphics.rectangle("fill", sb.leftShieldCore.x, -hh * 0.4,
          sb.rightShieldCore.x - sb.leftShieldCore.x, hh * 0.8)
      end
    end

    -- Pin array (edge connectors around GPU die)
    love.graphics.setColor(0.7, 0.65, 0.3, alpha * 0.4)
    for pin = -hw + 20, hw - 20, 10 do
      love.graphics.rectangle("fill", pin - 1, -hh - 6, 3, 6)
      love.graphics.rectangle("fill", pin - 1, hh, 3, 6)
    end
    for pin = -hh + 20, hh - 20, 10 do
      love.graphics.rectangle("fill", -hw - 6, pin - 1, 6, 3)
      love.graphics.rectangle("fill", hw, pin - 1, 6, 3)
    end

    -- Weapon emitter ports (phase-colored)
    love.graphics.setColor(pc[1], pc[2], pc[3], alpha * 0.7)
    love.graphics.rectangle("fill", -20, hh - 5, 10, 10)
    love.graphics.rectangle("fill", 10, hh - 5, 10, 10)

    love.graphics.pop()

    -- ===========================================================
    -- ATTACK WARNING HUD
    -- ===========================================================
    local warning, progress = synesthesia.getAttackWarning()
    if warning then
      local wFlash = 0.6 + math.sin(time * 6) * 0.4
      love.graphics.setColor(1, 0.3, 0.3, wFlash)
      love.graphics.setFont(love.graphics.newFont(12))
      love.graphics.printf("⚠ " .. warning .. " ⚠",
        screen.WIDTH / 2 - 100, screen.HEIGHT - 60, 200, "center")
      -- Progress bar
      if progress then
        love.graphics.setColor(0.15, 0.1, 0.1, 0.7)
        love.graphics.rectangle("fill", screen.WIDTH / 2 - 60, screen.HEIGHT - 45, 120, 6)
        love.graphics.setColor(1, 0.3, 0.2, 0.8)
        love.graphics.rectangle("fill", screen.WIDTH / 2 - 60, screen.HEIGHT - 45, 120 * progress, 6)
      end
    end

    -- ===========================================================
    -- HEALTH BAR (10-phase segmented, Elden Ring style)
    -- ===========================================================
    local healthPct = sb.health / sb.maxHealth
    local barWidth = 340
    local barX = screen.WIDTH / 2 - barWidth / 2
    local barY = 30

    -- Background
    love.graphics.setColor(0.08, 0.06, 0.1, 0.9)
    love.graphics.rectangle("fill", barX - 3, barY - 3, barWidth + 6, 18)
    love.graphics.setColor(0.3, 0.15, 0.4, 0.6)
    love.graphics.rectangle("line", barX - 3, barY - 3, barWidth + 6, 18)

    -- 10 chromatic phase segments
    local segColors = {
      {0.3, 0.9, 0.4},    -- 1: Shader Storm
      {0.2, 0.6, 1.0},    -- 2: Pipeline
      {0.9, 0.3, 0.9},    -- 3: Rasterizer
      {0.6, 0.2, 0.9},    -- 4: Tensor Core
      {0.2, 1.0, 0.8},    -- 5: Ray Trace
      {1.0, 0.5, 0.1},    -- 6: Buffer Overflow
      {1.0, 0.8, 0.1},    -- 7: Overclock
      {1.0, 0.15, 0.15},  -- 8: Kernel Panic
      {1.0, 0.4, 0.2},    -- 9: Thermal Throttle
      {1.0, 1.0, 1.0},    -- 10: Ascension
    }

    for i = 1, 10 do
      local segStart = (i - 1) / 10
      local segEnd = i / 10
      if healthPct > segStart then
        local segWidth = math.min(healthPct, segEnd) - segStart
        local sc = segColors[i]
        love.graphics.setColor(sc[1], sc[2], sc[3])
        love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 12)
      end
      love.graphics.setColor(0, 0, 0)
      love.graphics.rectangle("fill", barX + (i / 10) * barWidth - 1, barY, 2, 12)
    end

    -- Phase indicator
    love.graphics.setColor(pc[1], pc[2], pc[3], 0.9)
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.printf(synesthesia.getPhaseName() .. "  [" .. sb.phase .. "/10]",
      barX, barY + 14, barWidth, "center")

    -- Boss name
    local bossName = sb.ascended and "GPU CORE ARCHITECT — ASCENDED" or "GPU CORE ARCHITECT"
    love.graphics.setColor(pc[1], pc[2], pc[3])
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf(bossName, barX, barY - 20, barWidth, "center")

  elseif synesthesia.raidActive and synesthesia.raidSection >= 1 and synesthesia.raidSection <= 3 then
    -- Section name during terrain flight
    love.graphics.setColor(0.7, 0.8, 1, 0.7)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf("SYNESTHESIA INSTALLATION — " .. synesthesia.getSectionName(),
      screen.WIDTH / 2 - 200, 20, 400, "center")
  end
end

-- HSV to RGB helper for chromatic effects
function M.hsvToRgb(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return v, t, p
  elseif i == 1 then return q, v, p
  elseif i == 2 then return p, v, t
  elseif i == 3 then return p, q, v
  elseif i == 4 then return t, p, v
  else return v, p, q
  end
end

------------------------------------------------------------------------
-- THE MACHINE — 21-Phase Ultimate Final Boss Raid
-- Nebula + Hometown Station in background, industrial nightmare aesthetic
------------------------------------------------------------------------

function M.drawMachineBoss()
  local mb = machineboss.boss
  if not mb or not mb.active then return end

  local time = love.timer.getTime()
  local alpha = mb.fadeAlpha or 1

  -- ============================================================
  -- BACKGROUND: NEBULA + HOMETOWN STATION
  -- ============================================================

  -- Nebula cloud layers (swirling purple/blue/magenta cosmic dust)
  local nebulaAngle = mb.nebulaAngle or 0
  for layer = 1, 4 do
    local layerAlpha = 0.06 + layer * 0.02
    local r = 0.15 + layer * 0.05
    local g = 0.05 + layer * 0.02
    local b2 = 0.2 + layer * 0.08
    local cx = screen.WIDTH / 2 + math.cos(nebulaAngle * (0.5 + layer * 0.2)) * (80 + layer * 30)
    local cy = screen.HEIGHT / 2 + math.sin(nebulaAngle * (0.3 + layer * 0.15)) * (60 + layer * 20)
    local rad = 200 + layer * 80

    love.graphics.setColor(r, g, b2, layerAlpha * (0.7 + math.sin(time * 0.5 + layer) * 0.3))
    love.graphics.circle("fill", cx, cy, rad)
    love.graphics.setColor(r + 0.1, g + 0.05, b2 + 0.1, layerAlpha * 0.5)
    love.graphics.circle("fill", cx + 30, cy - 20, rad * 0.6)
  end

  -- Nebula stars (twinkling distant points inside the nebula)
  math.randomseed(42)
  for i = 1, 60 do
    local sx = math.random(0, screen.WIDTH)
    local sy = math.random(0, screen.HEIGHT)
    local twinkle = 0.3 + math.abs(math.sin(time * 1.5 + i * 0.7)) * 0.7
    local brightness = 0.4 + math.random() * 0.6
    love.graphics.setColor(brightness, brightness * 0.9, brightness, twinkle * 0.5)
    love.graphics.circle("fill", sx, sy, 1 + math.random())
  end
  math.randomseed(os.time())

  -- Hometown Station (distant, orbiting in the background)
  local stationAngle = mb.stationOrbitAngle or 0
  local stationX = screen.WIDTH * 0.8 + math.cos(stationAngle) * 60
  local stationY = screen.HEIGHT * 0.2 + math.sin(stationAngle) * 30
  local stationAlpha = 0.5 + math.sin(time * 0.3) * 0.1

  -- Station main body
  love.graphics.setColor(0.3, 0.35, 0.4, stationAlpha)
  love.graphics.rectangle("fill", stationX - 20, stationY - 8, 40, 16)
  -- Station ring
  love.graphics.setColor(0.4, 0.45, 0.5, stationAlpha * 0.8)
  love.graphics.circle("line", stationX, stationY, 24)
  -- Station solar panels
  love.graphics.setColor(0.25, 0.3, 0.5, stationAlpha)
  love.graphics.rectangle("fill", stationX - 35, stationY - 3, 12, 6)
  love.graphics.rectangle("fill", stationX + 23, stationY - 3, 12, 6)
  -- Station lights
  local lightPulse = math.abs(math.sin(time * 2))
  love.graphics.setColor(0.8, 0.9, 1, stationAlpha * lightPulse)
  love.graphics.circle("fill", stationX, stationY, 3)
  love.graphics.setColor(1, 0.5, 0.2, stationAlpha * (1 - lightPulse))
  love.graphics.circle("fill", stationX - 15, stationY - 5, 2)
  love.graphics.circle("fill", stationX + 15, stationY + 5, 2)
  -- Station label
  love.graphics.setColor(0.5, 0.55, 0.65, stationAlpha * 0.6)
  love.graphics.setFont(love.graphics.newFont(8))
  love.graphics.printf("HOMETOWN STATION", stationX - 50, stationY + 28, 100, "center")

  -- ============================================================
  -- DRAW HAZARD ZONES BEHIND BOSS
  -- ============================================================

  -- Steam Vents (Phase 3+) - hissing green/white steam
  for _, vent in ipairs(mb.steamVents or {}) do
    local ventPulse = 0.3 + math.abs(math.sin(time * 4 + vent.x * 0.1)) * 0.4
    love.graphics.setColor(0.6, 0.9, 0.5, ventPulse * 0.25)
    love.graphics.circle("fill", vent.x, vent.y, vent.radius + 12)
    love.graphics.setColor(0.7, 1, 0.6, ventPulse * 0.4)
    love.graphics.circle("fill", vent.x, vent.y, vent.radius)
    love.graphics.setColor(0.9, 1, 0.9, ventPulse * 0.6)
    love.graphics.circle("fill", vent.x, vent.y, vent.radius * 0.4)
    -- Steam particles rising
    for j = 0, 3 do
      local yOff = (time * 40 + j * 20) % (vent.radius * 2) - vent.radius
      love.graphics.setColor(0.8, 1, 0.8, (1 - math.abs(yOff) / vent.radius) * 0.3 * ventPulse)
      love.graphics.circle("fill", vent.x + math.sin(time * 3 + j) * 8, vent.y + yOff, 4)
    end
  end

  -- Molten Slag Zones (Phase 8+) - orange/red fire pools
  for _, zone in ipairs(mb.slagZones or {}) do
    local slagPulse = 0.4 + math.abs(math.sin(time * 3.5 + zone.x * 0.07)) * 0.4
    love.graphics.setColor(0.8, 0.2, 0.05, slagPulse * 0.3)
    love.graphics.circle("fill", zone.x, zone.y, zone.radius + 15)
    love.graphics.setColor(1, 0.4, 0.1, slagPulse * 0.5)
    love.graphics.circle("fill", zone.x, zone.y, zone.radius)
    love.graphics.setColor(1, 0.7, 0.3, slagPulse * 0.7)
    love.graphics.circle("fill", zone.x, zone.y, zone.radius * 0.4)
    -- Ember particles
    for j = 0, 2 do
      local emberY = zone.y - (time * 30 + j * 15) % 40
      love.graphics.setColor(1, 0.5 + math.random() * 0.3, 0.1, 0.5 * slagPulse)
      love.graphics.circle("fill", zone.x + math.sin(time * 2 + j * 3) * 12, emberY, 2)
    end
  end

  -- Quantum Cuts (Phase 15+) - reality tear lines
  for _, cut in ipairs(mb.quantumCuts or {}) do
    local cutAlpha = cut.warmup > 0 and (0.2 + math.sin(time * 12) * 0.15) or 0.8
    if cut.warmup > 0 then
      -- Telegraph: flickering line
      if cut.isVertical then
        love.graphics.setColor(0.5, 0.2, 1, cutAlpha * 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.line(cut.x, 0, cut.x, screen.HEIGHT)
      else
        love.graphics.setColor(0.5, 0.2, 1, cutAlpha * 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, cut.y, screen.WIDTH, cut.y)
      end
    else
      -- Active: bright dangerous line
      if cut.isVertical then
        love.graphics.setColor(0.8, 0.3, 1, 0.3)
        love.graphics.rectangle("fill", cut.x - 15, 0, 30, screen.HEIGHT)
        love.graphics.setColor(1, 0.5, 1, cutAlpha)
        love.graphics.setLineWidth(4)
        love.graphics.line(cut.x, 0, cut.x, screen.HEIGHT)
        love.graphics.setColor(1, 1, 1, cutAlpha * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.line(cut.x, 0, cut.x, screen.HEIGHT)
      else
        love.graphics.setColor(0.8, 0.3, 1, 0.3)
        love.graphics.rectangle("fill", 0, cut.y - 15, screen.WIDTH, 30)
        love.graphics.setColor(1, 0.5, 1, cutAlpha)
        love.graphics.setLineWidth(4)
        love.graphics.line(0, cut.y, screen.WIDTH, cut.y)
        love.graphics.setColor(1, 1, 1, cutAlpha * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, cut.y, screen.WIDTH, cut.y)
      end
    end
    love.graphics.setLineWidth(1)
  end

  -- Time Dilation Fields (Phase 16+) - blue/cyan distortion spheres
  for _, field in ipairs(mb.timeFields or {}) do
    local fieldPulse = 0.5 + math.sin(time * 2 + field.x * 0.05) * 0.3
    -- Outer distortion ring
    love.graphics.setColor(0.1, 0.3, 0.8, fieldPulse * 0.2)
    love.graphics.circle("fill", field.x, field.y, field.radius + 10)
    -- Inner field
    love.graphics.setColor(0.2, 0.5, 1, fieldPulse * 0.3)
    love.graphics.circle("fill", field.x, field.y, field.radius)
    -- Clockwork pattern inside
    love.graphics.setColor(0.3, 0.6, 1, fieldPulse * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", field.x, field.y, field.radius * 0.7)
    love.graphics.circle("line", field.x, field.y, field.radius * 0.4)
    -- Rotating hands
    local handAngle = time * 3
    love.graphics.line(
      field.x, field.y,
      field.x + math.cos(handAngle) * field.radius * 0.5,
      field.y + math.sin(handAngle) * field.radius * 0.5
    )
    love.graphics.line(
      field.x, field.y,
      field.x + math.cos(handAngle * 0.3) * field.radius * 0.3,
      field.y + math.sin(handAngle * 0.3) * field.radius * 0.3
    )
  end

  -- Conveyors (Phase 12+) - industrial conveyor belts
  for _, conv in ipairs(mb.conveyors or {}) do
    love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
    love.graphics.rectangle("fill", conv.x - conv.width / 2, conv.y - conv.height / 2, conv.width, conv.height)
    -- Conveyor lines (animated)
    love.graphics.setColor(0.5, 0.5, 0.55, 0.6)
    local lineOffset = (time * conv.speed * conv.direction * 0.5) % 20
    for lx = 0, conv.width, 20 do
      local lineX = conv.x - conv.width / 2 + lx + lineOffset
      if lineX >= conv.x - conv.width / 2 and lineX <= conv.x + conv.width / 2 then
        love.graphics.setLineWidth(1)
        love.graphics.line(lineX, conv.y - conv.height / 2, lineX, conv.y + conv.height / 2)
      end
    end
    -- Direction arrow
    love.graphics.setColor(1, 0.8, 0.2, 0.6)
    local arrowX = conv.x + conv.direction * 30
    love.graphics.circle("fill", arrowX, conv.y, 4)
  end

  -- Dimension Rifts (Phase 19+) - purple swirling portals
  for _, rift in ipairs(mb.rifts or {}) do
    local riftPulse = 0.6 + math.sin(time * 4 + rift.x) * 0.3
    -- Outer glow
    love.graphics.setColor(0.6, 0.1, 0.8, riftPulse * 0.25)
    love.graphics.circle("fill", rift.x, rift.y, rift.radius + 15)
    -- Swirl rings
    love.graphics.setColor(0.8, 0.2, 1, riftPulse * 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", rift.x, rift.y, rift.radius)
    love.graphics.setColor(1, 0.5, 1, riftPulse * 0.4)
    love.graphics.circle("line", rift.x, rift.y, rift.radius * 0.6)
    -- Center vortex
    love.graphics.setColor(1, 0.8, 1, riftPulse * 0.8)
    love.graphics.circle("fill", rift.x, rift.y, 5)
    love.graphics.setLineWidth(1)
  end

  -- Barriers (spinning obstacles)
  for _, bar in ipairs(mb.barriers or {}) do
    love.graphics.push()
    love.graphics.translate(bar.x, bar.y)
    love.graphics.rotate(bar.angle)
    love.graphics.setColor(0.5, 0.5, 0.55, 0.8)
    love.graphics.rectangle("fill", -bar.width / 2, -bar.height / 2, bar.width, bar.height)
    love.graphics.setColor(0.7, 0.3, 0.1, 0.6)
    love.graphics.rectangle("fill", -bar.width / 2 + 2, -bar.height / 2 + 2, bar.width - 4, bar.height - 4)
    love.graphics.pop()
  end

  -- Gears (Phase 4+) - spinning gear obstacles
  for _, gear in ipairs(mb.gears or {}) do
    love.graphics.push()
    love.graphics.translate(gear.x, gear.y)
    love.graphics.rotate(gear.spinAngle)
    -- Gear teeth
    love.graphics.setColor(0.4, 0.4, 0.45, 0.8)
    local teeth = 8
    for t = 0, teeth - 1 do
      local tAngle = t * (math.pi * 2 / teeth)
      love.graphics.rectangle("fill",
        math.cos(tAngle) * gear.radius - 4,
        math.sin(tAngle) * gear.radius - 4, 8, 8)
    end
    love.graphics.circle("fill", 0, 0, gear.radius * 0.8)
    -- Center hole
    love.graphics.setColor(0.15, 0.15, 0.18, 0.9)
    love.graphics.circle("fill", 0, 0, gear.radius * 0.3)
    love.graphics.pop()
  end

  -- Turbine Blades (Phase 13+) - deadly spinning hazards
  for _, turb in ipairs(mb.turbines or {}) do
    love.graphics.push()
    love.graphics.translate(turb.x, turb.y)
    love.graphics.rotate(turb.spinAngle)
    -- Danger glow
    love.graphics.setColor(1, 0.2, 0.1, 0.2)
    love.graphics.circle("fill", 0, 0, turb.radius + 10)
    -- Blades
    love.graphics.setColor(0.6, 0.15, 0.1, 0.9)
    for bl = 0, 3 do
      local bAngle = bl * (math.pi / 2)
      love.graphics.polygon("fill",
        0, 0,
        math.cos(bAngle - 0.2) * turb.radius, math.sin(bAngle - 0.2) * turb.radius,
        math.cos(bAngle + 0.2) * turb.radius, math.sin(bAngle + 0.2) * turb.radius
      )
    end
    -- Center hub
    love.graphics.setColor(0.3, 0.1, 0.1, 0.9)
    love.graphics.circle("fill", 0, 0, 8)
    love.graphics.pop()
  end

  -- Magnetic Pull indicator (Phase 11+)
  if mb.magnetActive then
    local magPulse = 0.3 + math.abs(math.sin(time * 5)) * 0.4
    love.graphics.setColor(0.3, 0.5, 1, magPulse * 0.2)
    love.graphics.circle("line", mb.x, mb.y, 180)
    love.graphics.setColor(0.4, 0.6, 1, magPulse * 0.15)
    love.graphics.circle("line", mb.x, mb.y, 120)
    love.graphics.setColor(0.5, 0.7, 1, magPulse * 0.1)
    love.graphics.circle("line", mb.x, mb.y, 60)
  end

  -- Annihilation Pulse safe zone indicator (Phase 20+)
  if mb.annihilationCharging then
    local progress = mb.annihilationTimer / mb.annihilationDuration
    -- Screen darkening
    love.graphics.setColor(0.8, 0.1, 0.05, (1 - progress) * 0.3)
    love.graphics.rectangle("fill", 0, 0, screen.WIDTH, screen.HEIGHT)
    -- Safe zone beacon
    local safePulse = math.abs(math.sin(time * 6))
    love.graphics.setColor(0.2, 1, 0.3, safePulse * 0.6)
    love.graphics.circle("line", mb.annihilationSafeX, mb.annihilationSafeY, mb.annihilationSafeRadius + 10)
    love.graphics.setColor(0.3, 1, 0.4, safePulse * 0.3)
    love.graphics.circle("fill", mb.annihilationSafeX, mb.annihilationSafeY, mb.annihilationSafeRadius)
    love.graphics.setColor(0.5, 1, 0.6, 0.8)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.printf("SAFE ZONE", mb.annihilationSafeX - 50, mb.annihilationSafeY - 6, 100, "center")
  end

  -- ============================================================
  -- DRAW THE BOSS
  -- ============================================================

  love.graphics.push()
  love.graphics.translate(mb.x, mb.y)

  -- Act-based color scheme
  local act = machineboss.getAct()
  local phaseInAct = mb.phase <= 7 and mb.phase or (mb.phase <= 14 and mb.phase - 7 or mb.phase - 14)

  local baseColor, coreColor, accentColor
  if act == 1 then
    -- Act I: Dark iron / rust
    baseColor = {0.12 + phaseInAct * 0.01, 0.1, 0.08}
    coreColor = {0.8 + phaseInAct * 0.02, 0.4 - phaseInAct * 0.02, 0.1}
    accentColor = {0.6, 0.3, 0.1}
  elseif act == 2 then
    -- Act II: Molten forge / orange-red
    baseColor = {0.15 + phaseInAct * 0.02, 0.08, 0.05}
    coreColor = {1, 0.5 - phaseInAct * 0.03, 0.1}
    accentColor = {1, 0.4, 0.05}
  else
    -- Act III: Cosmic / purple-white
    baseColor = {0.1 + phaseInAct * 0.02, 0.05, 0.15 + phaseInAct * 0.02}
    coreColor = {0.8, 0.3 + phaseInAct * 0.05, 1}
    accentColor = {0.6, 0.2, 0.9}
  end

  -- Phase transition glow
  if mb.phaseTransitioning then
    local transGlow = math.abs(math.sin(time * 10))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], transGlow * 0.6 * alpha)
    love.graphics.circle("fill", 0, 0, 120)
  end

  -- Outer hull - main body
  love.graphics.setColor(baseColor[1] * alpha, baseColor[2] * alpha, baseColor[3] * alpha, alpha)
  love.graphics.rectangle("fill", -mb.width / 2, -mb.height / 2, mb.width, mb.height)

  -- Industrial plating
  love.graphics.setColor(baseColor[1] * 0.7 * alpha, baseColor[2] * 0.7 * alpha, baseColor[3] * 0.7 * alpha, alpha)
  love.graphics.rectangle("fill", -70, -60, 140, 25)
  love.graphics.rectangle("fill", -80, 10, 160, 35)

  -- Rivets / bolts
  love.graphics.setColor(0.3 * alpha, 0.25 * alpha, 0.2 * alpha, alpha)
  for rx = -60, 60, 30 do
    love.graphics.circle("fill", rx, -50, 3)
    love.graphics.circle("fill", rx, 40, 3)
  end

  -- Central core / eye - pulsing based on phase
  local pulse = 1
  if mb.phase >= 10 then
    pulse = 0.6 + math.abs(math.sin(time * 6)) * 0.4
  end
  if mb.enraged then
    pulse = 0.4 + math.abs(math.sin(time * 12)) * 0.6
  end

  love.graphics.setColor(coreColor[1] * pulse * alpha, coreColor[2] * pulse * alpha, coreColor[3] * pulse * alpha, alpha)
  love.graphics.circle("fill", 0, -5, 30)

  -- Core inner glow
  love.graphics.setColor(1 * alpha, 1 * alpha, 1 * alpha, 0.5 * alpha * pulse)
  love.graphics.circle("fill", 0, -5, 12)

  -- Weapon ports
  love.graphics.setColor(accentColor[1] * 0.6 * alpha, accentColor[2] * 0.4 * alpha, accentColor[3] * 0.3 * alpha, alpha)
  love.graphics.rectangle("fill", -60, 50, 30, 20)
  love.graphics.rectangle("fill", 30, 50, 30, 20)
  love.graphics.rectangle("fill", -15, 55, 30, 15)

  -- Phase wings/appendages (grow with phases)
  if mb.phase >= 5 then
    local wingSize = math.min((mb.phase - 4) * 5, 40)
    love.graphics.setColor(accentColor[1] * 0.8 * alpha, accentColor[2] * 0.5 * alpha, accentColor[3] * 0.4 * alpha, alpha * 0.8)
    love.graphics.polygon("fill", -100, 0, -100 + wingSize, -30 - wingSize / 2, -100 + wingSize, 30 + wingSize / 2)
    love.graphics.polygon("fill", 100, 0, 100 - wingSize, -30 - wingSize / 2, 100 - wingSize, 30 + wingSize / 2)
  end

  -- Exhaust pipes (act II+)
  if act >= 2 then
    love.graphics.setColor(0.2 * alpha, 0.15 * alpha, 0.1 * alpha, alpha)
    love.graphics.rectangle("fill", -90, 20, 15, 40)
    love.graphics.rectangle("fill", 75, 20, 15, 40)
    -- Exhaust glow
    local exPulse = math.abs(math.sin(time * 4))
    love.graphics.setColor(1, 0.5, 0.1, exPulse * 0.5 * alpha)
    love.graphics.circle("fill", -83, 62, 8)
    love.graphics.circle("fill", 83, 62, 8)
  end

  -- God Machine aura (Phase 21)
  if mb.enraged then
    local auraPulse = math.abs(math.sin(time * 8))
    love.graphics.setColor(coreColor[1], coreColor[2], coreColor[3], auraPulse * 0.4 * alpha)
    love.graphics.circle("fill", 0, 0, 100)
    love.graphics.setColor(1, 1, 1, auraPulse * 0.2 * alpha)
    love.graphics.circle("fill", 0, 0, 60)
  end

  love.graphics.pop()

  -- ============================================================
  -- DRAW ARMOR PLATES (Phase 1-4)
  -- ============================================================

  if not mb.leftArmor.destroyed then
    local armorX = mb.x - 80
    love.graphics.setColor(0.35, 0.3, 0.25, alpha)
    love.graphics.rectangle("fill", armorX - 17, mb.y - 40, 35, 80)
    love.graphics.setColor(0.5, 0.4, 0.2, alpha)
    love.graphics.rectangle("fill", armorX - 15, mb.y - 38, 31, 76)
    -- Armor HP bar
    local hpPct = mb.leftArmor.health / mb.leftArmor.maxHealth
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", armorX - 15, mb.y + 42, 30, 4)
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("fill", armorX - 15, mb.y + 42, 30 * hpPct, 4)
  end

  if not mb.rightArmor.destroyed then
    local armorX = mb.x + 80
    love.graphics.setColor(0.35, 0.3, 0.25, alpha)
    love.graphics.rectangle("fill", armorX - 17, mb.y - 40, 35, 80)
    love.graphics.setColor(0.5, 0.4, 0.2, alpha)
    love.graphics.rectangle("fill", armorX - 15, mb.y - 38, 31, 76)
    local hpPct = mb.rightArmor.health / mb.rightArmor.maxHealth
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", armorX - 15, mb.y + 42, 30, 4)
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("fill", armorX - 15, mb.y + 42, 30 * hpPct, 4)
  end

  -- Shield Generator (Phase 8-10)
  local shieldPos = machineboss.getShieldPosition()
  if shieldPos then
    local sPulse = 0.6 + math.sin(time * 5) * 0.3
    love.graphics.setColor(0.2, 0.6, 1, sPulse * 0.4)
    love.graphics.circle("fill", shieldPos.x, shieldPos.y, 40)
    love.graphics.setColor(0.3, 0.7, 1, sPulse * 0.7)
    love.graphics.circle("line", shieldPos.x, shieldPos.y, 35)
    love.graphics.setColor(0.5, 0.8, 1, sPulse)
    love.graphics.circle("fill", shieldPos.x, shieldPos.y, 10)
    -- Shield HP bar
    local shpPct = shieldPos.health / shieldPos.maxHealth
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", shieldPos.x - 20, shieldPos.y + 25, 40, 4)
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.rectangle("fill", shieldPos.x - 20, shieldPos.y + 25, 40 * shpPct, 4)
  end

  -- ============================================================
  -- DRAW ADDS
  -- ============================================================

  for _, add in ipairs(mb.adds or {}) do
    -- Mini-machine drones
    love.graphics.setColor(0.25, 0.2, 0.18, 0.9)
    love.graphics.rectangle("fill", add.x - add.width / 2, add.y - add.height / 2, add.width, add.height)
    love.graphics.setColor(accentColor[1] * 0.7, accentColor[2] * 0.5, accentColor[3] * 0.3, 0.9)
    love.graphics.circle("fill", add.x, add.y, 5)
    -- Add HP bar
    local addHpPct = add.health / add.maxHealth
    love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
    love.graphics.rectangle("fill", add.x - 12, add.y - add.height / 2 - 6, 24, 3)
    love.graphics.setColor(0.2, 0.9, 0.3)
    love.graphics.rectangle("fill", add.x - 12, add.y - add.height / 2 - 6, 24 * addHpPct, 3)
    -- Regen indicator
    love.graphics.setColor(0.2, 1, 0.4, 0.6 + math.sin(time * 3) * 0.3)
    love.graphics.setFont(love.graphics.newFont(7))
    love.graphics.printf("+HP +MSL", add.x - 20, add.y + add.height / 2 + 2, 40, "center")
  end

  -- ============================================================
  -- DRILL LANCE CHARGE INDICATOR
  -- ============================================================

  if mb.drillCharging then
    local chargeProgress = 1.0 - mb.drillTimer / mb.drillDuration
    love.graphics.setColor(1, 0.6, 0.1, chargeProgress * 0.6)
    love.graphics.circle("fill", mb.x, mb.y + 60, 10 + chargeProgress * 20)
    -- Target line
    love.graphics.setColor(1, 0.3, 0.1, chargeProgress * 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(mb.x, mb.y + 60, mb.drillTargetX, mb.drillTargetY)
    love.graphics.setLineWidth(1)
  end

  -- Core Beam charge indicator (Phase 18+)
  if mb.coreBeamCharging then
    local chargeProgress = 1.0 - mb.coreBeamTimer / mb.coreBeamDuration
    love.graphics.setColor(1, 0.2, 0.1, chargeProgress * 0.8)
    love.graphics.circle("fill", mb.x, mb.y + 60, 8 + chargeProgress * 30)
    love.graphics.setColor(1, 1, 1, chargeProgress * 0.5)
    love.graphics.circle("fill", mb.x, mb.y + 60, 5 + chargeProgress * 15)
    -- Danger line to target
    love.graphics.setColor(1, 0.1, 0.1, chargeProgress * 0.5)
    love.graphics.setLineWidth(3)
    love.graphics.line(mb.x, mb.y + 60, mb.coreBeamTargetX, mb.coreBeamTargetY)
    love.graphics.setLineWidth(1)
  end

  -- Arc Welder beam (Phase 10+)
  if mb.arcWelderActive then
    local beamEndX = mb.x + math.cos(mb.arcWelderAngle) * 600
    local beamEndY = mb.y + math.sin(mb.arcWelderAngle) * 600
    love.graphics.setColor(0.3, 0.7, 1, 0.3)
    love.graphics.setLineWidth(12)
    love.graphics.line(mb.x, mb.y, beamEndX, beamEndY)
    love.graphics.setColor(0.6, 0.9, 1, 0.7)
    love.graphics.setLineWidth(4)
    love.graphics.line(mb.x, mb.y, beamEndX, beamEndY)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(mb.x, mb.y, beamEndX, beamEndY)
    -- Sparks at endpoint
    for s = 0, 3 do
      love.graphics.setColor(1, 0.8, 0.4, 0.7)
      love.graphics.circle("fill",
        beamEndX + math.cos(time * 8 + s) * 10,
        beamEndY + math.sin(time * 8 + s) * 10, 3)
    end
  end

  -- Hydraulic Ram charge indicator (Phase 9+)
  if mb.ramCharging then
    local ramProgress = 1.0 - mb.ramTimer / 1.5
    love.graphics.setColor(1, 0.5, 0.1, ramProgress * 0.5)
    love.graphics.circle("line", mb.x, mb.y, 30 + ramProgress * 40)
    love.graphics.setColor(1, 0.3, 0.05, ramProgress * 0.7)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.printf("!!", mb.x - 20, mb.y - 7, 40, "center")
  end

  -- Pressure Blow charge indicator (Phase 14+)
  if mb.pressureCharging then
    local presProgress = 1.0 - mb.pressureTimer / mb.pressureDuration
    love.graphics.setColor(1, 0.4, 0.1, presProgress * 0.4)
    love.graphics.circle("fill", mb.x, mb.y, 20 + presProgress * 60)
    love.graphics.setColor(1, 0.6, 0.3, presProgress * 0.6)
    love.graphics.circle("line", mb.x, mb.y, 10 + presProgress * 80)
  end

  -- ============================================================
  -- ATTACK WARNING & HUD
  -- ============================================================

  local warning, progress = machineboss.getAttackWarning()
  if warning then
    love.graphics.setColor(1, 0.2, 0.1, 0.9)
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.printf("!! " .. warning .. " !!", 0, screen.HEIGHT / 2 - 50, screen.WIDTH, "center")
    -- Warning progress bar
    love.graphics.setColor(0.3, 0.1, 0.1, 0.8)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200, 10)
    love.graphics.setColor(1, 0.3, 0.1)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, screen.HEIGHT / 2 - 25, 200 * progress, 10)
  end

  -- ============================================================
  -- BOSS HEALTH BAR — Elden Ring style, 21 phase segments
  -- ============================================================

  local healthPct = mb.health / mb.maxHealth
  local barWidth = 400
  local barX = screen.WIDTH / 2 - barWidth / 2
  local barY = 25

  -- Background
  love.graphics.setColor(0.08, 0.08, 0.08, 0.92)
  love.graphics.rectangle("fill", barX - 3, barY - 3, barWidth + 6, 20)

  -- Health segments (21 phases)
  for i = 1, 21 do
    local segStart = (i - 1) / 21
    local segEnd = i / 21
    if healthPct > segStart then
      local segWidth = math.min(healthPct, segEnd) - segStart

      -- Color per act
      local segR, segG, segB
      if i <= 7 then
        segR, segG, segB = 0.8, 0.5, 0.15  -- Act I: Gold/rust
      elseif i <= 14 then
        segR, segG, segB = 1, 0.35, 0.1     -- Act II: Molten orange
      else
        segR, segG, segB = 0.7, 0.25, 0.9   -- Act III: Cosmic purple
      end

      -- Current phase segment pulses
      if i == mb.phase then
        local segPulse = 0.7 + math.abs(math.sin(time * 4)) * 0.3
        segR = segR * segPulse
        segG = segG * segPulse
        segB = segB * segPulse
      end

      love.graphics.setColor(segR, segG, segB)
      love.graphics.rectangle("fill", barX + segStart * barWidth, barY, segWidth * barWidth, 14)
    end

    -- Phase divider lines
    if i < 21 then
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.rectangle("fill", barX + segEnd * barWidth - 1, barY, 2, 14)
    end
  end

  -- Bar border
  love.graphics.setColor(0.4, 0.35, 0.3, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, 16)
  love.graphics.setLineWidth(1)

  -- Phase name and number
  local phaseName = machineboss.getPhaseName()
  love.graphics.setColor(0.8, 0.8, 0.85, 0.9)
  love.graphics.setFont(love.graphics.newFont(10))
  love.graphics.printf("PHASE " .. mb.phase .. "/21 — " .. phaseName, barX, barY + 16, barWidth, "center")

  -- Act indicator
  local actNames = {"ACT I: THE AWAKENING", "ACT II: THE FORGE", "ACT III: THE SINGULARITY"}
  local actColors = {{0.8, 0.6, 0.2}, {1, 0.4, 0.1}, {0.7, 0.3, 1}}
  love.graphics.setColor(actColors[act][1], actColors[act][2], actColors[act][3], 0.7)
  love.graphics.setFont(love.graphics.newFont(9))
  love.graphics.printf(actNames[act], barX, barY + 28, barWidth, "center")

  -- Boss name
  love.graphics.setColor(0.85, 0.8, 0.7)
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.printf("THE MACHINE", barX, barY - 22, barWidth, "center")
end

return M
