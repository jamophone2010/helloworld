local M = {}

local currency = require("hub.currency")
local hub = require("hub")
local fonts = {}
local amount = 1
local notes = 0
local credits = 0
local conversionMode = "notesToCredits" -- "notesToCredits" or "creditsToNotes"

-- Hold tracking for arrow keys
local keyHoldState = {
  up = { held = false, holdTime = 0, timeSinceLastIncrement = 0 },
  down = { held = false, holdTime = 0, timeSinceLastIncrement = 0 },
  right = { held = false, holdTime = 0, timeSinceLastIncrement = 0 },
  left = { held = false, holdTime = 0, timeSinceLastIncrement = 0 }
}

local HOLD_STEADY_TIME = 2.0 -- 2 seconds before acceleration starts
local STEADY_RATE = 3.0 -- 3 increases per second during steady phase
local STEADY_INTERVAL = 1.0 / STEADY_RATE -- Time between increments in steady phase

function M.load()
  fonts.normal = love.graphics.newFont(14)
  fonts.large = love.graphics.newFont(20)
  fonts.small = love.graphics.newFont(12)
  amount = 1
  conversionMode = "notesToCredits"
  
  -- Reset key hold state
  for key, _ in pairs(keyHoldState) do
    keyHoldState[key] = { held = false, holdTime = 0, timeSinceLastIncrement = 0 }
  end
end

function M.update(dt)
  -- Update current balances on every frame
  notes = hub.getNotes()
  credits = hub.getCredits()
  
  -- Handle held arrow keys
  local increaseKeys = { "up", "right" }
  local decreaseKeys = { "down", "left" }
  
  for _, key in ipairs(increaseKeys) do
    if keyHoldState[key].held then
      keyHoldState[key].holdTime = keyHoldState[key].holdTime + dt
      keyHoldState[key].timeSinceLastIncrement = keyHoldState[key].timeSinceLastIncrement + dt
      
      if keyHoldState[key].holdTime < HOLD_STEADY_TIME then
        -- During steady phase: 3 increases per second
        if keyHoldState[key].timeSinceLastIncrement >= STEADY_INTERVAL then
          local baseIncrement = conversionMode == "creditsToNotes" and 100 or 1
          M.increaseAmount(baseIncrement)
          keyHoldState[key].timeSinceLastIncrement = 0
        end
      else
        -- After initial steady time, increase speed linearly
        local excessTime = keyHoldState[key].holdTime - HOLD_STEADY_TIME
        local incrementAmount = 1 + math.floor(excessTime * 2) -- Increases faster over time
        if conversionMode == "creditsToNotes" then
          incrementAmount = incrementAmount * 100
        end
        M.increaseAmount(incrementAmount)
      end
    end
  end
  
  for _, key in ipairs(decreaseKeys) do
    if keyHoldState[key].held then
      keyHoldState[key].holdTime = keyHoldState[key].holdTime + dt
      keyHoldState[key].timeSinceLastIncrement = keyHoldState[key].timeSinceLastIncrement + dt
      
      if keyHoldState[key].holdTime < HOLD_STEADY_TIME then
        -- During steady phase: 3 decreases per second
        if keyHoldState[key].timeSinceLastIncrement >= STEADY_INTERVAL then
          local baseDecrement = conversionMode == "creditsToNotes" and 100 or 1
          M.decreaseAmount(baseDecrement)
          keyHoldState[key].timeSinceLastIncrement = 0
        end
      else
        -- After initial steady time, increase speed linearly
        local excessTime = keyHoldState[key].holdTime - HOLD_STEADY_TIME
        local decrementAmount = 1 + math.floor(excessTime * 2) -- Increases faster over time
        if conversionMode == "creditsToNotes" then
          decrementAmount = decrementAmount * 100
        end
        M.decreaseAmount(decrementAmount)
      end
    end
  end
end

