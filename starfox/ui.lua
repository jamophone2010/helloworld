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
local bossexplosion = require("starfox.bossexplosion")
local supershot = require("starfox.supershot")
local abilities = require("starfox.abilities")
local ships = require("starfox.ships")

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
  if M.isSectorX() then
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

function M.drawVictory(enemiesDefeated, totalEnemies, notesEarned)
  notesEarned = notesEarned or 0

  -- Start animation if not active
  if not victoryState.active then
    M.startVictoryAnimation(enemiesDefeated, totalEnemies, notesEarned)
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
    local baseX = 180 + offsetX
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

return M
