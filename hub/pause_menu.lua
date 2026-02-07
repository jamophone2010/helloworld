local M = {}

local menuItems = {"Resume", "Options", "Save", "Exit to Main Menu", "Exit to Desktop"}
local selectedIndex = 1
local fonts = {}

M.onResume = nil
M.onOptions = nil
M.onSave = nil
M.onExitToMenu = nil

function M.load()
  fonts.title = love.graphics.newFont(32)
  fonts.menu = love.graphics.newFont(24)
  fonts.small = love.graphics.newFont(14)
  selectedIndex = 1
end

function M.update(dt)
  -- Nothing to update
end

function M.draw()
  -- Semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(0.3, 0.5, 1)
  love.graphics.printf("PAUSED", 0, 200, 1366, "center")

  -- Menu items
  love.graphics.setFont(fonts.menu)
  local startY = 320
  local itemHeight = 50

  for i, item in ipairs(menuItems) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. item .. " <", 0, startY + (i - 1) * itemHeight, 1366, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(item, 0, startY + (i - 1) * itemHeight, 1366, "center")
    end
  end

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Arrows: Navigate | ENTER: Select | ESC: Resume", 0, 650, 1366, "center")
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
  elseif key == "escape" then
    if M.onResume then
      M.onResume()
    end
  elseif key == "return" or key == "space" then
    if selectedIndex == 1 then
      -- Resume
      if M.onResume then
        M.onResume()
      end
    elseif selectedIndex == 2 then
      -- Options
      if M.onOptions then
        M.onOptions()
      end
    elseif selectedIndex == 3 then
      -- Save
      if M.onSave then
        M.onSave()
      end
    elseif selectedIndex == 4 then
      -- Exit to Main Menu
      if M.onExitToMenu then
        M.onExitToMenu()
      end
    elseif selectedIndex == 5 then
      -- Exit to Desktop
      love.event.quit()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for pause menu
end

return M
