local M = {}

local ships = require("starfox.ships")
local particles = require("starfox.particles")

-- Special gauge (0 to GAUGE_MAX, displayed as percentage)
local gauge = 0
local GAUGE_MAX = 50  -- kills needed to fill from kills alone

-- Ready animation state
local readyAnimTimer = 0
local readyAnimActive = false
local justBecameReady = false

-- Active ability state
M.active = false
M.abilityType = nil   -- "multilock", "reflectshield", "convert", "phasecloak"
M.abilityTimer = 0
M.abilityDuration = 0

-- Ability-specific data
M.convertKills = 0          -- Mistral: how many enemies converted so far
M.convertMax = 2            -- Mistral: max conversions
M.convertedWingmen = {}     -- Mistral: references to converted allies
M.reflectRadius = 80        -- Paladin: reflect radius
M.multiLockTargeting = false -- Lancer: whether multi-lock targeting is active

-- Visual effects
M.shieldAlpha = 0
M.phaseAlpha = 1.0
M.abilityFlashTimer = 0
M.activationFlash = 0

-- Particles for ability effects
M.abilityParticles = {}

function M.reset()
  gauge = 0
  readyAnimTimer = 0
  readyAnimActive = false
  justBecameReady = false
  M.active = false
  M.abilityType = nil
  M.abilityTimer = 0
  M.abilityDuration = 0
  M.convertKills = 0
  M.convertedWingmen = {}
  M.multiLockTargeting = false
  M.shieldAlpha = 0
  M.phaseAlpha = 1.0
  M.abilityFlashTimer = 0
  M.activationFlash = 0
  M.abilityParticles = {}
  M.empBurstRadius = 0
  M.empBurstMaxRadius = 500
  M.empBurstDamaged = {}
end

--- Add gauge from a kill (1 point per kill)
function M.registerKill(levelId)
  if M.active then return end
  if gauge >= GAUGE_MAX then return end
  local def = ships.getSelectedDef()
  if not def or not def.hasSpecial then return end
  gauge = math.min(GAUGE_MAX, gauge + 1)
  -- Sector Y (levelId 3) always keeps gauge full
  if levelId == 3 then
    gauge = GAUGE_MAX
  end
  M.checkReady()
end

--- Add gauge from boss damage (1 point per damage dealt)
function M.registerBossDamage(damage, levelId)
  if M.active then return end
  if gauge >= GAUGE_MAX then return end
  local def = ships.getSelectedDef()
  if not def or not def.hasSpecial then return end
  gauge = math.min(GAUGE_MAX, gauge + damage)
  if levelId == 3 then
    gauge = GAUGE_MAX
  end
  M.checkReady()
end

--- Add gauge from a medal bonus
function M.registerMedal(medalThreshold)
  local def = ships.getSelectedDef()
  if not def or not def.hasSpecial then return end
  if gauge >= GAUGE_MAX then return end
  local bonus = ships.getSpecialGaugeBonus(medalThreshold)
  if bonus > 0 then
    gauge = math.min(GAUGE_MAX, gauge + bonus)
    M.checkReady()
  end
end

function M.checkReady()
  if gauge >= GAUGE_MAX and not readyAnimActive and not M.active then
    readyAnimActive = true
    readyAnimTimer = 0
    justBecameReady = true
  end
end

function M.isReady()
  return gauge >= GAUGE_MAX and not M.active
end

function M.getGaugePercent()
  return gauge / GAUGE_MAX
end

function M.getGaugeValue()
  return gauge
end

function M.getGaugeMax()
  return GAUGE_MAX
end

