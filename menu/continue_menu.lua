local M = {}

local galaxy = require("menu.galaxy")
local saves = require("menu.saves")
local selectedSlot = 1
local fonts = {}
local state = "selecting" -- "selecting", "confirm_delete"

local fadeState = {
  active = false,
  alpha = 0,
  callback = nil
}

M.onSelectSave = nil
M.onBack = nil

function M.load()
  fonts.title = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 40)
  fonts.menu = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 28)
  fonts.info = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 16)
  selectedSlot = 1
  state = "selecting"
  fadeState.active = false
  fadeState.alpha = 0
  fadeState.callback = nil
end

function M.update(dt)
  galaxy.update(dt)

  -- Fade out to white
  if fadeState.active then
    fadeState.alpha = math.min(1.0, fadeState.alpha + dt * 2.0)
    if fadeState.alpha >= 1.0 and fadeState.callback then
      local cb = fadeState.callback
      fadeState.callback = nil
      cb()
    end
  end
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
  love.graphics.printf("LOAD GAME", 0, 50, 1366, "center")

  -- Save slots
  love.graphics.setFont(fonts.menu)
  local startY = 200
  local slotHeight = 130

  for slot = 1, 3 do
    local saveData = saves.getSave(slot)
    local x = 150
    local y = startY + (slot - 1) * slotHeight

    if slot == selectedSlot then
      love.graphics.setColor(1, 1, 0)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", x - 10, y - 10, 1066, 110)
    else
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", x - 10, y - 10, 1066, 110)
    end

    if saveData then
      love.graphics.setColor(1, 1, 1)
      love.graphics.printf("Slot " .. slot .. " - " .. (saveData.name or "Unknown"), x, y, 1066 - 20, "left")

      love.graphics.setFont(fonts.info)
      love.graphics.setColor(0.8, 0.8, 0.8)
      local timeStr = saves.formatTime(saveData.timePlayed or 0)
      love.graphics.printf("Time: " .. timeStr .. " | Last Saved: " .. (saveData.lastPlayed or "Unknown"), x, y + 35, 1066 - 20, "left")
      love.graphics.printf("Credits: " .. (saveData.credits or 0) .. " | Notes: " .. (saveData.notes or 0), x, y + 60, 1066 - 20, "left")
      love.graphics.setFont(fonts.menu)
    else
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.printf("Slot " .. slot .. " - [Empty]", x, y + 30, 1066 - 20, "center")
    end
  end

  -- Draw delete confirmation dialog
  if state == "confirm_delete" then
    M.drawConfirmDialog()
  end

  -- Instructions
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.5, 0.5, 0.5)
  if state == "selecting" then
    love.graphics.printf("UP/DOWN: Select | ENTER: Load | X: Delete | ESC: Back", 0, 700, 1366, "center")
  end

  -- Black fade overlay
  if fadeState.active and fadeState.alpha > 0 then
    love.graphics.setColor(0, 0, 0, fadeState.alpha)
    love.graphics.rectangle("fill", 0, 0, 1366, 768)
  end
end

function M.drawConfirmDialog()
  -- Dim background
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Dialog box
  local boxW = 500
  local boxH = 150
  local boxX = (1366 - boxW) / 2
  local boxY = (768 - boxH) / 2

  love.graphics.setColor(0.2, 0.2, 0.25)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
  love.graphics.setColor(1, 0.3, 0.3)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

  -- Message
  love.graphics.setFont(fonts.menu)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Delete this save?", boxX, boxY + 30, boxW, "center")

  -- Options
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.8, 0.8, 0.8)
  love.graphics.printf("ENTER: Yes | ESC: No", boxX, boxY + 100, boxW, "center")
end

function M.keypressed(key)
  if state == "selecting" then
    if key == "up" then
      selectedSlot = selectedSlot - 1
      if selectedSlot < 1 then
        selectedSlot = 3
      end
    elseif key == "down" then
      selectedSlot = selectedSlot + 1
      if selectedSlot > 3 then
        selectedSlot = 1
      end
    elseif key == "return" then
      local saveData = saves.getSave(selectedSlot)
      if saveData and not fadeState.active then
        if M.onSelectSave then
          -- Start fade to white, then load
          fadeState.active = true
          fadeState.alpha = 0
          local slot = selectedSlot
          fadeState.callback = function()
            M.onSelectSave(slot, saveData)
          end
        end
      end
    elseif key == "x" then
      local saveData = saves.getSave(selectedSlot)
      if saveData then
        state = "confirm_delete"
      end
    elseif key == "escape" then
      if M.onBack then
        M.onBack()
      end
    end
  elseif state == "confirm_delete" then
    if key == "return" then
      saves.deleteSave(selectedSlot)
      state = "selecting"
    elseif key == "escape" then
      state = "selecting"
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented for continue menu
end

return M
