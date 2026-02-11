local M = {}

local selectedIndex = 1
local fonts = {}

M.onResume = nil
M.onOptions = nil
M.onSave = nil
M.onExitToMenu = nil
M.returnToShip = nil  -- Set for non-hometown hubs to add "Return to Ship" option

local function buildMenuItems()
  if M.returnToShip then
    return {"Resume", "Options", "Save", "Return to Ship", "Exit to Main Menu", "Exit to Desktop"}
  else
    return {"Resume", "Options", "Save", "Exit to Main Menu", "Exit to Desktop"}
  end
end

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
  local menuItems = buildMenuItems()

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
  local menuItems = buildMenuItems()
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
    local item = menuItems[selectedIndex]
    if item == "Resume" then
      if M.onResume then M.onResume() end
    elseif item == "Options" then
      if M.onOptions then M.onOptions() end
    elseif item == "Save" then
      if M.onSave then M.onSave() end
    elseif item == "Return to Ship" then
      if M.returnToShip then M.returnToShip() end
    elseif item == "Exit to Main Menu" then
      if M.onExitToMenu then M.onExitToMenu() end
    elseif item == "Exit to Desktop" then
      love.event.quit()
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for pause menu
end

return M
