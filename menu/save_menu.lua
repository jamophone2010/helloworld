local M = {}

local saves = require("menu.saves")
local selectedSlot = 1
local fonts = {}
local state = "selecting" -- "selecting", "confirm_overwrite", "confirm_delete", "saved"
local savedTimer = 0

M.onSave = nil
M.onBack = nil
M.getSaveData = nil -- Function to get current game data

function M.load()
  fonts.title = love.graphics.newFont(40)
  fonts.menu = love.graphics.newFont(28)
  fonts.info = love.graphics.newFont(16)
  selectedSlot = 1
  state = "selecting"
  savedTimer = 0
end

function M.update(dt)
  if state == "saved" then
    savedTimer = savedTimer + dt
    if savedTimer >= 1.5 then
      if M.onBack then
        M.onBack()
      end
    end
  end
end

function M.draw()
  -- Background
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("SAVE GAME", 0, 50, 1366, "center")

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

  -- Draw confirmation dialogs or saved message
  if state == "confirm_overwrite" then
    M.drawConfirmDialog("Overwrite existing save?")
  elseif state == "confirm_delete" then
    M.drawConfirmDialog("Delete this save?")
  elseif state == "saved" then
    M.drawSavedMessage()
  end

  -- Instructions
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.5, 0.5, 0.5)
  if state == "selecting" then
    love.graphics.printf("UP/DOWN: Select | ENTER: Save | X: Delete | ESC: Back", 0, 700, 1366, "center")
  end
end

function M.drawConfirmDialog(message)
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
  love.graphics.setColor(1, 1, 0)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

  -- Message
  love.graphics.setFont(fonts.menu)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(message, boxX, boxY + 30, boxW, "center")

  -- Options
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.8, 0.8, 0.8)
  love.graphics.printf("ENTER: Yes | ESC: No", boxX, boxY + 100, boxW, "center")
end

function M.drawSavedMessage()
  -- Dim background
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Message box
  local boxW = 300
  local boxH = 80
  local boxX = (1366 - boxW) / 2
  local boxY = (768 - boxH) / 2

  love.graphics.setColor(0.1, 0.3, 0.1)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
  love.graphics.setColor(0, 1, 0)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

  love.graphics.setFont(fonts.menu)
  love.graphics.setColor(0, 1, 0)
  love.graphics.printf("Game Saved!", boxX, boxY + 22, boxW, "center")
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
      if saveData then
        -- Slot occupied, confirm overwrite
        state = "confirm_overwrite"
      else
        -- Empty slot, save directly
        M.doSave()
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
  elseif state == "confirm_overwrite" then
    if key == "return" then
      M.doSave()
    elseif key == "escape" then
      state = "selecting"
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

function M.doSave()
  if M.getSaveData then
    local saveData = M.getSaveData()
    saves.saveSave(selectedSlot, saveData)
    if M.onSave then
      M.onSave(selectedSlot)
    end
    state = "saved"
    savedTimer = 0
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented
end

return M
