local M = {}

local galaxy = require("menu.galaxy")
local resolution = require("resolution")
local controller = require("controller")

local fonts = {}
local selectedIndex = 1

M.onBack = nil

local menuItems = {}  -- built dynamically

local function buildMenuItems()
  return {
    { label = "Resolution: " .. resolution.getCurrentLabel(), type = "resolution" },
    { label = "Controller: " .. controller.getCurrentLabel(), type = "controller" },
    { label = "Back", type = "back" },
  }
end

function M.load()
  fonts.title = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 40)
  fonts.menu  = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 28)
  fonts.info  = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 16)
  selectedIndex = 1
  menuItems = buildMenuItems()
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

  -- Menu items
  love.graphics.setFont(fonts.menu)
  local startY = 260
  local itemHeight = 70

  for i, item in ipairs(menuItems) do
    local y = startY + (i - 1) * itemHeight

    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      -- Highlight box
      love.graphics.rectangle("line", 350, y - 8, 666, 50)
      love.graphics.printf(item.label, 0, y, 1366, "center")
    else
      love.graphics.setColor(0.7, 0.7, 0.7)
      love.graphics.printf(item.label, 0, y, 1366, "center")
    end
  end

  -- Contextual hint for cycling rows
  local selItem = menuItems[selectedIndex]
  if selItem and selItem.type == "resolution" then
    love.graphics.setFont(fonts.info)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("< LEFT / RIGHT > to change resolution  |  ENTER to apply", 0, startY + #menuItems * itemHeight - 10, 1366, "center")
  elseif selItem and selItem.type == "controller" then
    love.graphics.setFont(fonts.info)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("< LEFT / RIGHT > to change controller  |  ENTER to apply", 0, startY + #menuItems * itemHeight - 10, 1366, "center")
  end

  -- Instructions
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("UP/DOWN: Navigate  |  ESC: Back", 0, 700, 1366, "center")
end

function M.keypressed(key)
  if key == "up" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then selectedIndex = #menuItems end
  elseif key == "down" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #menuItems then selectedIndex = 1 end
  elseif key == "left" then
    if menuItems[selectedIndex].type == "resolution" then
      resolution.prevPreset()
      menuItems = buildMenuItems()
    elseif menuItems[selectedIndex].type == "controller" then
      controller.prevPreset()
      menuItems = buildMenuItems()
    end
  elseif key == "right" then
    if menuItems[selectedIndex].type == "resolution" then
      resolution.nextPreset()
      menuItems = buildMenuItems()
    elseif menuItems[selectedIndex].type == "controller" then
      controller.nextPreset()
      menuItems = buildMenuItems()
    end
  elseif key == "return" then
    local item = menuItems[selectedIndex]
    if item.type == "resolution" then
      -- Apply the selected resolution and save preference
      resolution.apply()
      resolution.save()
      menuItems = buildMenuItems()
    elseif item.type == "controller" then
      -- Save the selected controller preference
      controller.save()
      menuItems = buildMenuItems()
    elseif item.type == "back" then
      if M.onBack then M.onBack() end
    end
  elseif key == "escape" then
    if M.onBack then M.onBack() end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for options menu
end

return M
