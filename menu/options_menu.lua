local M = {}

local galaxy = require("menu.galaxy")

local fonts = {}

M.onBack = nil

function M.load()
  fonts.title = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 40)
  fonts.menu = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 28)
  fonts.info = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 16)
end

function M.update(dt)
  galaxy.update(dt)
end

function M.draw()
  -- Galaxy background
  galaxy.draw()

  -- Semi-transparent purple overlay
  love.graphics.setColor(0.08, 0.05, 0.15, 0.75)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("OPTIONS", 0, 50, 1366, "center")

  -- Placeholder
  love.graphics.setFont(fonts.menu)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Options coming soon...", 0, 300, 1366, "center")

  -- Instructions
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("ESC: Back to Main Menu", 0, 700, 1366, "center")
end

function M.keypressed(key)
  if key == "escape" then
    if M.onBack then
      M.onBack()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for options menu
end

return M
