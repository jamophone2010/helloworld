local M = {}
local reel = require("slotmachine.reel")
local symbols = require("slotmachine.symbols")

local REEL_X_POSITIONS = {250, 350, 450}
local REEL_Y = 200

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
    if machine.payoutTimer >= 2.0 then
      machine.state = "idle"
      machine.payoutTimer = 0
    end
  end
end

function M.spin(machine)
  if machine.state ~= "idle" then
    return false
  end

  machine.state = "spinning"

  local delays = {0, 0.3, 0.6}
  local spinDuration = 2.0

  for i, r in ipairs(machine.reels) do
    local targetIndex = math.random(1, #symbols.SYMBOLS)
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
