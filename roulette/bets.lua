local M = {}

-- Standard roulette payout multipliers (profit ratio)
-- These represent the profit multiplier, not including the original bet
-- Final payout = bet.amount * (PAYOUTS[type] + 1)
local PAYOUTS = {
  straight = 35,    -- Single number: 35:1 payout
  split = 17,       -- Two numbers: 17:1 payout
  street = 11,      -- Three numbers: 11:1 payout
  corner = 8,       -- Four numbers: 8:1 payout
  dozen = 2,        -- Dozen: 2:1 payout
  column = 2,       -- Column: 2:1 payout
  red = 1,          -- Red: 1:1 payout
  black = 1,        -- Black: 1:1 payout
  odd = 1,          -- Odd: 1:1 payout
  even = 1,         -- Even: 1:1 payout
  low = 1,          -- 1-18: 1:1 payout
  high = 1          -- 19-36: 1:1 payout
}

function M.new()
  return {
    active = {}
  }
end

function M.placeBet(bets, betInfo, amount)
  -- Check if there's already a bet on this position
  for i, existingBet in ipairs(bets.active) do
    if existingBet.type == betInfo.type and M.arraysEqual(existingBet.numbers, betInfo.numbers) then
      -- Combine with existing bet
      bets.active[i].amount = existingBet.amount + amount
      return
    end
  end
  
  -- Create new bet
  table.insert(bets.active, {
    type = betInfo.type,
    numbers = betInfo.numbers,
    amount = amount
  })
end

-- Helper function to compare number arrays
function M.arraysEqual(arr1, arr2)
  if #arr1 ~= #arr2 then
    return false
  end
  
  for i = 1, #arr1 do
    if arr1[i] ~= arr2[i] then
      return false
    end
  end
  
  return true
end

function M.clear(bets)
  bets.active = {}
end

function M.checkWin(bet, resultNumber)
  local result = resultNumber
  if resultNumber == "00" then
    result = "00"
  end

  for _, num in ipairs(bet.numbers) do
    if num == result then
      return true
    end
  end

  return false
end

function M.calculatePayout(bets, resultNumber)
  local totalPayout = 0
  local wins = {}

  for _, bet in ipairs(bets.active) do
    if M.checkWin(bet, resultNumber) then
      local payout = bet.amount * (PAYOUTS[bet.type] + 1)
      totalPayout = totalPayout + payout
      table.insert(wins, {
        type = bet.type,
        amount = payout
      })
    end
  end

  return totalPayout, wins
end

function M.getTotalBetAmount(bets)
  local total = 0
  for _, bet in ipairs(bets.active) do
    total = total + bet.amount
  end
  return total
end

return M
