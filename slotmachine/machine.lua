local M = {}
local reel = require("slotmachine.reel")
local symbols = require("slotmachine.symbols")

-- Centered for 1366x768
local SCREEN_W = 1366
local MACHINE_W = 470
local MACHINE_CENTER_X = SCREEN_W / 2
local REEL_X_START = MACHINE_CENTER_X - MACHINE_W / 2
local REEL_X_POSITIONS = {REEL_X_START, REEL_X_START + 160, REEL_X_START + 320}
local REEL_Y = 180

function M.new()
  local machine = {
    reels = {},
    state = "idle",
    results = {},
    payoutTimer = 0
  }

  for i = 1, 3 do
    machine.reels[i] = reel.new(REEL_X_POSITIONS[i], REEL_Y, symbols.SYMBOLS)
  end

  return machine
end

function M.update(machine, dt)
  if machine.state == "spinning" then
    for _, r in ipairs(machine.reels) do
      reel.update(r, dt)
    end

    local allStopped = true
    for _, r in ipairs(machine.reels) do
      if not reel.isStopped(r) then
        allStopped = false
        break
      end
    end

    if allStopped then
      M.captureResults(machine)
      machine.state = "checking"
    end

  elseif machine.state == "payout" then
    machine.payoutTimer = machine.payoutTimer + dt
    if machine.payoutTimer >= 8.0 then
      machine.state = "idle"
      machine.payoutTimer = 0
    end
  end
end

-- Weighted symbol selection: higher weight = more likely to appear
local SYMBOL_WEIGHTS = {
  cherry = 25,   -- most common
  lemon = 20,
  orange = 18,
  plum = 15,
  bar = 12,
  seven = 7,
  diamond = 3    -- rarest
}

local function getWeightedSymbolIndex(symbolList)
  local totalWeight = 0
  for _, sym in ipairs(symbolList) do
    totalWeight = totalWeight + (SYMBOL_WEIGHTS[sym.id] or 10)
  end

  local roll = math.random() * totalWeight
  local cumulative = 0

  for i, sym in ipairs(symbolList) do
    cumulative = cumulative + (SYMBOL_WEIGHTS[sym.id] or 10)
    if roll <= cumulative then
      return i
    end
  end

  return #symbolList
end

function M.spin(machine)
  if machine.state ~= "idle" then
    return false
  end

  machine.state = "spinning"

  local delays = {0, 0.3, 0.6}
  local spinDuration = 2.0

  for i, r in ipairs(machine.reels) do
    local targetIndex = getWeightedSymbolIndex(symbols.SYMBOLS)
    reel.startSpin(r, spinDuration + delays[i], targetIndex - 1)
  end

  return true
end

function M.captureResults(machine)
  machine.results = {}
  for i, r in ipairs(machine.reels) do
    machine.results[i] = reel.getVisibleSymbols(r)
  end
end

function M.checkWins(machine, betAmount)
  local wins = {}
  local totalWinnings = 0

  for _, payline in ipairs(symbols.PAYLINES) do
    local paylineSymbols = {}

    for _, pos in ipairs(payline.positions) do
      local reelNum = pos[1]
      local symbolPos = pos[2]
      local symbol = machine.results[reelNum][symbolPos]
      table.insert(paylineSymbols, symbol)
    end

    if paylineSymbols[1].id == paylineSymbols[2].id and
       paylineSymbols[2].id == paylineSymbols[3].id then

      local payout = symbols.getPayout(paylineSymbols[1].id, betAmount)
      table.insert(wins, {
        payline = payline.name,
        symbol = paylineSymbols[1].id,
        amount = payout
      })
      totalWinnings = totalWinnings + payout
    end
  end

  return wins, totalWinnings
end

return M
