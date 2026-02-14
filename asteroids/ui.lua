local M = {}
local ship = require("asteroids.ship")
local asteroid = require("asteroids.asteroid")
local powerup = require("asteroids.powerup")


local fonts = {}

function M.load()
  fonts.tiny = love.graphics.newFont(12)
  fonts.small = love.graphics.newFont(18)
  fonts.medium = love.graphics.newFont(22)
  fonts.large = love.graphics.newFont(32)
  fonts.huge = love.graphics.newFont(48)
  fonts.hud = love.graphics.newFont(16)
  fonts.hudLabel = love.graphics.newFont(14)
  fonts.hudSmall = love.graphics.newFont(12)
  fonts.title = love.graphics.newFont(36)
  fonts.subtitle = love.graphics.newFont(28)
end

function M.getFont(name)
  return fonts[name] or fonts.small
end

function M.drawShip(s, color)
  local c = color or {1, 1, 1}
  local points = ship.getPoints(s)

  -- Subtle engine glow behind ship
  love.graphics.setColor(c[1], c[2], c[3], 0.08)
  love.graphics.circle("fill", s.x, s.y, s.size * 1.6)

  -- Filled hull
  love.graphics.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.7)
  love.graphics.polygon("fill", points)
  -- Wireframe edge
  love.graphics.setColor(c[1], c[2], c[3])
  love.graphics.polygon("line", points)

  -- Cockpit dot
  love.graphics.setColor(0.3, 0.9, 1, 0.8)
  love.graphics.circle("fill", s.x, s.y, 2)

  if s.shieldTimer > 0 then
    local pulse = math.sin(love.timer.getTime() * 8) * 0.15 + 0.35
    love.graphics.setColor(0.3, 0.5, 1, pulse)
    love.graphics.circle("fill", s.x, s.y, s.size * 1.5)
    love.graphics.setColor(0.5, 0.7, 1, pulse + 0.2)
    love.graphics.circle("line", s.x, s.y, s.size * 1.5)
  end
end

function M.drawAsteroid(a, color)
  love.graphics.setColor(color or {0.7, 0.7, 0.7})
  local radius = asteroid.getRadius(a)
  local sides = 8

  local points = {}
  for i = 0, sides - 1 do
    local angle = a.rotation + (i / sides) * math.pi * 2
    local r = radius * (0.8 + math.sin(i) * 0.2)
    table.insert(points, a.x + math.cos(angle) * r)
    table.insert(points, a.y + math.sin(angle) * r)
  end

  love.graphics.polygon("line", points)
end

function M.drawBullet(b)
  if b.isMissile then
    -- Draw missile trail
    for _, t in ipairs(b.missileTrail or {}) do
      local alpha = t.life / t.maxLife
      love.graphics.setColor(1, 0.4, 0.1, alpha * 0.6)
      love.graphics.circle("fill", t.x, t.y, t.size * alpha)
    end
    -- Missile glow
    love.graphics.setColor(1, 0.2, 0, 0.25)
    love.graphics.circle("fill", b.x, b.y, 12)
    -- Missile body (elongated in direction of travel)
    local angle = b.angle or 0
    love.graphics.push()
    love.graphics.translate(b.x, b.y)
    love.graphics.rotate(angle)
    love.graphics.setColor(1, 0.3, 0.1)
    love.graphics.polygon("fill", 8, 0, -4, -3, -4, 3)  -- Arrow/missile shape
    love.graphics.setColor(1, 0.7, 0.3)
    love.graphics.polygon("line", 8, 0, -4, -3, -4, 3)
    -- Exhaust flame
    local flicker = math.sin(love.timer.getTime() * 30) * 2
    love.graphics.setColor(1, 0.6, 0, 0.9)
    love.graphics.polygon("fill", -4, -2, -8 - flicker, 0, -4, 2)
    love.graphics.pop()
    -- Bright tip
    love.graphics.setColor(1, 1, 0.8, 0.9)
    love.graphics.circle("fill", b.x + math.cos(angle) * 6, b.y + math.sin(angle) * 6, 2)
  else
    local t = love.timer.getTime()
    local pulse = math.sin(t * 12 + b.x * 0.3) * 0.15 + 0.85
    local r = b.size

    -- Outer bloom halo (large, soft)
    love.graphics.setColor(1, 0.7, 0.1, 0.06 * pulse)
    love.graphics.circle("fill", b.x, b.y, r * 6)
    -- Mid bloom
    love.graphics.setColor(1, 0.8, 0.2, 0.12 * pulse)
    love.graphics.circle("fill", b.x, b.y, r * 3.5)
    -- Inner glow
    love.graphics.setColor(1, 0.9, 0.3, 0.35 * pulse)
    love.graphics.circle("fill", b.x, b.y, r * 2)
    -- Core bullet
    love.graphics.setColor(1, 1, 0.7, 0.95)
    love.graphics.circle("fill", b.x, b.y, r)
    -- Hot white center
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", b.x, b.y, r * 0.45)

    -- Tiny motion trail (2 trailing dots)
    local speed = math.sqrt((b.vx or 0)^2 + (b.vy or 0)^2)
    if speed > 10 then
      local nx, ny = (b.vx or 0) / speed, (b.vy or 0) / speed
      for i = 1, 2 do
        local d = i * 4
        local ta = 0.35 - i * 0.12
        love.graphics.setColor(1, 0.85, 0.3, ta * pulse)
        love.graphics.circle("fill", b.x - nx * d, b.y - ny * d, r * (0.7 - i * 0.15))
      end
    end
  end