--- Consume the gauge and activate the ability
function M.activate(player, infiniteSpecial)
  if not M.isReady() and not infiniteSpecial then return false end

  local def = ships.getSelectedDef()
  if not def or not def.hasSpecial then return false end

  -- Only consume gauge if not infinite special
  if not infiniteSpecial then
    gauge = 0
    readyAnimActive = false
    justBecameReady = false
  end
  M.active = true
  M.activationFlash = 1.0
  M.abilityFlashTimer = 0

  local shipId = def.id
  if shipId == "lancer" then
    M.abilityType = "multilock"
    M.abilityDuration = 5.0
    M.abilityTimer = 5.0
    M.multiLockTargeting = true
  elseif shipId == "paladin" then
    M.abilityType = "reflectshield"
    M.abilityDuration = 5.0
    M.abilityTimer = 5.0
    M.shieldAlpha = 1.0
    player.invulnerable = true
    player.invulnerableTimer = 5.0
  elseif shipId == "mistral" then
    M.abilityType = "convert"
    M.abilityDuration = 3.0
    M.abilityTimer = 3.0
    M.convertKills = 0
    M.convertedWingmen = {}
  elseif shipId == "phantom" then
    M.abilityType = "phasecloak"
    M.abilityDuration = 5.0
    M.abilityTimer = 5.0
    M.phaseAlpha = 0.5
    player.invulnerable = true
    player.invulnerableTimer = 5.0
  elseif shipId == "prototype" then
    M.abilityType = "empburst"
    M.abilityDuration = 3.0
    M.abilityTimer = 3.0
    M.empBurstRadius = 0
    M.empBurstMaxRadius = 500
    M.empBurstDamaged = {}
    player.invulnerable = true
    player.invulnerableTimer = 1.5
  else
    M.active = false
    return false
  end

  -- Activation burst particles
  for i = 1, 30 do
    local angle = math.random() * math.pi * 2
    local speed = math.random(100, 300)
    table.insert(M.abilityParticles, {
      x = player.x, y = player.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.8,
      maxLife = 0.8,
      color = {def.accentColor[1], def.accentColor[2], def.accentColor[3]},
      size = math.random(3, 7),
    })
  end

  -- Special attack disrupts Prototype's shield
  local prototype = require("starfox.prototype")
  if prototype.isActive() and prototype.shieldActive then
    prototype.onSpecialAttackHit()
  end

  return true
end

