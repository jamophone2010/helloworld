local M = {}

-- Simple ability key detector: press V to activate

local isPressed = false

-- Callback fired when ability is activated
M.onActivate = nil

function M.reset()
  isPressed = false
end

function M.update(dt)
  -- No update needed for simple press detection
end

function M.keypressed(key)
  if key ~= "v" then return end  -- V key is the special ability key
  if M.onActivate then
    M.onActivate()
  end
end

function M.keyreleased(key)
  if key ~= "v" then return end
  isPressed = false
end

--- Returns true if the player is currently pressing the ability key
function M.isHolding()
  return isPressed
end

--- Returns the current hold duration (for visual feedback)
function M.getHoldDuration()
  return 0
end

--- Returns the progress toward activation (0.0 to 1.0)
function M.getProgress()
  if isPressed and not hasTriggered then
    local duration = love.timer.getTime() - pressStart
    return math.min(1.0, duration / HOLD_DURATION)
  end
  return 0
end

return M
