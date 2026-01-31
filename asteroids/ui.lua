local M = {}
local ship = require("asteroids.ship")
local asteroid = require("asteroids.asteroid")
local powerup = require("asteroids.powerup")


local fonts = {}

function M.load()
  fonts.small = love.graphics.newFont(16)
  fonts.large = love.graphics.newFont(32)
end

function M.drawShip(s)
  local points = ship.getPoints(s)

  love.graphics.setColor(1, 1, 1)
  love.graphics.polygon("line", points)

  if s.shieldTimer > 0 then
    love.graphics.setColor(0.3, 0.5, 1, 0.3)
    love.graphics.circle("fill", s.x, s.y, s.size * 1.5)
  end
end

function M.drawAsteroid(a)
  love.graphics.setColor(0.7, 0.7, 0.7)
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
  love.graphics.setColor(1, 1, 0)
  love.graphics.circle("fill", b.x, b.y, b.size)
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
  local color = powerup.TYPES[p.type].color
  love.graphics.setColor(color)

  local size = p.size
  local points = {}
  for i = 0, 4 do
    local angle = p.rotation + (i / 5) * math.pi * 2
    table.insert(points, p.x + math.cos(angle) * size)
    table.insert(points, p.y + math.sin(angle) * size)
  end

  love.graphics.polygon("line", points)

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(1, 1, 1)
  local label = p.type == "shield" and "S" or (p.type == "rapidfire" and "R" or "H")
  love.graphics.printf(label, p.x - 10, p.y - 8, 20, "center")
end

function M.drawParticle(p)
  local alpha = p.lifetime / p.maxLife
  love.graphics.setColor(1, 0.5, 0, alpha)
  love.graphics.circle("fill", p.x, p.y, 2)
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
