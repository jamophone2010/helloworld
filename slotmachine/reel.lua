local M = {}

local SYMBOL_HEIGHT = 120
local SYMBOL_SPACING = 15
local SYMBOL_TOTAL = SYMBOL_HEIGHT + SYMBOL_SPACING
local MAX_SPEED = -800  -- negative for reverse direction
local ACCEL_TIME = 0.2
local DECEL_TIME = 0.5

function M.new(x, y, symbols)
  local reel = {
    x = x,
    y = y,
    symbols = symbols,
    offset = 0,
    velocity = 0,
    spinning = false,
    targetOffset = 0,
    stopDelay = 0,
    accelTime = 0,
    decelTime = 0,
    decelStartOffset = 0,
    phase = "idle"
  }
  return reel
end

function M.update(reel, dt)
  if not reel.spinning then return end

  if reel.phase == "accel" then
    reel.accelTime = reel.accelTime + dt
    local t = math.min(reel.accelTime / ACCEL_TIME, 1)
    reel.velocity = MAX_SPEED * t * t
    reel.offset = reel.offset + reel.velocity * dt

    if t >= 1 then
      reel.phase = "coast"
      reel.velocity = MAX_SPEED
    end

  elseif reel.phase == "coast" then
    if reel.stopDelay > 0 then
      reel.stopDelay = reel.stopDelay - dt
      if reel.stopDelay <= 0 then
        reel.phase = "decel"
        reel.decelTime = 0
        reel.decelStartOffset = reel.offset
      end
    end
    reel.offset = reel.offset + reel.velocity * dt

  elseif reel.phase == "decel" then
    reel.decelTime = reel.decelTime + dt
    local t = math.min(reel.decelTime / DECEL_TIME, 1)

    local easeOut = 1 - math.pow(1 - t, 3)

    local totalDist = reel.targetOffset - reel.decelStartOffset
    reel.offset = reel.decelStartOffset + totalDist * easeOut

    if t >= 1 then
      reel.offset = reel.targetOffset
      reel.velocity = 0
      reel.spinning = false
      reel.phase = "idle"
    end
  end
end

function M.startSpin(reel, delay, targetSymbolIndex)
  reel.spinning = true
  reel.stopDelay = delay
  reel.velocity = 0
  reel.accelTime = 0
  reel.phase = "accel"

  local spins = 3
  reel.targetOffset = reel.offset - (spins * #reel.symbols + targetSymbolIndex) * SYMBOL_TOTAL  -- negative for reverse
end

function M.isStopped(reel)
  return not reel.spinning
end

-- Safe modulo that always returns positive values
local function posMod(a, b)
  return ((a % b) + b) % b
end

function M.getVisibleSymbols(reel)
  local visible = {}
  local numSymbols = #reel.symbols

  local topIndex = posMod(math.floor(reel.offset / SYMBOL_TOTAL), numSymbols)

  for i = 0, 2 do
    local index = posMod(topIndex + i, numSymbols) + 1
    visible[i + 1] = reel.symbols[index]
  end

  return visible
end

function M.getOffset(reel)
  return posMod(reel.offset, SYMBOL_TOTAL * #reel.symbols)
end

return M