function M.update(dt, player)
  -- Ready animation
  if readyAnimActive then
    readyAnimTimer = readyAnimTimer + dt
  end

  -- Active ability countdown
  if M.active then
    M.abilityTimer = M.abilityTimer - dt
    M.abilityFlashTimer = M.abilityFlashTimer + dt
    M.activationFlash = math.max(0, M.activationFlash - dt * 2)

    -- Ability-specific updates
    if M.abilityType == "reflectshield" then
      M.shieldAlpha = 0.6 + math.sin(M.abilityFlashTimer * 6) * 0.3
      -- Spawn shield particles
      if math.random() < 0.3 then
        local angle = math.random() * math.pi * 2
        table.insert(M.abilityParticles, {
          x = player.x + math.cos(angle) * M.reflectRadius,
          y = player.y + math.sin(angle) * M.reflectRadius,
          vx = math.cos(angle) * 20,
          vy = math.sin(angle) * 20,
          life = 0.5,
          maxLife = 0.5,
          color = {0.3, 1, 0.5},
          size = 3,
        })
      end
    elseif M.abilityType == "phasecloak" then
      M.phaseAlpha = 0.3 + math.sin(M.abilityFlashTimer * 4) * 0.15
      -- Spawn ghost particles
      if math.random() < 0.2 then
        table.insert(M.abilityParticles, {
          x = player.x + (math.random() - 0.5) * 40,
          y = player.y + (math.random() - 0.5) * 40,
          vx = 0, vy = -30,
          life = 0.6,
          maxLife = 0.6,
          color = {0.5, 0.5, 0.7},
          size = 4,
        })
      end
    elseif M.abilityType == "multilock" then
      -- Bloom particles during targeting
      if math.random() < 0.15 then
        table.insert(M.abilityParticles, {
          x = player.x + (math.random() - 0.5) * 60,
          y = player.y - 20,
          vx = (math.random() - 0.5) * 40,
          vy = -math.random(60, 120),
          life = 0.4,
          maxLife = 0.4,
          color = {1, 0.6, 0.1},
          size = math.random(2, 4),
        })
      end
    elseif M.abilityType == "convert" then
      -- Purple attraction particles
      if math.random() < 0.2 then
        local angle = math.random() * math.pi * 2
        local dist = math.random(80, 150)
        table.insert(M.abilityParticles, {
          x = player.x + math.cos(angle) * dist,
          y = player.y + math.sin(angle) * dist,
          vx = -math.cos(angle) * 100,
          vy = -math.sin(angle) * 100,
          life = 0.5,
          maxLife = 0.5,
          color = {0.6, 0.1, 1},
          size = 3,
        })
      end
    elseif M.abilityType == "empburst" then
      -- Expand EMP burst ring outward
      M.empBurstRadius = M.empBurstRadius + dt * 800
      if M.empBurstRadius > M.empBurstMaxRadius then
        M.empBurstRadius = M.empBurstMaxRadius
      end
      -- Damage enemies caught in the expanding ring
      local enemies = require("starfox.enemies")
      for _, enemy in ipairs(enemies.enemies) do
        if not M.empBurstDamaged[enemy] then
          local dx = enemy.x - player.x
          local dy = enemy.y - player.y
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist <= M.empBurstRadius then
            enemies.damage(enemy, 3)
            M.empBurstDamaged[enemy] = true
            -- EMP spark particles at enemy position
            for j = 1, 5 do
              local angle = math.random() * math.pi * 2
              table.insert(M.abilityParticles, {
                x = enemy.x, y = enemy.y,
                vx = math.cos(angle) * math.random(40, 100),
                vy = math.sin(angle) * math.random(40, 100),
                life = 0.4, maxLife = 0.4,
                color = {0.3, 0.6, 1},
                size = math.random(2, 5),
              })
            end
          end
        end
      end
      -- Ring particles
      if math.random() < 0.5 and M.empBurstRadius < M.empBurstMaxRadius then
        local angle = math.random() * math.pi * 2
        table.insert(M.abilityParticles, {
          x = player.x + math.cos(angle) * M.empBurstRadius,
          y = player.y + math.sin(angle) * M.empBurstRadius,
          vx = math.cos(angle) * 30,
          vy = math.sin(angle) * 30,
          life = 0.5, maxLife = 0.5,
          color = {0.2, 0.5, 1},
          size = math.random(3, 6),
        })
      end
    end

    -- Expire
    if M.abilityTimer <= 0 then
      M.deactivate(player)
    end
  end

  -- Update ability particles
  for i = #M.abilityParticles, 1, -1 do
    local p = M.abilityParticles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    p.vx = p.vx * 0.96
    p.vy = p.vy * 0.96
    if p.life <= 0 then
      table.remove(M.abilityParticles, i)
    end
  end
end

function M.deactivate(player)
  if M.abilityType == "phasecloak" then
    M.phaseAlpha = 1.0
    player.shotgunHeld = false
  end
  if M.abilityType == "reflectshield" then
    M.shieldAlpha = 0
    local weapons = require("starfox.weapons")
    weapons.cancelPaladinCharge()
  end
  if M.abilityType == "multilock" then
    M.multiLockTargeting = false
    -- Multi-lock release is handled by init.lua when timer expires
  end
  if M.abilityType == "empburst" then
    M.empBurstRadius = 0
    M.empBurstDamaged = {}
  end

  M.active = false
  M.abilityType = nil
  M.abilityTimer = 0
  M.abilityDuration = 0
end

--- Returns the enemy speed multiplier while ability is active
function M.getEnemySpeedScale()
  if not M.active then return 1.0 end
  if M.abilityType == "multilock" then return 0.5 end
  if M.abilityType == "reflectshield" then return 0.5 end
  if M.abilityType == "convert" then return 0.75 end
  if M.abilityType == "phasecloak" then return 0.75 end
  if M.abilityType == "empburst" then return 0.3 end
  return 1.0
end

