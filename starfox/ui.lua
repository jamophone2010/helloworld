local M = {}
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

local fonts = {}
local currentLevelId = 1

function M.setLevelId(levelId)
  currentLevelId = levelId
end

function M.isSectorX()
  return currentLevelId == 8
end

function M.load()
  fonts.large = love.graphics.newFont(36)
  fonts.normal = love.graphics.newFont(20)
  hud.load()
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

function M.drawPlayer(player)
  if player.invulnerable and math.floor(love.timer.getTime() * 10) % 2 == 0 then
    return
  end

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
  love.graphics.translate(player.x, player.y)

  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.polygon("fill", 0, -20, -15, 15, 15, 15)

  love.graphics.setColor(0.5, 0.7, 1)
  love.graphics.polygon("fill", -25, 10, -15, 5, -15, 15, -25, 15)
  love.graphics.polygon("fill", 25, 10, 15, 5, 15, 15, 25, 15)

  love.graphics.setColor(1, 1, 1)
  love.graphics.polygon("line", 0, -20, -15, 15, 15, 15)

  if player.charging and player.chargeLevel > 0.2 then
    local size = 5 + player.chargeLevel * 15
    love.graphics.setColor(0.3, 0.8, 1, 0.5 + player.chargeLevel * 0.5)
    love.graphics.circle("fill", 0, -20, size)
  end

  love.graphics.pop()
end

function M.drawWingmen()
  for _, wingman in ipairs(wingmen.wingmen) do
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.polygon("fill", wingman.x, wingman.y - 10, wingman.x - 8, wingman.y + 8, wingman.x + 8, wingman.y + 8)
  end
end

function M.drawLasers()
  for _, laser in ipairs(weapons.lasers) do
    local r, g, b = 0, 1, 0
    if laser.owner == "player" then
      if laser.charged then
        r, g, b = 0.3, 0.8, 1
      else
        r, g, b = 0, 1, 0
      end
    elseif laser.owner == "ally" then
      r, g, b = 0.3, 0.8, 1
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
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", laser.x - laser.width/2, laser.y - laser.height/2, laser.width, laser.height)
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

    love.graphics.setColor(1, 0.3, 0.3, alpha)
    love.graphics.polygon("fill", enemy.x, enemy.y + 15, enemy.x - 12, enemy.y - 10, enemy.x + 12, enemy.y - 10)

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
    love.graphics.rectangle("fill", wall.gapRight, wall.y, 800 - wall.gapRight, wall.height)

    -- Wall outlines
    love.graphics.setColor(0.5, 0.4, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, wall.y, wall.gapLeft, wall.height)
    love.graphics.rectangle("line", wall.gapRight, wall.y, 800 - wall.gapRight, wall.height)

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

function M.drawParticles()
  for _, p in ipairs(particles.particles) do
    local alpha = p.life / p.maxLife
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
    love.graphics.circle("fill", p.x, p.y, p.size)
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
  love.graphics.printf("STARFOX 2D", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("CORNERIA", 0, 250, 800, "center")
  love.graphics.printf("Press SPACE to start", 0, 320, 800, "center")
  love.graphics.printf("Arrows: Move | SPACE: Shoot | Z: Barrel Roll | X: Bomb", 0, 360, 800, "center")
end

function M.drawGameOver(score)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 0, 0)
  love.graphics.printf("MISSION FAILED", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 280, 800, "center")
  love.graphics.printf("Press R to retry", 0, 340, 800, "center")
end

function M.drawVictory(score)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0, 1, 0)
  love.graphics.printf("MISSION COMPLETE", 0, 200, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 280, 800, "center")
  love.graphics.printf("Press R to play again", 0, 340, 800, "center")
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
  love.graphics.printf("WARP ZONE!", 0, 180, 800, "center")

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.6, 0.9, 1)
  love.graphics.printf("All 7 portals collected!", 0, 240, 800, "center")

  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 300, 800, "center")
  love.graphics.printf("SECRET PATH UNLOCKED", 0, 340, 800, "center")
  love.graphics.printf("Press R to continue", 0, 400, 800, "center")
end

function M.drawLevelSelect()
  love.graphics.setBackgroundColor(0.01, 0.01, 0.08)

  -- Draw static stars
  for _, star in ipairs(levelselect.getStars()) do
    love.graphics.setColor(1, 1, 1, star.brightness)
    love.graphics.circle("fill", star.x, star.y, star.size)
  end

  local planets = levelselect.getPlanets()
  local selected = levelselect.getSelected()

  -- Draw connection lines
  love.graphics.setColor(0.3, 0.4, 0.6, 0.6)
  love.graphics.setLineWidth(2)
  for _, planet in ipairs(planets) do
    for _, connId in ipairs(planet.connections) do
      if connId > planet.id then
        local conn = planets[connId]
        love.graphics.line(planet.x, planet.y, conn.x, conn.y)
      end
    end
  end

  -- Draw planets
  for _, planet in ipairs(planets) do
    local isSelected = (planet.id == selected.id)
    local radius = isSelected and 20 or 14

    -- Glow for selected
    if isSelected then
      love.graphics.setColor(0.3, 0.5, 1, 0.4)
      love.graphics.circle("fill", planet.x, planet.y, radius + 8)
    end

    -- Planet body
    love.graphics.setColor(0.2, 0.4, 0.7)
    love.graphics.circle("fill", planet.x, planet.y, radius)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("line", planet.x, planet.y, radius)

    -- Planet name
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(planet.name, planet.x - 50, planet.y + radius + 4, 100, "center")
  end

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("LYLAT SYSTEM", 0, 550, 800, "center")

  -- Instructions
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Arrows: Navigate | SPACE: Select | ESC: Back", 0, 580, 800, "center")
end

return M
