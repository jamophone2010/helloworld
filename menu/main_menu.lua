local M = {}

local galaxy = require("menu.galaxy")

local menuItems = {"New Game", "Continue", "Options", "Exit to Desktop"}
local selectedIndex = 1
local fonts = {}

local screen = "pressstart"  -- "pressstart" | "menu"
local dimAlpha = 0
local blinkTimer = 0

M.onNewGame = nil
M.onContinue = nil
M.onOptions = nil

function M.load()
  fonts.title = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 68)
  fonts.titleBold = love.graphics.newFont("fonts/EBGaramond-Bold.ttf", 68)
  fonts.menu = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 32)
  fonts.pressStart = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 26)
  fonts.hint = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 16)
  selectedIndex = 1
  screen = "pressstart"
  dimAlpha = 0
  blinkTimer = 0
  galaxy.load()
end

function M.update(dt)
  galaxy.update(dt)
  blinkTimer = blinkTimer + dt
  if screen == "menu" and dimAlpha < 0.58 then
    dimAlpha = math.min(0.58, dimAlpha + dt * 2.5)
  end
end

function M.draw()
  galaxy.draw()

  -- Dim overlay fades in when entering menu
  if dimAlpha > 0 then
    love.graphics.setColor(0, 0, 0, dimAlpha)
    love.graphics.rectangle("fill", 0, 0, 1366, 768)
  end

  -- Title: always shown
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("STARLIGHT", 0, 80, 1366, "center")
  love.graphics.printf("SYMPHONY",  0, 135, 1366, "center")

  if screen == "pressstart" then
    -- Fade in/out "PRESS START"
    local alpha = (math.sin(blinkTimer * 1.4) * 0.5 + 0.5) * 0.85
    love.graphics.setFont(fonts.pressStart)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("PRESS START", 0, 610, 1366, "center")
  else
    -- Menu items
    love.graphics.setFont(fonts.menu)
    local startY = 250
    local itemHeight = 80

    for i, item in ipairs(menuItems) do
      if i == selectedIndex then
        love.graphics.setColor(1, 1, 0)
        love.graphics.rectangle("line", 400, startY + (i - 1) * itemHeight - 10, 566, 60)
      else
        love.graphics.setColor(0.7, 0.7, 0.7)
      end
      love.graphics.printf(item, 0, startY + (i - 1) * itemHeight, 1366, "center")
    end

    love.graphics.setFont(fonts.hint)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("UP/DOWN: select  |  ENTER: confirm", 0, 710, 1366, "center")
  end
end

function M.keypressed(key)
  if screen == "pressstart" then
    if key == "space" or key == "e" or key == "return" then
      screen = "menu"
    end
    return
  end

  if key == "up" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then selectedIndex = #menuItems end
  elseif key == "down" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #menuItems then selectedIndex = 1 end
  elseif key == "return" then
    if selectedIndex == 1 then
      if M.onNewGame then M.onNewGame() end
    elseif selectedIndex == 2 then
      if M.onContinue then M.onContinue() end
    elseif selectedIndex == 3 then
      if M.onOptions then M.onOptions() end
    elseif selectedIndex == 4 then
      love.event.quit()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for main menu
end

return M
