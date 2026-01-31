local M = {}

local fonts = {}

function M.load()
  fonts.small = love.graphics.newFont(14)
  fonts.normal = love.graphics.newFont(18)
  fonts.large = love.graphics.newFont(24)
end

function M.draw(player, levelTime, callout, bossHealth, bossMaxHealth)
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("SHIELD", 10, 10)

  local shieldWidth = 150
  local shieldPercent = player.health / player.maxHealth

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
    if i <= player.bombs then
      love.graphics.setColor(1, 0.8, 0)
    else
      love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.circle("fill", 320 + i * 20, 20, 8)
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.print("LIVES: " .. player.lives, 400, 10)

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(string.format("%06d", player.score), 600, 10, 190, "right")

  love.graphics.setFont(fonts.small)
  love.graphics.printf("CORNERIA", 600, 35, 190, "right")

  if player.charging and player.chargeLevel > 0 then
    local chargeWidth = 100
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 350, 550, chargeWidth, 15)

    love.graphics.setColor(0.3, 0.5, 1)
    love.graphics.rectangle("fill", 350, 550, chargeWidth * player.chargeLevel, 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 350, 550, chargeWidth, 15)

    love.graphics.print("CHARGE", 350, 535)
  end

  if callout then
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.printf(callout.speaker .. ": \"" .. callout.message .. "\"", 50, 570, 700, "center")
  end

  if bossHealth and bossMaxHealth then
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("BOSS", 300, 50, 200, "center")

    local bossBarWidth = 200
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 300, 65, bossBarWidth, 15)

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 300, 65, bossBarWidth * (bossHealth / bossMaxHealth), 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 300, 65, bossBarWidth, 15)
  end
end

return M