end

function M.drawUFO(u)
  love.graphics.setColor(0, 1, 0)

  local w = u.size
  local h = u.size * 0.4

  love.graphics.line(u.x - w, u.y, u.x - w/2, u.y - h)
  love.graphics.line(u.x - w/2, u.y - h, u.x + w/2, u.y - h)
  love.graphics.line(u.x + w/2, u.y - h, u.x + w, u.y)
  love.graphics.line(u.x - w, u.y, u.x + w, u.y)
  love.graphics.line(u.x - w/2, u.y, u.x - w, u.y + h/2)
  love.graphics.line(u.x + w/2, u.y, u.x + w, u.y + h/2)
  love.graphics.line(u.x - w, u.y + h/2, u.x + w, u.y + h/2)
end

function M.drawPowerup(p)
  local pType = powerup.TYPES[p.type]
  if not pType then return end
  local color = pType.color
  love.graphics.setColor(color)

  local size = p.size
  local time = love.timer.getTime()
  local pulse = math.sin(time * 4 + p.x * 0.1) * 0.2 + 0.8

  -- Outer glow
  love.graphics.setColor(color[1], color[2], color[3], 0.15 * pulse)
  love.graphics.circle("fill", p.x, p.y, size * 2)

  -- Star shape
  local points = {}
  for i = 0, 4 do
    local angle = p.rotation + (i / 5) * math.pi * 2
    table.insert(points, p.x + math.cos(angle) * size)
    table.insert(points, p.y + math.sin(angle) * size)
    local innerAngle = p.rotation + ((i + 0.5) / 5) * math.pi * 2
    table.insert(points, p.x + math.cos(innerAngle) * size * 0.5)
    table.insert(points, p.y + math.sin(innerAngle) * size * 0.5)
  end

  love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, 0.4)
  love.graphics.polygon("fill", points)
  love.graphics.setColor(color[1], color[2], color[3], pulse)
  love.graphics.polygon("line", points)

  love.graphics.setFont(fonts.hudSmall)
  love.graphics.setColor(1, 1, 1)
  local label = powerup.getLabel(p.type)
  love.graphics.printf(label, p.x - 10, p.y - 6, 20, "center")
end

function M.drawParticle(p)
  local alpha = p.lifetime / p.maxLife
  -- Outer bloom glow
  love.graphics.setColor(1, 0.5, 0, alpha * 0.08)
  love.graphics.circle("fill", p.x, p.y, 8)
  love.graphics.setColor(1, 0.5, 0, alpha * 0.2)
  love.graphics.circle("fill", p.x, p.y, 4)
  -- Core
  love.graphics.setColor(1, 0.7, 0.15, alpha)
  love.graphics.circle("fill", p.x, p.y, 2)
  love.graphics.setColor(1, 1, 0.8, alpha * 0.7)
  love.graphics.circle("fill", p.x, p.y, 1)
end

function M.drawHUD(health, score, level)
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 1, 1)

  love.graphics.print("Score: " .. score, 10, 10)
  love.graphics.print("Level: " .. level, 10, 35)

  local barWidth = 200
  local barHeight = 20
  local barX = 10
  local barY = 60

  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

  local healthPercent = math.max(0, health / 100)
  local healthColor = healthPercent > 0.5 and {0, 1, 0} or (healthPercent > 0.25 and {1, 1, 0} or {1, 0, 0})
  love.graphics.setColor(healthColor)
  love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
  love.graphics.printf("Health: " .. math.floor(health), barX, barY + 3, barWidth, "center")
end

function M.drawMenu()
  love.graphics.setBackgroundColor(0, 0, 0)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("ASTEROIDS", 0, 200, 800, "center")

  love.graphics.setFont(fonts.small)
  love.graphics.printf("Press SPACE to start", 0, 280, 800, "center")
  love.graphics.printf("Arrow Keys: Move | SPACE: Shoot | X: Hyperspace", 0, 320, 800, "center")
end

function M.drawGameOver(score, level)
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 0, 0)
  love.graphics.printf("GAME OVER", 0, 200, 800, "center")

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Final Score: " .. score, 0, 260, 800, "center")
  love.graphics.printf("Level Reached: " .. level, 0, 290, 800, "center")
  love.graphics.printf("Press R to restart", 0, 330, 800, "center")
end

return M