--- Returns true if enemies should be drawn toward the player
function M.shouldAttractEnemies()
  if not M.active then return false end
  return M.abilityType == "convert" or M.abilityType == "phasecloak"
end

--- Returns true if enemies should NOT shoot
function M.shouldSuppressShooting()
  if not M.active then return false end
  return M.abilityType == "convert" or M.abilityType == "phasecloak"
end

--- Returns true if the player should pass through walls (maze)
function M.isPhasing()
  return M.active and M.abilityType == "phasecloak"
end

--- Returns the player draw alpha (for Phantom phase effect)
function M.getPlayerAlpha()
  if M.active and M.abilityType == "phasecloak" then
    return M.phaseAlpha
  end
  return 1.0
end

--- Returns true if bullets should be reflected (Paladin shield)
function M.shouldReflectBullets()
  return M.active and M.abilityType == "reflectshield"
end

--- Returns true if multi-lock targeting is active (Lancer)
function M.isMultiLockActive()
  return M.active and M.abilityType == "multilock"
end

function M.hasInfiniteDodge()
  return M.active and (M.abilityType == "multilock" or M.abilityType == "reflectshield" or M.abilityType == "phasecloak")
end

function M.canContinuousShoot()
  return M.active and M.abilityType == "reflectshield"
end

--- Returns true if phasecloak is active (Phantom)
function M.isPhaseCloakActive()
  return M.active and M.abilityType == "phasecloak"
end

--- Returns true if convert mode is active and we still need kills (Mistral)
function M.isConvertActive()
  return M.active and M.abilityType == "convert" and M.convertKills < M.convertMax
end

--- Register a converted enemy kill (Mistral) - returns true if conversion happened
function M.registerConversion()
  if not M.isConvertActive() then return false end
  M.convertKills = M.convertKills + 1
  return true
end

--- Check if the ship has a special ability
function M.hasSpecial()
  local def = ships.getSelectedDef()
  return def and def.hasSpecial
end

