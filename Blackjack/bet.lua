local M = {}
local hand = require("blackjack.hand")

M.CHIP_VALUES = {1, 5, 10, 25, 100, 1000, 5000, 10000, 100000, 1000000}
M.CHIP_COLORS = {
  [1] = {1, 1, 1},          -- White
  [5] = {1, 0.1, 0.1},      -- Red
  [10] = {0.1, 0.1, 1},     -- Blue
  [25] = {0.1, 0.8, 0.1},   -- Green
  [100] = {0.1, 0.1, 0.1},  -- Black
  [1000] = {0.5, 0.1, 0.5}, -- Purple
  [5000] = {1, 0.5, 0},     -- Orange
  [10000] = {0.8, 0.8, 0.1},-- Yellow
  [100000] = {0.8, 0.4, 0.2},-- Brown
  [1000000] = {0.9, 0.7, 0.2}-- Gold
}
M.CHIP_LABELS = {
  [1] = "1",
  [5] = "5",
  [10] = "10",
  [25] = "25",
  [100] = "100",
  [1000] = "1K",
  [5000] = "5K",
  [10000] = "10K",
  [100000] = "100K",
  [1000000] = "1M"
}

function M.new(startingCredits)
  return {
    credits = startingCredits or 1000,
    currentBet = 0,
    insuranceBet = 0,
    selectedChipIndex = 2
  }
end

function M.getSelectedChipValue(betting)
  return M.CHIP_VALUES[betting.selectedChipIndex]
end

function M.getChipColor(value)
  return M.CHIP_COLORS[value] or {0.5, 0.5, 0.5}
end

function M.getChipLabel(value)
  return M.CHIP_LABELS[value] or tostring(value)
end

-- Convert an amount into optimal chip stack
function M.getChipStack(amount)
  local stack = {}
  local remaining = amount

  for i = #M.CHIP_VALUES, 1, -1 do
    local chipValue = M.CHIP_VALUES[i]
    local count = math.floor(remaining / chipValue)
    if count > 0 then
      table.insert(stack, {value = chipValue, count = count})
      remaining = remaining - (count * chipValue)
    end
  end

  return stack
end

function M.canAfford(betting, amount)
  return betting.credits >= amount
end

function M.increaseBet(betting)
  local chipValue = M.getSelectedChipValue(betting)
  if betting.credits >= betting.currentBet + chipValue then
    betting.currentBet = betting.currentBet + chipValue
  end
end

function M.decreaseBet(betting)
  local chipValue = M.getSelectedChipValue(betting)
  betting.currentBet = math.max(0, betting.currentBet - chipValue)
end

function M.nextChip(betting)
  local startIndex = betting.selectedChipIndex
  repeat
    betting.selectedChipIndex = betting.selectedChipIndex + 1
    if betting.selectedChipIndex > #M.CHIP_VALUES then
      betting.selectedChipIndex = 1
    end
  until M.canAfford(betting, M.CHIP_VALUES[betting.selectedChipIndex]) or betting.selectedChipIndex == startIndex
end

function M.prevChip(betting)
  local startIndex = betting.selectedChipIndex
  repeat
    betting.selectedChipIndex = betting.selectedChipIndex - 1
    if betting.selectedChipIndex < 1 then
      betting.selectedChipIndex = #M.CHIP_VALUES
    end
  until M.canAfford(betting, M.CHIP_VALUES[betting.selectedChipIndex]) or betting.selectedChipIndex == startIndex
end

function M.canPlaceBet(betting)
  return betting.currentBet > 0 and betting.credits >= betting.currentBet
end

function M.placeBet(betting)
  if not M.canPlaceBet(betting) then
    return false
  end
  betting.credits = betting.credits - betting.currentBet
  return true
end

function M.placeInsurance(betting)
  local insuranceAmount = math.floor(betting.currentBet / 2)
  if betting.credits >= insuranceAmount then
    betting.credits = betting.credits - insuranceAmount
    betting.insuranceBet = insuranceAmount
    return true
  end
  return false
end

function M.calculatePayout(betting, playerHand, dealerHand, dealerBlackjack)
  local payout = 0
  local result = ""

  if betting.insuranceBet > 0 then
    if dealerBlackjack then
      payout = payout + betting.insuranceBet * 3
      result = "Insurance pays 2:1"
    end
    betting.insuranceBet = 0
  end

  local playerValue = hand.getValue(playerHand)
  local dealerValue = hand.getValue(dealerHand)
  local playerBJ = hand.isBlackjack(playerHand)
  local playerBust = hand.isBust(playerHand)
  local dealerBust = hand.isBust(dealerHand)

  if playerBust then
    result = "Bust - Dealer wins"
  elseif playerBJ and not dealerBlackjack then
    payout = payout + math.floor(betting.currentBet * 2.5)
    result = "Blackjack! Pays 3:2"
  elseif dealerBust then
    payout = payout + betting.currentBet * 2
    result = "Dealer busts - You win!"
  elseif playerValue > dealerValue then
    payout = payout + betting.currentBet * 2
    result = "You win!"
  elseif playerValue == dealerValue then
    payout = payout + betting.currentBet
    result = "Push"
  else
    result = "Dealer wins"
  end

  betting.credits = betting.credits + payout
  return payout, result
end

return M
