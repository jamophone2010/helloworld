local M = {}

local fonts = {}
local playerName = ""
local maxLength = 12
local cursorBlink = 0
local cursorVisible = true

M.onComplete = nil
M.onBack = nil

function M.load()
  fonts.title = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 40)
  fonts.input = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 32)
  fonts.info = love.graphics.newFont("fonts/EBGaramond-Regular.ttf", 16)
  playerName = ""
  cursorBlink = 0
  cursorVisible = true
end

function M.update(dt)
  cursorBlink = cursorBlink + dt
  if cursorBlink >= 0.5 then
    cursorBlink = 0
    cursorVisible = not cursorVisible
  end
end

function M.draw()
  -- Background
  love.graphics.setColor(0.1, 0.1, 0.15)
  love.graphics.rectangle("fill", 0, 0, 1366, 768)

  -- Title
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("ENTER YOUR NAME", 0, 150, 1366, "center")

  -- Input box background
  local boxX = (1366 - 500) / 2
  local boxY = 320
  local boxW = 500
  local boxH = 60

  love.graphics.setColor(0.2, 0.2, 0.25)
  love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
  love.graphics.setColor(0.5, 0.5, 0.6)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

  -- Player name text
  love.graphics.setFont(fonts.input)
  love.graphics.setColor(1, 1, 1)
  local displayText = playerName
  if cursorVisible then
    displayText = displayText .. "_"
  end
  love.graphics.printf(displayText, boxX + 15, boxY + 12, boxW - 30, "left")

  -- Character count
  love.graphics.setFont(fonts.info)
  love.graphics.setColor(0.6, 0.6, 0.6)
  love.graphics.printf(#playerName .. "/" .. maxLength, boxX, boxY + boxH + 10, boxW, "right")

  -- Instructions
  love.graphics.setColor(0.5, 0.5, 0.5)
  love.graphics.printf("Type your name (letters, numbers, spaces)", 0, 450, 1366, "center")
  love.graphics.printf("ENTER: Confirm | BACKSPACE: Delete | ESC: Back", 0, 700, 1366, "center")

  -- Error message if name is empty
  if #playerName == 0 then
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.printf("Name cannot be empty", 0, 480, 1366, "center")
  end
end

function M.keypressed(key)
  if key == "escape" then
    if M.onBack then
      M.onBack()
    end
  elseif key == "return" then
    if #playerName > 0 then
      if M.onComplete then
        M.onComplete(playerName)
      end
    end
  elseif key == "backspace" then
    if #playerName > 0 then
      playerName = playerName:sub(1, -2)
    end
  end
end

function M.textinput(text)
  -- Only allow alphanumeric and space
  if #playerName < maxLength then
    if text:match("^[%w ]$") then
      playerName = playerName .. text
    end
  end
end

function M.mousepressed(x, y, button)
  -- Not implemented
end

return M