--- Draw ability effects (called from ui.lua)
function M.drawEffects(player)
  if not M.active and #M.abilityParticles == 0 and M.activationFlash <= 0 then return end

  -- Activation flash (screen-wide)
  if M.activationFlash > 0 then
    local def = ships.getSelectedDef()
    if def then
      love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], M.activationFlash * 0.3)
      love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
  end

  -- Ability particles
  for _, p in ipairs(M.abilityParticles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.8)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    -- Glow
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.2)
    love.graphics.circle("fill", p.x, p.y, p.size * alpha * 2.5)
  end

  if not M.active then return end

  -- Reflect Shield visuals (Paladin)
  if M.abilityType == "reflectshield" then
    -- Multi-layer shield
    for i = 3, 1, -1 do
      local radius = M.reflectRadius + i * 8
      local a = M.shieldAlpha * 0.15 / i
      love.graphics.setColor(0.2, 1, 0.4, a)
      love.graphics.circle("fill", player.x, player.y, radius)
    end
    -- Main shield ring
    love.graphics.setColor(0.3, 1, 0.5, M.shieldAlpha * 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", player.x, player.y, M.reflectRadius)
    -- Inner ring
    love.graphics.setColor(0.5, 1, 0.7, M.shieldAlpha * 0.4)
    love.graphics.setLineWidth(1.5)
    local innerPulse = M.reflectRadius - 10 + math.sin(M.abilityFlashTimer * 8) * 5
    love.graphics.circle("line", player.x, player.y, innerPulse)
    love.graphics.setLineWidth(1)

    -- Hexagonal pattern hint
    local segments = 6
    for i = 0, segments - 1 do
      local angle = (i / segments) * math.pi * 2 + M.abilityFlashTimer
      local x1 = player.x + math.cos(angle) * M.reflectRadius
      local y1 = player.y + math.sin(angle) * M.reflectRadius
      love.graphics.setColor(0.5, 1, 0.7, M.shieldAlpha * 0.3)
      love.graphics.circle("fill", x1, y1, 4)
    end
  end

  -- Phase Cloak visuals (Phantom)
  if M.abilityType == "phasecloak" then
    -- Ghost outline
    love.graphics.setColor(0.5, 0.5, 0.8, 0.3 + math.sin(M.abilityFlashTimer * 3) * 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", player.x, player.y, 30 + math.sin(M.abilityFlashTimer * 5) * 3)
    love.graphics.setLineWidth(1)
  end

  -- Multi-Lock visuals (Lancer) — targeting reticle ring
  if M.abilityType == "multilock" then
    local pulse = math.sin(M.abilityFlashTimer * 10) * 0.2 + 0.8
    love.graphics.setColor(1, 0.5, 0.1, 0.3 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", player.x, player.y, 50)
    love.graphics.setLineWidth(1)
    -- Scanning lines
    local scanY = player.y - 200 + (M.abilityFlashTimer % 1) * 400
    love.graphics.setColor(1, 0.6, 0.1, 0.15)
    love.graphics.rectangle("fill", 0, scanY - 2, love.graphics.getWidth(), 4)
  end

  -- Convert visuals (Mistral)
  if M.abilityType == "convert" then
    local pulse = math.sin(M.abilityFlashTimer * 6) * 0.2 + 0.8
    love.graphics.setColor(0.6, 0.1, 1, 0.25 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", player.x, player.y, 40 + math.sin(M.abilityFlashTimer * 4) * 5)
    love.graphics.setLineWidth(1)
    -- Conversion count
    love.graphics.setColor(0.8, 0.4, 1, 0.8)
    love.graphics.printf(M.convertKills .. "/" .. M.convertMax, player.x - 30, player.y - 50, 60, "center")
  end

  -- EMP Burst visuals (Prototype)
  if M.abilityType == "empburst" then
    -- Expanding ring
    if M.empBurstRadius < M.empBurstMaxRadius then
      local ringAlpha = 1.0 - (M.empBurstRadius / M.empBurstMaxRadius)
      love.graphics.setColor(0.2, 0.5, 1, ringAlpha * 0.6)
      love.graphics.setLineWidth(4)
      love.graphics.circle("line", player.x, player.y, M.empBurstRadius)
      -- Secondary ring slightly behind
      love.graphics.setColor(0.4, 0.7, 1, ringAlpha * 0.3)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", player.x, player.y, math.max(0, M.empBurstRadius - 20))
      love.graphics.setLineWidth(1)
    end
    -- Inner glow that fades
    local glowAlpha = math.max(0, 1.0 - M.abilityFlashTimer * 2)
    if glowAlpha > 0 then
      love.graphics.setColor(0.3, 0.6, 1, glowAlpha * 0.2)
      love.graphics.circle("fill", player.x, player.y, 60)
    end
    -- Electric arcs around player
    love.graphics.setColor(0.4, 0.7, 1, 0.4 + math.sin(M.abilityFlashTimer * 15) * 0.2)
    love.graphics.setLineWidth(1.5)
    for i = 0, 3 do
      local angle = (i / 4) * math.pi * 2 + M.abilityFlashTimer * 3
      local r = 25 + math.sin(M.abilityFlashTimer * 8 + i) * 5
      local x1 = player.x + math.cos(angle) * r
      local y1 = player.y + math.sin(angle) * r
      local x2 = player.x + math.cos(angle + 0.5) * (r + 10)
      local y2 = player.y + math.sin(angle + 0.5) * (r + 10)
      love.graphics.line(x1, y1, x2, y2)
    end
    love.graphics.setLineWidth(1)
  end

  -- Timer overlay
  if M.abilityDuration > 0 then
    local pct = M.abilityTimer / M.abilityDuration
    local barW = 60
    local barH = 4
    local barX = player.x - barW / 2
    local barY = player.y + 25

    love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2, 2)

    local def = ships.getSelectedDef()
    if def then
      love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.8)
    else
      love.graphics.setColor(1, 1, 1, 0.8)
    end
    love.graphics.rectangle("fill", barX, barY, barW * pct, barH, 2, 2)
  end
end

--- Draw the special gauge on the HUD (called from hud.lua)
function M.drawGauge()
  local def = ships.getSelectedDef()
  if not def or not def.hasSpecial then return end

  local gaugeWidth = 60
  local gaugeHeight = 15
  local gaugeX = 80  -- Right of dodge gauge
  local gaugeY = 550

  local pct = M.getGaugePercent()

  -- Label
  love.graphics.setFont(love.graphics.newFont(14))
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SPECIAL", 80, 535)

  -- Background
  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.rectangle("fill", gaugeX, gaugeY, gaugeWidth, gaugeHeight)

  -- Fill color based on ship
  if pct >= 1 then
    -- Pulsing when full
    local pulse = math.sin(love.timer.getTime() * 6) * 0.3 + 0.7
    love.graphics.setColor(def.accentColor[1] * pulse, def.accentColor[2] * pulse, def.accentColor[3] * pulse)
  else
    love.graphics.setColor(def.color[1] * 0.8, def.color[2] * 0.8, def.color[3] * 0.8)
  end
  love.graphics.rectangle("fill", gaugeX, gaugeY, gaugeWidth * pct, gaugeHeight)

  -- Border
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", gaugeX, gaugeY, gaugeWidth, gaugeHeight)

  -- "Ready!" animation when full
  if readyAnimActive and not M.active then
    local readyPulse = math.sin(readyAnimTimer * 5) * 0.3 + 0.7
    local scale = 1.0

    -- Initial pop-in
    if readyAnimTimer < 0.3 then
      scale = 1.0 + (1.0 - readyAnimTimer / 0.3) * 0.5
    end

    love.graphics.push()
    love.graphics.translate(gaugeX + gaugeWidth / 2, gaugeY - 12)
    love.graphics.scale(scale, scale)

    -- Glow behind text
    love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], 0.3 * readyPulse)
    love.graphics.rectangle("fill", -30, -8, 60, 16, 4, 4)

    -- Text
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], readyPulse)
    love.graphics.printf("Ready!", -30, -7, 60, "center")

    love.graphics.pop()

    -- Sparkle particles around gauge
    if justBecameReady and readyAnimTimer < 0.5 then
      -- Initial burst effect drawn as radiating dots
      local burstCount = 8
      for i = 0, burstCount - 1 do
        local angle = (i / burstCount) * math.pi * 2 + readyAnimTimer * 3
        local dist = 20 + readyAnimTimer * 60
        local sx = gaugeX + gaugeWidth / 2 + math.cos(angle) * dist
        local sy = gaugeY + gaugeHeight / 2 + math.sin(angle) * dist
        local alpha = 1.0 - readyAnimTimer * 2
        if alpha > 0 then
          love.graphics.setColor(def.accentColor[1], def.accentColor[2], def.accentColor[3], alpha * 0.6)
          love.graphics.circle("fill", sx, sy, 3)
        end
      end
    end
    if readyAnimTimer > 0.5 then
      justBecameReady = false
    end
  end

  -- Morse input hint
  if pct >= 1 and not M.active then
    love.graphics.setFont(love.graphics.newFont(10))
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.print("V: ·−", gaugeX, gaugeY + 17)
  end
end

--- Spawn multi-lock barrage explosion effect (Lancer)
function M.spawnMultiLockBarrage(playerX, playerY, targetCount)
  -- Bloom effect at player
  for i = 1, 20 do
    local angle = math.random() * math.pi * 2
    local speed = math.random(150, 350)
    table.insert(M.abilityParticles, {
      x = playerX, y = playerY,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.6,
      maxLife = 0.6,
      color = {1, 0.7, 0.2},
      size = math.random(4, 8),
    })
  end
  -- White flash particles
  for i = 1, 10 do
    local angle = math.random() * math.pi * 2
    local speed = math.random(100, 200)
    table.insert(M.abilityParticles, {
      x = playerX, y = playerY - 15,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = 0.3,
      maxLife = 0.3,
      color = {1, 1, 1},
      size = math.random(2, 5),
    })
  end
end

return M