function M.draw()
  -- Background
  love.graphics.setColor(0.2, 0.2, 0.3)
  love.graphics.rectangle("fill", 0, 0, 800, 600)

  -- Title
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 0)
  love.graphics.printf("CASHIER", 0, 100, 800, "center")

  -- Info box
  love.graphics.setColor(0, 0, 0, 0.9)
  love.graphics.rectangle("fill", 150, 160, 500, 350)
  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", 150, 160, 500, 350)

  -- Current balances
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("Your Notes: " .. notes, 0, 190, 800, "center")
  love.graphics.printf("Your Credits: " .. credits, 0, 220, 800, "center")

  -- Exchange rate
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.printf("Exchange Rate: 1 Note = 100 Credits", 0, 260, 800, "center")

  -- Mode indicator
  love.graphics.setFont(fonts.normal)
  love.graphics.setColor(1, 1, 0)
  if conversionMode == "notesToCredits" then
    love.graphics.printf("Converting: Notes to Credits", 0, 300, 800, "center")
  else
    love.graphics.printf("Converting: Credits to Notes", 0, 300, 800, "center")
  end

  -- Amount selector
  love.graphics.setFont(fonts.large)
  love.graphics.setColor(1, 1, 0)
  if conversionMode == "notesToCredits" then
    love.graphics.printf("Convert: " .. amount .. " Notes", 0, 340, 800, "center")
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("(" .. (amount * currency.NOTES_TO_CREDITS) .. " Credits)", 0, 370, 800, "center")
    
    -- Warning if insufficient notes
    if hub.getNotes() < amount then
      love.graphics.setColor(1, 0, 0)
      love.graphics.printf("Insufficient Notes!", 0, 410, 800, "center")
    end
  else
    love.graphics.printf("Convert: " .. amount .. " Credits", 0, 340, 800, "center")
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("(" .. math.floor(amount / currency.NOTES_TO_CREDITS) .. " Notes)", 0, 370, 800, "center")
    
    -- Warning if insufficient credits
    if hub.getCredits() < amount then
      love.graphics.setColor(1, 0, 0)
      love.graphics.printf("Insufficient Credits!", 0, 410, 800, "center")
    end
  end

  -- Instructions
  love.graphics.setFont(fonts.small)
  love.graphics.setColor(0.7, 0.7, 0.7)
  love.graphics.print("Arrow Keys: Adjust | Tab: Switch Mode | E: Confirm | ESC: Cancel", 170, 460)
end

function M.increaseAmount(increment)
  amount = amount + increment
  if conversionMode == "notesToCredits" then
    if amount > hub.getNotes() then
      amount = hub.getNotes()
    end
    if amount > 99 then
      amount = 99
    end
  else
    if amount > hub.getCredits() then
      amount = hub.getCredits()
    end
  end
end

function M.decreaseAmount(decrement)
  amount = amount - decrement
  if amount < (conversionMode == "creditsToNotes" and 100 or 1) then
    amount = (conversionMode == "creditsToNotes" and 100 or 1)
  end
end

function M.keypressed(key)
  if key == "escape" then
    if returnToHub then
      returnToHub()
    end
  elseif key == "tab" then
    -- Switch conversion mode
    if conversionMode == "notesToCredits" then
      conversionMode = "creditsToNotes"
      amount = 100 -- Start with a reasonable amount for credits
    else
      conversionMode = "notesToCredits"
      amount = 1
    end
  elseif key == "up" or key == "right" then
    -- Start holding
    if key == "up" then
      keyHoldState.up.held = true
      keyHoldState.up.holdTime = 0
      keyHoldState.up.timeSinceLastIncrement = 0
    else
      keyHoldState.right.held = true
      keyHoldState.right.holdTime = 0
      keyHoldState.right.timeSinceLastIncrement = 0
    end
    -- Immediate increase for first press
    M.increaseAmount(conversionMode == "creditsToNotes" and 100 or 1)
  elseif key == "down" or key == "left" then
    -- Start holding
    if key == "down" then
      keyHoldState.down.held = true
      keyHoldState.down.holdTime = 0
      keyHoldState.down.timeSinceLastIncrement = 0
    else
      keyHoldState.left.held = true
      keyHoldState.left.holdTime = 0
      keyHoldState.left.timeSinceLastIncrement = 0
    end
    -- Immediate decrease for first press
    M.decreaseAmount(conversionMode == "creditsToNotes" and 100 or 1)
  elseif key == "e" then
    if conversionMode == "notesToCredits" then
      if hub.getNotes() >= amount then
        local newNotes, creditsToAdd = currency.convertNotesToCredits(hub.getNotes(), amount)
        hub.setNotes(newNotes)
        hub.setCredits(hub.getCredits() + creditsToAdd)
        currency.save(newNotes)
        -- Reset amount after successful conversion
        amount = 1
        if amount > hub.getNotes() then
          amount = math.max(1, hub.getNotes())
        end
      end
    else
      if hub.getCredits() >= amount then
        local notesFromCredits = math.floor(amount / currency.NOTES_TO_CREDITS)
        local creditsUsed = notesFromCredits * currency.NOTES_TO_CREDITS
        hub.setCredits(hub.getCredits() - creditsUsed)
        hub.setNotes(hub.getNotes() + notesFromCredits)
        currency.save(hub.getNotes())
        -- Reset amount after successful conversion
        amount = 100
        if amount > hub.getCredits() then
          amount = math.max(100, hub.getCredits())
        end
      end
    end
  end
end

function M.keyreleased(key)
  -- Stop holding
  if key == "up" then
    keyHoldState.up.held = false
    keyHoldState.up.holdTime = 0
    keyHoldState.up.timeSinceLastIncrement = 0
  elseif key == "down" then
    keyHoldState.down.held = false
    keyHoldState.down.holdTime = 0
    keyHoldState.down.timeSinceLastIncrement = 0
  elseif key == "right" then
    keyHoldState.right.held = false
    keyHoldState.right.holdTime = 0
    keyHoldState.right.timeSinceLastIncrement = 0
  elseif key == "left" then
    keyHoldState.left.held = false
    keyHoldState.left.holdTime = 0
    keyHoldState.left.timeSinceLastIncrement = 0
  end
end

return M

