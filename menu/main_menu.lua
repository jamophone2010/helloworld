local M = {}

local menuItems = {"New Game", "Continue", "Options", "Exit to Desktop"}
local selectedIndex = 1
local fonts = {}

M.onNewGame = nil
M.onContinue = nil
M.onOptions = nil

function M.load()
  fonts.title = love.graphics.newFont(48)
  fonts.menu = love.graphics.newFont(32)
  selectedIndex = 1
end

function M.update(dt)
  -- Nothing to update
end

function M.draw()
  -- Background
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("STARLIGHT SYMPHONY", 0, 100, 1366, "center")

  -- Menu items
  love.graphics.setFont(fonts.menu)
  local startY = 250
  local itemHeight = 80

  for i, item in ipairs(menuItems) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      -- Draw selection highlight
      love.graphics.rectangle("line", 400, startY + (i - 1) * itemHeight - 10, 566, 60)
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
    end
    love.graphics.printf(item, 0, startY + (i - 1) * itemHeight, 1366, "center")
  end

  -- Instructions
  love.graphics.setFont(love.graphics.newFont(16))
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Use UP/DOWN arrows to select, ENTER to confirm", 0, 700, 1366, "center")
end

function M.keypressed(key)
  if key == "up" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then
      selectedIndex = #menuItems
    end
  elseif key == "down" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #menuItems then
      selectedIndex = 1
    end
  elseif key == "return" then
    if selectedIndex == 1 then
      -- New Game
      if M.onNewGame then
        M.onNewGame()
      end
    elseif selectedIndex == 2 then
      -- Continue
      if M.onContinue then
        M.onContinue()
      end
    elseif selectedIndex == 3 then
      -- Options
      if M.onOptions then
        M.onOptions()
      end
    elseif selectedIndex == 4 then
      -- Exit to Desktop
      love.event.quit()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for main menu
end

return M
