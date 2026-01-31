local M = {}

local PAYOUTS = {
  straight = 35,
  split = 17,
  street = 11,
  corner = 8,
  dozen = 2,
  column = 2,
  red = 1,
  black = 1,
  odd = 1,
  even = 1,
  low = 1,
  high = 1
}

function M.new()
  return {
    active = {}
  }
end

function M.placeBet(bets, betInfo, amount)
  table.insert(bets.active, {
    type = betInfo.type,
    numbers = betInfo.numbers,
    amount = amount
  })
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
