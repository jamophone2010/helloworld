local M = {}

local NUM_PAYLINES = 5

function M.new(startingCredits)
  return {
    credits = startingCredits or 100,
    currentBet = 1,
    minBet = 1,
    maxBet = 10
  }
end

function M.getTotalBet(bank)
  return bank.currentBet * NUM_PAYLINES
end

function M.canPlaceBet(bank)
  return bank.credits >= M.getTotalBet(bank)
end

function M.placeBet(bank)
  local totalBet = M.getTotalBet(bank)
  if not M.canPlaceBet(bank) then
    return false
  end
  bank.credits = bank.credits - totalBet
  return true
end

function M.addWinnings(bank, amount)
  bank.credits = bank.credits + amount
end

function M.increaseBet(bank)
  bank.currentBet = math.min(bank.currentBet + 1, bank.maxBet)
end

function M.decreaseBet(bank)
  bank.currentBet = math.max(bank.currentBet - 1, bank.minBet)
end

return M
