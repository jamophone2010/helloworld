local M = {}

local currency = require("hub.currency")
local fonts = {}
local selectedIndex = 1
local notes = 0

local items = {
  {name = "Health Pack", cost = 5, desc = "Restore 50 HP", type = "health", value = 50},
  {name = "Extra Life", cost = 10, desc = "+1 Life for StarFox", type = "lives", value = 1},
  {name = "Smart Bomb", cost = 3, desc = "+1 Bomb for StarFox", type = "bombs", value = 1},
  {name = "Spartan Laser", cost = 20, desc = "Powerful beam weapon (Z to switch)", type = "laser", value = 1}
}

function M.load()
  fonts.normal = love.graphics.newFont(14)
  fonts.large = love.graphics.newFont(20)
  fonts.small = love.graphics.newFont(12)
  selectedIndex = 1
end

function M.update(dt)
  -- Nothing to update
end

function M.draw()
  -- Get current notes value
  local hub = require("hub")
  notes = hub.getNotes() or 0
  
  -- Background
  love.graphics.setColor(0.2, 0.2, 0.3)
  love.graphics.rectangle("fill", 0, 0, 800, 600)

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("SHOP", 0, 50, 800, "center")

  -- Notes balance
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Your Notes: " .. notes, 0, 90, 800, "center")

  -- Menu box
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", 150, 150, 500, 350)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", 150, 150, 500, 350)

  -- Items
  love.graphics.setFont(fonts.normal)
  local yOffset = 180
  for i, item in ipairs(items) do
    if i == selectedIndex then
      love.graphics.setColor(1, 1, 0)
      love.graphics.printf("> " .. item.name .. " - " .. item.cost .. " Notes", 170, yOffset, 460, "left")
    else
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf("  " .. item.name .. " - " .. item.cost .. " Notes", 170, yOffset, 460, "left")
    end
    yOffset = yOffset + 30
  end

  -- Selected item description
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf(items[selectedIndex].desc, 170, yOffset + 20, 460, "left")

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.print("Arrow Keys: Navigate | E: Buy | ESC: Exit", 170, 470)

  -- Insufficient funds warning
  if notes < items[selectedIndex].cost then
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("Insufficient Notes!", 0, 520, 800, "center")
  end
end

function M.keypressed(key)
  if key == "escape" then
    if returnToHub then
      returnToHub()
    end
  elseif key == "up" then
    selectedIndex = selectedIndex - 1
    if selectedIndex < 1 then
      selectedIndex = #items
    end
  elseif key == "down" then
    selectedIndex = selectedIndex + 1
    if selectedIndex > #items then
      selectedIndex = 1
    end
  elseif key == "e" then
    local item = items[selectedIndex]
    if notes >= item.cost then
      local hub = require("hub")
      if hub.spendNotes(item.cost) then
        notes = notes - item.cost
        -- Add item to shop items
        local shopItems = hub.getShopItems()
        if item.type == "laser" then
          shopItems.laser = true
        else
          shopItems[item.type] = shopItems[item.type] + item.value
        end
        -- Note: spendNotes already saves, no need to save again
      end
    end
  end
end

return M
