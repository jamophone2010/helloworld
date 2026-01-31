local M = {}
local portals = require("hub.portals")

local fonts = {}

function M.load()
  fonts.normal = love.graphics.newFont(18)
  fonts.large = love.graphics.newFont(28)
end

function M.draw(player, nearbyPortal)
  love.graphics.setBackgroundColor(0.2, 0.2, 0.2)

  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("GAME HUB", 0, 20, 800, "center")

  for _, portal in ipairs(portals.PORTALS) do
    local isNearby = nearbyPortal and nearbyPortal.name == portal.name

    if isNearby then
      love.graphics.setColor(portal.color[1], portal.color[2], portal.color[3], 0.3)
      love.graphics.circle("fill", portal.x, portal.y, portal.radius + 10)
    end

    love.graphics.setColor(portal.color)
    love.graphics.circle("line", portal.x, portal.y, portal.radius, 32)
    love.graphics.circle("line", portal.x, portal.y, portal.radius - 10, 32)

    local darker = {portal.color[1] * 0.5, portal.color[2] * 0.5, portal.color[3] * 0.5}
    love.graphics.setColor(darker)
    love.graphics.circle("fill", portal.x, portal.y, portal.radius - 20)

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(portal.name, portal.x - 100, portal.y - portal.radius - 30, 200, "center")

    if isNearby then
      love.graphics.setFont(fonts.normal)
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("Press E to enter", portal.x - 100, portal.y + portal.radius + 10, 200, "center")
    end
  end

  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", player.x, player.y, player.radius)
  love.graphics.setColor(0.3, 0.3, 0.3)
  love.graphics.circle("line", player.x, player.y, player.radius)

  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Arrow Keys: Move", 10, 550)
  love.graphics.print("E: Enter Portal", 10, 575)
end

return M
