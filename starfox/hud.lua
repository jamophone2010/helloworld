local M = {}

local screen = require("starfox.screen")
local player = require("starfox.player")
local abilities = require("starfox.abilities")

local fonts = {}

function M.load()
  fonts.small = love.graphics.newFont(14)
  fonts.normal = love.graphics.newFont(18)
  fonts.large = love.graphics.newFont(24)
end

function M.draw(p, levelTime, callout, bossHealth, bossMaxHealth, levelName, portalCount, totalEnemiesSpawned)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SHIELD", 10, 10)

  local shieldWidth = 150
  local shieldPercent = p.health / p.maxHealth

  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.rectangle("fill", 80, 10, shieldWidth, 20)

  local shieldColor = shieldPercent > 0.5 and {0, 1, 0} or (shieldPercent > 0.25 and {1, 1, 0} or {1, 0, 0})
  love.graphics.setColor(shieldColor)
  love.graphics.rectangle("fill", 80, 10, shieldWidth * shieldPercent, 20)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", 80, 10, shieldWidth, 20)

  love.graphics.setColor(1, 1, 1)
  love.graphics.print("BOMBS:", 250, 10)
  for i = 1, 3 do
    if i <= p.bombs then
      love.graphics.setColor(1, 0.8, 0)
    else
      love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.circle("fill", 320 + i * 20, 20, 8)
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.print("LIVES: " .. p.lives, 420, 10)

  -- Determine enemies counter color
  local enemiesColor = {1, 1, 1}  -- Default white
  if p.enemiesEscaped == 0 then
    -- Gold if no enemies escaped
    enemiesColor = {1, 0.84, 0}
  elseif totalEnemiesSpawned and totalEnemiesSpawned > 0 then
    local killPercentage = (p.enemiesDefeated / totalEnemiesSpawned) * 100
    if killPercentage < 60 then
      -- Red if below 60%
      enemiesColor = {1, 0, 0}
    end
    -- Otherwise stays white
  end

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(enemiesColor)
  love.graphics.printf("ENEMIES: " .. p.enemiesDefeated, screen.WIDTH - 200, 10, 190, "right")

  love.graphics.setFont(fonts.small)
  love.graphics.printf(levelName or "CORNERIA", screen.WIDTH - 200, 35, 190, "right")

  -- Time counter
  local minutes = math.floor(levelTime / 60)
  local seconds = math.floor(levelTime % 60)
  local timeStr = string.format("%02d:%02d", minutes, seconds)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(timeStr, screen.WIDTH - 200, screen.HEIGHT - 40, 190, "right")

  if p.charging and p.chargeLevel > 0 then
    local chargeWidth = 100
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 350, screen.HEIGHT - 50, chargeWidth, 15)

    love.graphics.setColor(0.3, 0.5, 1)
    love.graphics.rectangle("fill", 350, screen.HEIGHT - 50, chargeWidth * p.chargeLevel, 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 350, screen.HEIGHT - 50, chargeWidth, 15)

    love.graphics.print("CHARGE", 350, screen.HEIGHT - 65)
  end

  -- Dodge cooldown gauge
  local dodgeWidth = 60
  local dodgeMax = player.getDodgeCooldownMax()
  local dodgeReady = (dodgeMax - p.dodgeCooldown) / dodgeMax
  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.rectangle("fill", 10, screen.HEIGHT - 50, dodgeWidth, 15)

  if dodgeReady >= 1 then
    love.graphics.setColor(0.2, 0.8, 0.4)
  else
    love.graphics.setColor(0.6, 0.4, 0.2)
  end
  love.graphics.rectangle("fill", 10, screen.HEIGHT - 50, dodgeWidth * dodgeReady, 15)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", 10, screen.HEIGHT - 50, dodgeWidth, 15)
  love.graphics.setFont(fonts.small)
  love.graphics.print("DODGE", 10, screen.HEIGHT - 65)

  -- Special ability gauge (drawn right of dodge)
  abilities.drawGauge()

  -- Weapon indicator
  if p.hasLaser then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WEAPON: " .. (p.currentWeapon == "blaster" and "BLASTER" or "SPARTAN LASER"), 10, 70)
    
    -- Spartan Laser cooldown timer (only show when cooling down)
    if p.currentWeapon == "laser" and p.laserCooldown > 0 then
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 0.5, 0)
      love.graphics.printf("COOLDOWN: " .. string.format("%.1f", p.laserCooldown) .. "s", 10, 90, 200, "left")
    end
    
    -- Laser firing indicator
    if p.laserFiring then
      local fireWidth = 100
      local firePercent = p.laserFireTime / 5.0
      
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print("LASER POWER", 10, 105)
      
      love.graphics.setColor(0.3, 0.3, 0.3)
      love.graphics.rectangle("fill", 10, 120, fireWidth, 15)
      
      love.graphics.setColor(1, 0, 0)
      love.graphics.rectangle("fill", 10, 120, fireWidth * firePercent, 15)
      
      love.graphics.setColor(1, 1, 1)
      love.graphics.rectangle("line", 10, 120, fireWidth, 15)
      
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(1, 1, 0)
      love.graphics.print("DPS: " .. string.format("%.1f", math.pow(3, p.laserFireTime)), 10, 140)
    end
  end

  if callout then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.printf(callout.speaker .. ": \"" .. callout.message .. "\"", 50, screen.HEIGHT - 30, screen.WIDTH - 100, "center")
  end

  if bossHealth and bossMaxHealth then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("BOSS", screen.WIDTH / 2 - 100, 50, 200, "center")

    local bossBarWidth = 200
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, 65, bossBarWidth, 15)

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", screen.WIDTH / 2 - 100, 65, bossBarWidth * (bossHealth / bossMaxHealth), 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", screen.WIDTH / 2 - 100, 65, bossBarWidth, 15)
  end

  -- Portal counter (only show if portals exist in level)
  if portalCount and portalCount > 0 then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0.4, 0.8, 1)
    love.graphics.print("WARP RINGS: " .. portalCount .. "/7", 10, 40)

    -- Progress indicators
    for i = 1, 7 do
      if i <= portalCount then
        love.graphics.setColor(0.4, 0.8, 1)
      else
        love.graphics.setColor(0.2, 0.3, 0.4)
      end
      love.graphics.circle("fill", 140 + i * 18, 50, 6)
    end
  end
end

return M
